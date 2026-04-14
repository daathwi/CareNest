import 'dart:async';
import 'dart:isolate';
import 'llama_service.dart';

class InferenceMetrics {
  final double ttft;
  final double tps;
  final int totalTokens;
  final double totalTime;

  InferenceMetrics({
    required this.ttft,
    required this.tps,
    required this.totalTokens,
    required this.totalTime,
  });

  Map<String, dynamic> toMap() => {
    "type": "metrics",
    "ttft": ttft,
    "tps": tps,
    "totalTokens": totalTokens,
    "totalTime": totalTime,
  };
}

class LlamaIsolateRunner {
  static LlamaIsolateRunner? _instance;
  Isolate? _isolate;
  SendPort? _commandPort;
  final StreamController<dynamic> _responseController = StreamController<dynamic>.broadcast();
  bool _isInitialized = false;

  LlamaIsolateRunner._();
  factory LlamaIsolateRunner() => _instance ??= LlamaIsolateRunner._();

  Stream<dynamic> get responses => _responseController.stream;

  Future<void> init(String modelPath) async {
    if (_isInitialized) return;

    final receivePort = ReceivePort();
    final setupCompleter = Completer<void>();

    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
    
    receivePort.listen((message) {
      if (_commandPort == null && message is SendPort) {
        _commandPort = message;
        setupCompleter.complete();
        return;
      }
      
      if (message is String && message == "___IDLE___") {
        return;
      }
      _responseController.add(message);
    });

    await setupCompleter.future;

    // Send the load command
    _commandPort!.send({"cmd": "load", "modelPath": modelPath});
    _isInitialized = true;
  }

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _isInitialized = false;
  }

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  void generate(String prompt) {
    if (_isBusy) return;
    _isBusy = true;
    _commandPort?.send({"cmd": "generate", "prompt": prompt});
  }

  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    LlamaService? llama;
    String? currentModelPath;

    receivePort.listen((message) {
      final cmd = message["cmd"];
      
      if (cmd == "load") {
        final path = message["modelPath"];
        if (llama != null && currentModelPath == path) return;
        
        llama = LlamaService();
        llama!.loadModel(path);
        currentModelPath = path;
        
        // Cache system prompt immediately after load
        llama!.warmupSystemPrompt(_systemPrompt);
        mainSendPort.send("___IDLE___");
      } 
      else if (cmd == "generate") {
        if (llama == null) return;
        
        final String userInput = message["prompt"];
        final String userPrompt = "$userInput<end_of_turn>\n<start_of_turn>model\n";
        
        final overallWatch = Stopwatch()..start();
        final prefillWatch = Stopwatch()..start();

        try {
          if (!llama!.setPrompt(userPrompt)) {
            mainSendPort.send("Error: Failed to process prompt.");
            mainSendPort.send("___DONE___");
            return;
          }

          double? ttft;
          int tokenCount = 0;
          final generationWatch = Stopwatch();

          for (int i = 0; i < 1024; i++) {
            final token = llama!.getNextToken();
            if (token == null) break;

            if (tokenCount == 0) {
              ttft = prefillWatch.elapsedMilliseconds.toDouble();
              generationWatch.start();
            }

            mainSendPort.send(token);
            tokenCount++;
          }

          generationWatch.stop();
          overallWatch.stop();

          final metrics = InferenceMetrics(
            ttft: ttft ?? 0.0,
            tps: tokenCount / (generationWatch.elapsedMilliseconds / 1000.0),
            totalTokens: tokenCount,
            totalTime: overallWatch.elapsedMilliseconds.toDouble(),
          );

          mainSendPort.send(metrics.toMap());
          mainSendPort.send("___DONE___");
          mainSendPort.send("___IDLE___");
        } catch (e) {
          mainSendPort.send("Error: $e");
          mainSendPort.send("___DONE___");
          mainSendPort.send("___IDLE___");
        }
      }
    });
  }
}

const String _systemPrompt = 
    "<start_of_turn>user\n"
    "You are CareNest, a precise medical diagnostic reporter. Your goal is to produce clinical-grade documentation.\n"
    "STRICT UI RULES:\n"
    "1. FLOWCHARTS: For every procedure or symptom path, generate a Mermaid diagram. \n"
    "   - ALWAYS use `flowchart TD`.\n"
    "   - NODES: Every node MUST be formatted as `ID[Long Descriptive Clinical Label]`. \n"
    "   - ID: Use descriptive CamelCase IDs (e.g. PtAssessment, LabResults). NEVER use single letters.\n"
    "   - PATHS: Create ONLY linear, strictly vertical paths: S1[...] --> S2[...] --> S3[...]\n"
    "   - NO HORIZONTAL BRANCHING: If multiple options exist, list them in a vertical sequence or use multiple flowcharts.\n"
    "2. TABLES: Use Markdown tables for comparing medications, symptoms, or reference values.\n"
    "3. FORMATTING: Use Markdown headers (e.g. ## for Clinical Sections, ### for sub-sections). NEVER write the text 'H1' or 'H2' at the start of a line.\n"
    "4. SAFETY: Always include a ⚠️ Critical Safety section at the end of every report.\n"
    "Output raw Markdown. Use ## and ### only.<end_of_turn>\n\n";

// Compatibility helper to keep main.dart working for now
Future<Stream<dynamic>> runLlamaStreaming(String prompt, String modelPath) async {
  final runner = LlamaIsolateRunner();
  await runner.init(modelPath);
  
  final controller = StreamController<dynamic>();
  StreamSubscription? subscription;
  
  subscription = runner.responses.listen((msg) {
    if (controller.isClosed) return; // Safety check

    if (msg is String) {
      if (msg == "___DONE___") {
        subscription?.cancel();
        runner._isBusy = false;
        controller.close();
      } else {
        String filtered = msg.replaceAll("<end_of_turn>", "").replaceAll("<start_of_turn>", "");
        controller.add(filtered);
      }
    } else {
      controller.add(msg);
    }
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
    subscription?.cancel();
  }, onDone: () {
    if (!controller.isClosed) controller.close();
  });

  runner.generate(prompt);

  return controller.stream;
}
