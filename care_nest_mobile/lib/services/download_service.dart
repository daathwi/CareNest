import 'dart:io';
import 'dart:ui';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  static const String modelUrl =
      "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-IQ4_XS.gguf?download=true";

  String? _modelTaskId;
  bool _isDownloading = false;
  Timer? _pollingTimer;

  final ReceivePort _port = ReceivePort();

  Future<void> initialize() async {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      int status = data[1];
      int progress = data[2];
      _handleUpdate(id, status, progress);
    });

    await FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  Function(double)? _onProgress;
  Function(String)? _onComplete;
  Function(String)? _onError;

  void _handleUpdate(String id, int status, int progress) async {
    // We now rely on SQLite polling for bulletproof UI updates.
    // Leaving this callback registered as it is required by the engine.
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final tasks = await FlutterDownloader.loadTasks();
        if (tasks == null) return;
        
        DownloadTask? task;
        try {
          task = tasks.firstWhere((t) => t.taskId == _modelTaskId);
        } catch (_) {}

        if (task != null) {
          if (task.status == DownloadTaskStatus.failed || task.status == DownloadTaskStatus.canceled) {
            timer.cancel();
            _isDownloading = false;
            _onError?.call("Download failed or was canceled.");
          } else if (task.status == DownloadTaskStatus.complete) {
            timer.cancel();
            if (_isDownloading) {
              _isDownloading = false;
              final mPath = await getModelPath();
              _onComplete?.call(mPath);
            }
          } else if (task.status == DownloadTaskStatus.running) {
             double p = task.progress > 0 ? (task.progress / 100) : 0.001; // 0.001 to indicate connection active
             _onProgress?.call(p);
          }
        }
      } catch (e) {
        // Ignore polling read errors
      }
    });
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'models', 'gemma-4-E2B-it-IQ4_XS.gguf');
  }

  Future<Directory> _getModelsDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(directory.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<bool> isModelDownloaded() async {
    final mPath = await getModelPath();
    return await File(mPath).exists();
  }

  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(String modelPath) onComplete,
    required Function(String error) onError,
  }) async {
    if (_isDownloading) return;
    _isDownloading = true;

    _onProgress = onProgress;
    _onComplete = onComplete;
    _onError = onError;

    try {
      final modelsDir = await _getModelsDir();
      
      // To fix the "Stuck at 0.0%" bug, we force a completely clean slate
      // instead of trying to re-attach to a potentially corrupted tasks.
      await FlutterDownloader.cancelAll();
      final staleFile = File(p.join(modelsDir.path, 'gemma-4-E2B-it-IQ4_XS.gguf'));
      if (staleFile.existsSync()) {
        try { staleFile.deleteSync(); } catch (_) {}
      }

      _modelTaskId = await FlutterDownloader.enqueue(
        url: modelUrl,
        savedDir: modelsDir.path,
        fileName: 'gemma-4-E2B-it-IQ4_XS.gguf',
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
        requiresStorageNotLow: false, 
        timeout: 60000, 
      );
      
      _startPolling(); 
    } catch (e) {
      _isDownloading = false;
      onError(e.toString());
    }
  }
}
