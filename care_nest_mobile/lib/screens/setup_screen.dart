import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/download_service.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SetupScreen({super.key, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final DownloadService _downloadService = DownloadService();
  double _progress = 0;
  bool _isDownloading = false;
  String? _error;

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });

    await _downloadService.downloadModel(
      onProgress: (progress) {
        setState(() {
          _progress = progress;
        });
      },
      onComplete: (mPath, pPath) {
        widget.onComplete();
      },
      onError: (error) {
        setState(() {
          _error = error;
          _isDownloading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  size: 64,
                  color: Color(0xFF006D5B),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                "Initializing\nCareNest Core",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "CareNest uses Gemma 4 to run a fully local AI medical assistant. No servers, no tracking. Everything happens privately on your device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              if (_isDownloading) ...[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006D5B)),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "DOWNLOADING MODEL: ${(_progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                    color: Color(0xFF006D5B),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF006D5B),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006D5B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Start Download",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Exit Setup", style: TextStyle(fontSize: 16)),
                ),
              ],
              const SizedBox(height: 48),
              const Divider(color: Color(0xFFCBD5E1)),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "One-time setup (requires internet). After this, you’re 100% offline & private.",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    "Network Error: $_error",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
