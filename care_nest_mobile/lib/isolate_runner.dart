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

// The system prompt is SEPARATED from the user message.
// It gets cached in the KV cache once, and never re-processed.
const String _systemPrompt =
    "<start_of_turn>user\n"
    "You are CareNest, a helpful and precise medical assistant. Respond in Markdown.\n"
    "1. Use standard Markdown formatting with headers, bullet points, bold text, and italics where appropriate.\n"
    "2. FLOWCHARTS: For any step-by-step process, include a Mermaid diagram. ALWAYS wrap it in ```mermaid ... ```. Use `flowchart TD`.\n"
    "   CRITICAL NODE RULES - follow exactly:\n"
    "   - Nodes MUST have a unique ID followed by a label in square brackets: S1[Clinical Step]\n"
    "   - NEVER omit the ID: WRONG: [Patient presents]; CORRECT: P1[Patient presents]\n"
    "   - NEVER use curly braces {} or round brackets ().\n"
    "   - Connections are ONLY top-to-bottom vertical: S1 --> S2 --> S3\n"
    "   - NEVER branch left or right. Only one path, straight down.\n"
    "   - CORNER CASE: Ensure IDs have no spaces. Use CamelCase or underscores for IDs.\n"
    "   CORRECT example: Init[Patient presents] --> Assessment[Assess symptoms] --> Labs[Run blood tests] --> Dx[Diagnose condition]\n"
    "3. TABLES: For comparisons, use Markdown tables. Keep content concise per cell.\n"
    "4. PRECAUTIONS: List urgent safety points with ⚠️.\n"
    "Output raw Markdown only. ALWAYS use ID[Label] for flowchart nodes. NEVER branch horizontally.<end_of_turn>\n\n";

Future<Stream<dynamic>> runLlamaStreaming(
  String prompt,
  String modelPath,
) async {
  final receivePort = ReceivePort();

  await Isolate.spawn(_entry, {
    "prompt": prompt,
    "modelPath": modelPath,
    "sendPort": receivePort.sendPort,
  });

  bool isFirstToken = true;

  return receivePort
      .map((message) {
        if (message is String) {
          if (message == "___DONE___") {
            receivePort.close();
            return null;
          }

          String filtered = message
              .replaceAll("<end_of_turn>", "")
              .replaceAll("<start_of_turn>", "");

          if (isFirstToken) {
            String cleaned = filtered.trimLeft();
            if (cleaned.isNotEmpty) {
              isFirstToken = false;
              return cleaned;
            }
            return null;
          }
          return filtered;
        }
        return message;
      })
      .where((msg) => msg != null);
}

void _entry(Map args) {
  final String userInput = args["prompt"];
  final String modelPath = args["modelPath"];
  final SendPort sendPort = args["sendPort"];

  // The user message is the ONLY thing that gets prefilled each turn.
  // The system prompt is already cached in the KV cache.
  final String userPrompt =
      "$userInput<end_of_turn>\n"
      "<start_of_turn>model\n";

  final overallWatch = Stopwatch()..start();
  final prefillWatch = Stopwatch()..start();

  try {
    final llama = LlamaService();
    llama.loadModel(modelPath);

    // Cache system prompt in KV once (no-op if already cached)
    llama.warmupSystemPrompt(_systemPrompt);

    // Only the user message gets prefilled — system prompt KV is reused
    if (!llama.setPrompt(userPrompt)) {
      sendPort.send("Error: Failed to process multimodal prompt.");
      sendPort.send("___DONE___");
      return;
    }

    double? ttft;
    int tokenCount = 0;
    final generationWatch = Stopwatch();

    for (int i = 0; i < 1024; i++) {
      final token = llama.getNextToken();
      if (token == null) break;

      if (tokenCount == 0) {
        ttft = prefillWatch.elapsedMilliseconds.toDouble();
        generationWatch.start();
      }

      sendPort.send(token);
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

    sendPort.send(metrics.toMap());
    sendPort.send("___DONE___");
  } catch (e) {
    sendPort.send("Error: $e");
    sendPort.send("___DONE___");
  }
}
