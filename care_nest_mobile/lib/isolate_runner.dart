import 'dart:isolate';
import 'dart:typed_data';
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
    "You are CareNest, a medical assistant.\n"
    "If enough detail is given, respond with:\n"
    "1. Short overview (3 sentences)\n"
    "2. Markdown table: 4 rows max\n"
    "3. Precautions: 3 bullets, flag urgent with ⚠️\n"
    "Be concise. and no Robotic headers - always answer in Markdown format\n\n";

Future<Stream<dynamic>> runLlamaStreaming(
  String prompt,
  String modelPath,
  String projectorPath, {
  List<Uint8List>? imagesData,
  List<int>? widths,
  List<int>? heights,
}) async {
  final receivePort = ReceivePort();

  await Isolate.spawn(_entry, {
    "prompt": prompt,
    "modelPath": modelPath,
    "projectorPath": projectorPath,
    "sendPort": receivePort.sendPort,
    "imagesData": imagesData,
    "widths": widths,
    "heights": heights,
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
  final String projectorPath = args["projectorPath"];
  final SendPort sendPort = args["sendPort"];
  final List<Uint8List>? imagesData = args["imagesData"];
  final List<int>? widths = args["widths"];
  final List<int>? heights = args["heights"];

  String mediaTags = "";
  if (imagesData != null) {
    mediaTags = List.filled(imagesData.length, "<__media__>\n").join("");
  }

  // The user message is the ONLY thing that gets prefilled each turn.
  // The system prompt is already cached in the KV cache.
  final String userPrompt =
      "$mediaTags$userInput<end_of_turn>\n"
      "<start_of_turn>model\n";

  final overallWatch = Stopwatch()..start();
  final prefillWatch = Stopwatch()..start();

  try {
    final llama = LlamaService();
    llama.loadModel(modelPath, projectorPath);

    // Cache system prompt in KV once (no-op if already cached)
    llama.warmupSystemPrompt(_systemPrompt);

    // Inject Images if present
    if (imagesData != null && widths != null && heights != null) {
      llama.setImages(imagesData, widths, heights);
    }

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
