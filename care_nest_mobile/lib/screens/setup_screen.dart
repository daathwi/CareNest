import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/download_service.dart';
import '../services/voice_service.dart';

class SetupScreen extends StatefulWidget {
  final Function(String modelPath) onComplete;
  const SetupScreen({super.key, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final DownloadService _downloadService = DownloadService();
  final VoiceService _voiceService = VoiceService();
  
  bool _isDownloading = false;
  bool _voiceReady = false;
  double _progress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkVoiceHealth();
  }

  void _checkVoiceHealth() async {
    try {
      await _voiceService.init();
      setState(() => _voiceReady = true);
    } catch (e) {
      print("RescueNow: Voice Initialization Warning - $e");
    }
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });

    await _downloadService.downloadModel(
      onProgress: (p) => setState(() => _progress = p),
      onComplete: (m) => widget.onComplete(m),
      onError: (e) => setState(() {
        _error = e;
        _isDownloading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.emergency_outlined, 
                  size: 64, color: Color(0xFFE11D48)),
              ),
              const SizedBox(height: 48),
              Text(
                "Initializing\nRescueNow Core",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "RescueNow uses Gemma-4 to run a fully local AI health assistant for ASHA workers. No internet needed. No tracking. Everything happens privately on your device.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _buildVoiceIndicator(),
              const Spacer(),
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0.001 ? _progress : null,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFFE11D48),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _progress > 0.001 
                      ? "DOWNLOADING MODEL: ${(_progress * 100).toStringAsFixed(1)}%" 
                      : "CONNECTING TO SECURE SERVER...",
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ] else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(_error!, 
                      style: const TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text("Start Download", 
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security, size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "One-time setup (requires internet). After this, RescueNow is 100% offline & private for field visits.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _voiceReady ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _voiceReady ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _voiceReady ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: _voiceReady ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            _voiceReady ? "Offline Voice Protocol Ready" : "Checking Offline Voice Packs...",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _voiceReady ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
