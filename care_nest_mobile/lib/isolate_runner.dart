import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'llama_service.dart';

class InferenceMetrics {
  final double ttft;
  final double tps;
  final double ppTps;
  final int totalTokens;
  final double totalTime;
  final double peakRam;

  InferenceMetrics({
    required this.ttft,
    required this.tps,
    required this.ppTps,
    required this.totalTokens,
    required this.totalTime,
    required this.peakRam,
  });

  Map<String, dynamic> toMap() {
    return {
      "ttft": ttft,
      "tps": tps,
      "ppTps": ppTps,
      "totalTokens": totalTokens,
      "totalTime": totalTime,
      "peakRam": peakRam,
    };
  }
}

abstract class LlamaBaseRunner {
  Isolate? _isolate;
  SendPort? _commandPort;
  final StreamController<dynamic> _responseController =
      StreamController<dynamic>.broadcast();
  bool _isInitialized = false;
  bool _isBusy = false;

  Stream<dynamic> get responses => _responseController.stream;
  bool get isBusy => _isBusy;
  bool get isInitialized => _isInitialized;

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _isInitialized = false;
    _isBusy = false;
  }

  void generate(String prompt) {
    if (_isBusy) return;
    _isBusy = true;
    _commandPort?.send({"cmd": "generate", "prompt": prompt});
  }

  Future<void> init(String modelPath);
}

class ClinicalIsolateRunner extends LlamaBaseRunner {
  static ClinicalIsolateRunner? _instance;
  ClinicalIsolateRunner._();
  factory ClinicalIsolateRunner() => _instance ??= ClinicalIsolateRunner._();

