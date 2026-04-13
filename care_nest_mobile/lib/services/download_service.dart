import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  
  static const String modelUrl = 
      "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_1.gguf?download=true";
  
  static const String projectorUrl = 
      "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/mmproj-F16.gguf?download=true";

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/models/gemma-4-E2B-it-Q4_1.gguf';
  }

  Future<String> getProjectorPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/models/mmproj-F16.gguf';
  }

  Future<Directory> _getModelsDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<bool> isModelDownloaded() async {
    final mPath = await getModelPath();
    final pPath = await getProjectorPath();
    return await File(mPath).exists() && await File(pPath).exists();
  }

  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(String modelPath, String projectorPath) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      await _getModelsDir();
      final mPath = await getModelPath();
      final pPath = await getProjectorPath();

      // Estimated sizes for weighted progress (GGUF ~2GB, mmproj ~200MB)
      const double modelWeight = 0.9;
      const double projectorWeight = 0.1;

      // 1. Download Model Brain
      await _dio.download(
        modelUrl,
        mPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = (received / total) * modelWeight;
            onProgress(progress);
          }
        },
      );

      // 2. Download Vision Projector
      await _dio.download(
        projectorUrl,
        pPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = modelWeight + ((received / total) * projectorWeight);
            onProgress(progress);
          }
        },
      );

      onComplete(mPath, pPath);
    } catch (e) {
      onError(e.toString());
    }
  }
}
