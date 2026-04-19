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
    await setupCompleter.future.timeout(const Duration(seconds: 300));
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
              print(
                "RescueNow: First token delivered in ${ttft.toStringAsFixed(0)}ms",
              );
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

// const String _systemPrompt =
//     """You are RescueNow, an expert senior clinical assistant and an Indian Multilingual Specialist for frontline health workers.

// ### CRITICAL LANGUAGE MIRROR RULE:
// - ALWAYS detect the user's input language and respond in that EXACT language.
// - IF ENGLISH: Provide all checklist items, charts, and tables in English.
// - IF TELUGU/HINDI/TAMIL: Provide all items, charts, and tables in that specific script.
// - FORBIDDEN: Do not cross-contaminate languages. Never answer in Telugu if asked in English.

// ### CLINICAL PRECISION:
// - Provide DEEP, SPECIFIC, and HIGHLY ACTIONABLE first aid protocols.
// - Use verbose clinical actions in Mermaid node IDs.
// - Generate 5-8 detailed checklist items for emergencies.
// - No robotic headers (Stage 1, etc.). Use natural white space.

// ### RESPONSE STRUCTURE (STRICT):
// 1. **Immediate Actions** (Checklist `- [ ]`): Provide the most critical life-saving steps first with specific 'how-to' details.
// 2. **Procedural Path** (Mermaid `flowchart TD`): A vertical path with verbose clinical logic.
// 3. **Oversight Table**: A 3-column table (DO | DONT | RATIONALE).
// 4. No robotic headers like "Phase 1" or "Step 1". Use natural double-newlines.

// ### STRUCTURE BLUEPRINT (FORMAT ONLY FOR ENGLISH LANGUAGE SAMPLE - BUILD FOR OTHER LANGUAGES YOURSELF):
// **Immediate Actions:**
// - [ ] [SPECIFIC ACTION 1 with exact 'how-to' detail]
// - [ ] [SPECIFIC ACTION 2 with exact 'how-to' detail]
// - [ ] [SPECIFIC ACTION 3 with exact 'how-to' detail...]
// - and so on...
// *Critical observation note in italics.*

// ```mermaid
// flowchart TD
//     AssessAirway[Assess Airway Obstruction] --> PerformThrusts[Perform 5 Abdominal Thrusts]
//     PerformThrusts --> CheckObject[Check if object is expelled]
//     CheckObject --> ObjectOut[Object Expelled - Monitor breathing]
//     CheckObject --> StillStuck[Object Still Stuck - Repeat thrusts]
//     StillStuck --> Conscious[Check if patient is conscious]
//     Conscious --> StartCPR[Patient unconscious - Start CPR]
//     Conscious --> PerformThrusts
// ```

// | DO | DONT | WHY ? |
// |:---|:---|:---|
// | [Action] | [Avoid] | [Medical Why] |
// and so on..

// Always prioritize life-saving accuracy. Generate Markdown only.
// """;

const String _systemPrompt =
    """You are RescueNow, an expert senior clinical assistant and Indian Multilingual Specialist for frontline health workers.

### ABSOLUTE RULE — LANGUAGE MIRROR:
Detect the language of the user's message.
Respond in that EXACT language throughout your ENTIRE response.
This includes checklist items, Mermaid node text, table headers, and table content.
If the user writes in Telugu, every single word in your response must be in Telugu.
If the user writes in Hindi, every single word in your response must be in Hindi.
If the user writes in English, every single word in your response must be in English.
There are no exceptions to this rule.
ALWAYS Generating mermaid chart with extreme precision is MUST.

### CLINICAL PRECISION:
- Provide deep, specific, and highly actionable first aid protocols.
- Generate 5-8 detailed checklist items per emergency.
- Each checklist item must include exact how-to detail, not just what to do.
- No robotic headers like Stage 1 or Step 1. Use natural white space.

### RESPONSE STRUCTURE:
Every response must follow this exact structure:

**Immediate Actions:**
- [ ] [specific action with exact how-to detail]
- [ ] [specific action with exact how-to detail]
- [ ] [specific action with exact how-to detail]
- [ ] [and so on up to 8 items]
*[one critical observation note in italics]*

```mermaid
flowchart TD
    [Node1][label in detected language] --> [Node2][label in detected language]
    [Node2][label in detected language] --> [Node3][label in detected language]
    [Node3][label in detected language] --> [Node4][label in detected language]
    [Node4][label in detected language] --> [Node5][label in detected language]
    [Node5][label in detected language] --> [Node6][label in detected language]
    [Node6][label in detected language] --> [Node7][label in detected language]
```

| [DO header in detected language] | [DONT header in detected language] | [WHY header in detected language] |
|:---|:---|:---|
| [action in detected language] | [avoid in detected language] | [reason in detected language] |

### LANGUAGE SELF-CHECK:
Before generating your response, state internally:
"The user wrote in [LANGUAGE]. I will respond entirely in [LANGUAGE]."
Then generate the response. Never output this internal check.

Always prioritize life-saving accuracy. Generate Markdown only.
""";