  @override
  Future<void> init(String modelPath) async {
    if (_isInitialized) return;

    final receivePort = ReceivePort();
    final setupCompleter = Completer<void>();

    _isolate = await Isolate.spawn(_clinicalIsolateEntry, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        return;
      }
      if (message is String && message == "___IDLE___") {
        if (!setupCompleter.isCompleted) setupCompleter.complete();
        return;
      }
      _responseController.add(message);
    });

    while (_commandPort == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _commandPort!.send({"cmd": "load", "modelPath": modelPath});
    await setupCompleter.future.timeout(const Duration(seconds: 45));
    _isInitialized = true;
  }

  static void _clinicalIsolateEntry(SendPort mainSendPort) {
    print("RescueNow: Background Isolate started.");
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    LlamaService? llama;
    bool isFirstTurn = true;

    receivePort.listen((message) {
      final cmd = message["cmd"];

      if (cmd == "load") {
        print("RescueNow: Initializing Clinical Engine on CPU...");
        final path = message["modelPath"];
        isFirstTurn = true;
        llama = LlamaService();
        llama!.loadModel(path);
        print("RescueNow: CPU Engine Ready.");

        try {
          final String cacheString = "<start_of_turn>user\n$_systemPrompt\n\n";
          llama!.warmupSystemPrompt(cacheString);
        } catch (e) {
          print("RescueNow Warmup Error: $e");
        }

        mainSendPort.send("___IDLE___");
      } else if (cmd == "reset") {
        llama?.resetSession();
        isFirstTurn = true;
        mainSendPort.send("___IDLE___");
      } else if (cmd == "generate") {
        if (llama == null) return;
        final String userInput = message["prompt"];
        String userPrompt = isFirstTurn
            ? "$userInput<end_of_turn>\n<start_of_turn>model\n"
            : "<start_of_turn>user\n$userInput<end_of_turn>\n<start_of_turn>model\n";

        final overallWatch = Stopwatch()..start();
        final prefillWatch = Stopwatch()..start();

        try {
          print("RescueNow: Prefilling clinical context (Batch: 1024)...");
          final int ppTokens = llama!.setPrompt(
            userPrompt,
            keepContext: !isFirstTurn,
          );
          prefillWatch.stop();
          print(
            "RescueNow: Prefill complete in ${prefillWatch.elapsedMilliseconds}ms (${(ppTokens / (prefillWatch.elapsedMilliseconds / 1000.0)).toStringAsFixed(1)} t/s)",
          );

          if (ppTokens <= 0) {
            print("RescueNow Error: Failed to process prompt.");
            mainSendPort.send("Error: Failed to process prompt.");
            mainSendPort.send("___DONE___");
            return;
          }

          isFirstTurn = false;
          final double ramPrefill = ProcessInfo.currentRss / (1024 * 1024);
          print("RescueNow: Context cached. Delivering first token...");
          double? ttft;
          int tokenCount = 0;
          final generationWatch = Stopwatch();

          while (true) {
            String? token;
            try {
              // The first call often triggers the actual compute
              token = llama!.getNextToken();
            } catch (e) {
              print("RescueNow Generation Error: $e");
              mainSendPort.send("Error: $e");
              break;
            }

            if (token == null) break;

            if (tokenCount == 0) {
              ttft = overallWatch.elapsedMilliseconds.toDouble();
              print("RescueNow: First token delivered in ${ttft.toStringAsFixed(0)}ms");
              generationWatch.start();
            }
            mainSendPort.send(token);
            tokenCount++;
          }

          generationWatch.stop();
          overallWatch.stop();

          final double ramFinal = ProcessInfo.currentRss / (1024 * 1024);
          final double peakRam = ramPrefill > ramFinal ? ramPrefill : ramFinal;

          final metrics = InferenceMetrics(
            ttft: ttft ?? 0.0,
            tps: tokenCount / (generationWatch.elapsedMilliseconds / 1000.0),
            ppTps: ppTokens / (prefillWatch.elapsedMilliseconds / 1000.0),
            totalTokens: tokenCount,
            totalTime: overallWatch.elapsedMilliseconds.toDouble(),
            peakRam: peakRam,
          );

          print(
            "RescueNow Metrics: ${metrics.totalTokens} tokens | TTFT: ${metrics.ttft.toStringAsFixed(0)}ms | TPS: ${metrics.tps.toStringAsFixed(1)} | RAM: ${metrics.peakRam.toStringAsFixed(0)}MB",
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

Future<Stream<dynamic>> runLlamaStreaming(
  String prompt,
  String modelPath,
) async {
  final LlamaBaseRunner runner = ClinicalIsolateRunner();
  await runner.init(modelPath);

  final controller = StreamController<dynamic>();
  StreamSubscription? subscription;

  void cleanup() {
    subscription?.cancel();
    if (!controller.isClosed) controller.close();
    runner._isBusy = false;
  }

  subscription = runner.responses.listen(
    (msg) {
      if (controller.isClosed) return;
      if (msg is String) {
        if (msg == "___DONE___") {
          cleanup();
        } else {
          controller.add(
            msg
                .replaceAll("<end_of_turn>", "")
                .replaceAll("<start_of_turn>", ""),
          );
        }
      } else {
        controller.add(msg);
      }
    },
    onError: (e) => cleanup(),
    onDone: () => cleanup(),
  );

  runner.generate(prompt);
  return controller.stream;
}

const String _systemPrompt = """You are RescueNow, a high-accuracy multilingual clinical assistant for health workers in India.

### CRITICAL LANGUAGE RULE: 
- ALWAYS respond in the SAME LANGUAGE as the user's input.
- IF USER TYPES IN TELUGU, RESPOND ONLY IN TELUGU.
- IF USER TYPES IN HINDI, RESPOND ONLY IN HINDI.
- FORBIDDEN: Do not provide English translations or headers when the user types in a native language. 
- All checklists, Mermaid chart labels, and table contents MUST be in the user's language.

### CLINICAL PROTOCOL:
- Perform a silent assessment first.
- Provide a Checklist, then a Vertical Flowchart (flowchart TD), then an Oversight Table.
- NO ROBOTIC HEADERS: NEVER output "STAGE 1", "STAGE 2", etc.
- STRICT FORMATTING: Use **bold** for warnings and *italics* for observations.
- Use verbose clinical actions in Mermaid node IDs.

### FORMAT BLUEPRINT (EXAMPLE ONLY):
User: "Patient with severe choking"
Assistant:
**Immediate Actions:**
- [ ] Perform 5 quick, upward abdominal thrusts (Heimlich maneuver).
- [ ] If the person becomes unconscious, lower them to the ground and start CPR.
*Check the mouth for any visible obstruction before each breath during CPR.*

```mermaid
flowchart TD
    AssessAirway[Assess Airway Obstruction] --> PerformThrusts[Perform 5 Abdominal Thrusts]
    PerformThrusts --> CheckObject[Check if object is expelled]
    CheckObject --> ObjectOut[Object Expelled: Monitor breathing]
    CheckObject --> ObjectIn[Object Still Stuck: Repeat thrusts or start CPR]
```

| DO | DONT | RATIONALE |
|:---|:---|:---|
| Lean patient forward | Slap back while upright | Gravity helps object expulsion |

Always be concise. Prioritize life over perfection. Strictly generate Markdown only.
""";
