import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'isolate_runner.dart';
import 'services/download_service.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import 'screens/setup_screen.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("RescueNow: Initializing Application Services...");
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  final downloadService = DownloadService();
  await downloadService.initialize();
  final isReady = await downloadService.isModelDownloaded();

  if (isReady) {
    print("RescueNow: GGUF Model detected. Preparing for inference.");
  } else {
    print("RescueNow: Model missing. Redirecting to Setup Screen.");
  }

  runApp(RescueNowApp(isReady: isReady));
}

class RescueNowApp extends StatelessWidget {
  final bool isReady;
  const RescueNowApp({super.key, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RescueNow AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D5B),
          brightness: Brightness.light,
          primary: const Color(0xFF006D5B),
          surface: const Color(0xFFFFFFFF),
          background: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.outfitTextTheme().copyWith(
          displayLarge: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
            letterSpacing: -1.0,
          ),
          headlineMedium: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
          titleLarge: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
          bodyLarge: GoogleFonts.outfit(
            fontSize: 17,
            height: 1.6,
            color: const Color(0xFF334155),
            letterSpacing: 0.2,
          ),
          bodyMedium: GoogleFonts.outfit(
            fontSize: 15,
            height: 1.5,
            color: const Color(0xFF475569),
          ),
          labelSmall: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: isReady
          ? const HomeScreen()
          : Builder(
              builder: (context) => SetupScreen(
                onComplete: (mPath) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),
            ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  "Welcome to\nRescueNow",
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  "Choose your interaction mode",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 60),
                _buildModeCard(
                  context,
                  title: "Start Assistant",
                  description:
                      "Deep clinical analysis through text and document scanning.",
                  icon: Icons.chat_bubble_rounded,
                  color: const Color(0xFF1E293B),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showResetDialog(context),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Reset Model Data"),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const Spacer(),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Powered by Gemma 4 • Fully Offline",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Model?"),
        content: const Text(
          "This will delete the local Gemma 4 model and trigger a re-download. Use this if the model is corrupted or not responding.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final mPath = await DownloadService().getModelPath();
              if (await File(mPath).exists()) await File(mPath).delete();

              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SetupScreen(
                      onComplete: (mPath) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text("Delete & Reset"),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFFCBD5E1),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTableBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CustomTableBuilder(this.context);

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    List<Widget> headerWidgets = [];
    List<List<Widget>> rowWidgets = [];

    for (var child in element.children ?? []) {
      if (child is md.Element && child.tag == 'thead') {
        for (var tr in child.children ?? []) {
          if (tr is md.Element && tr.tag == 'tr') {
            for (var th in tr.children ?? []) {
              headerWidgets.add(
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    th.textContent,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              );
            }
          }
        }
      }
      if (child is md.Element && child.tag == 'tbody') {
        for (var tr in child.children ?? []) {
          if (tr is md.Element && tr.tag == 'tr') {
            List<Widget> rowCells = [];
            for (var td in tr.children ?? []) {
              rowCells.add(
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    td.textContent,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }
            if (rowCells.isNotEmpty) rowWidgets.add(rowCells);
          }
        }
      }
    }

    final int colCount = headerWidgets.isEmpty ? 0 : headerWidgets.length;
    if (colCount == 0 && rowWidgets.isNotEmpty) return const SizedBox();
    if (headerWidgets.isEmpty && rowWidgets.isEmpty) return const SizedBox();

    const double colWidth = 180.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        thumbVisibility: true,
        thickness: 4.0,
        radius: const Radius.circular(2),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(colWidth),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: const Color(0xFFE2E8F0).withOpacity(0.6),
                width: 0.5,
              ),
              verticalInside: BorderSide(
                color: const Color(0xFFE2E8F0).withOpacity(0.6),
                width: 0.5,
              ),
            ),
            children: [
              if (headerWidgets.isNotEmpty)
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: headerWidgets
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: w,
                        ),
                      )
                      .toList(),
                ),
              ...rowWidgets.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: idx % 2 == 1
                        ? const Color(0xFFF8FAFC)
                        : Colors.white,
                  ),
                  children: row
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: w,
                        ),
                      )
                      .toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomBlockquoteBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF006D5B).withOpacity(0.04),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        border: const Border(
          left: BorderSide(color: Color(0xFF006D5B), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF006D5B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: Color(0xFF006D5B),
              size: 14,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              element.textContent,
              style: GoogleFonts.outfit(
                color: const Color(0xFF193A36),
                height: 1.6,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  String text;
  final bool isUser;
  bool isStreaming;
  Map<String, dynamic>? metrics;
  final String? imagePath;
  final Map<String, String>? vitals;

  Message({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.metrics,
    this.imagePath,
    this.vitals,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final DownloadService _downloadService = DownloadService();
  String? _modelPath;
  bool _isLoadingModel = true;
  Map<String, dynamic>? _lastMetrics;
  StreamSubscription? _inferenceSubscription;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  @override
  void dispose() {
    _inferenceSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    ClinicalIsolateRunner().stop();
    super.dispose();
  }

  Future<void> _initModel() async {
    try {
      final mPath = await _downloadService.getModelPath();
      setState(() {
        _modelPath = mPath;
        _isLoadingModel = false;
        _messages.add(
          Message(
            text:
                "RescueNow active. Engine running in **Clinical CPU Mode** for maximum stability.",
            isUser: false,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isLoadingModel = false;
        _messages.add(
          Message(text: "Error initializing AI: $e", isUser: false),
        );
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) async {
    if (text.trim().isEmpty) return;
    if (_modelPath == null) {
      print(
        "RescueNow Error: Attempted to send prompt before model initialization.",
      );
      return;
    }

    print(
      "RescueNow: Incoming Clinical Observation: '${text.substring(0, text.length > 30 ? 30 : text.length)}...'",
    );

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _controller.clear();
      _messages.add(Message(text: "", isUser: false, isStreaming: true));
      _lastMetrics = null;
    });
    _scrollToBottom();
    try {
      final stream = await runLlamaStreaming(text, _modelPath!);
      String fullResponse = "";
      _inferenceSubscription = stream.listen(
        (event) {
          if (!mounted) return;
          if (event is String) {
            setState(() {
              fullResponse += event;
              _messages.last = Message(text: fullResponse, isUser: false, isStreaming: true);
            });
            _scrollToBottom();
          } else if (event is Map<String, dynamic>) {
            setState(() {
              _lastMetrics = event;
              _messages.last.metrics = event;
            });
          }
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _messages.last.isStreaming = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.last = Message(text: "Error: $e", isUser: false));
    }
  }

  void _showEncouragementModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF006D5B), size: 52),
            ),
            const SizedBox(height: 24),
            Text(
              "Excellent Triage!",
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            const Text(
              "You have completed all actions in the protocol. Continue monitoring the patient's vitals closely.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006D5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Continue Monitoring", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF006D5B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Text("RescueNow"),
          ],
        ),
      ),
      body: Column(
        children: [
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return msg.isUser
                    ? _buildUserMessage(msg)
                    : _buildAssistantMessage(msg);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildUserMessage(Message msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (msg.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(msg.imagePath!),
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    msg.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(Message msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isStreaming || msg.text.isNotEmpty)
            ..._parseMessageWithMermaid(msg, msg.isStreaming),
          if (msg.isStreaming && msg.text.isEmpty) _buildLoadingWidget(),
          if (msg.metrics != null && !msg.isStreaming)
            _buildPerformanceReport(msg.metrics!),
        ],
      ),
    );
  }

  List<Widget> _parseMessageWithMermaid(Message msg, bool isStreaming) {
    final String text = msg.text;
    if (text.isEmpty && isStreaming)
      return [
        const Text(
          "●",
          style: TextStyle(color: Color(0xFF5A877E), fontSize: 18),
        ),
      ];

    final style = MarkdownStyleSheet(
      p: Theme.of(context).textTheme.bodyLarge,
      h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF006D5B),
        fontWeight: FontWeight.w700,
      ),
      tableHead: const TextStyle(fontWeight: FontWeight.bold),
    );

    final List<Widget> finalWidgets = [];

    // 1. Identify and extract INTERACTIVE CHECKLIST items
    final checklistRegex = RegExp(
      r'^\s*-\s*\[([ xX])\]\s*(.*)$',
      multiLine: true,
    );
    final checklistMatches = checklistRegex.allMatches(text).toList();

    if (checklistMatches.isNotEmpty) {
      final List<Widget> checklistTiles = [];
      final lines = text.split('\n');

      for (int i = 0; i < checklistMatches.length; i++) {
        final match = checklistMatches[i];
        final isChecked = match.group(1)!.toLowerCase() == 'x';
        final content = match.group(2)!;

        // Find the absolute line index for this specific match
        int absoluteLineIndex = -1;
        int currentOffset = 0;
        for (int l = 0; l < lines.length; l++) {
          final lineStart = text.indexOf(lines[l], currentOffset);
          if (lineStart <= match.start &&
              (lineStart + lines[l].length) >= match.end) {
            absoluteLineIndex = l;
            break;
          }
          currentOffset = lineStart + lines[l].length;
        }

        checklistTiles.add(
          _buildInteractiveCheckTile(
            content: content,
            isChecked: isChecked,
            onToggle: () {
              print(
                "RescueNow: UI Checklist Interaction - Toggling absolute line: $absoluteLineIndex",
              );
              if (absoluteLineIndex != -1) {
                setState(() {
                  final currentLines = msg.text.split('\n');
                  final target = isChecked ? "[x]" : "[ ]";
                  final replacement = isChecked ? "[ ]" : "[x]";
                  currentLines[absoluteLineIndex] =
                      currentLines[absoluteLineIndex].replaceFirst(
                        target,
                        replacement,
                      );
                  msg.text = currentLines.join('\n');
                  
                  // Check if all items are now ticked off
                  final updatedText = msg.text;
                  if (!updatedText.contains("[ ]")) {
                    _showEncouragementModal();
                  }
                });
              }
            },
          ),
        );
      }
      finalWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 24, top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: checklistTiles),
        ),
      );
      finalWidgets.add(const SizedBox(height: 24));
    }

    // 2. Remove checklist from bodyText to avoid duplicate rendering
    String filteredText = text.replaceAll(checklistRegex, "").trim();
    final String bodyText = _cleanText(filteredText);

    // 3. Render Mermaid and Markdown
    final RegExp mermaidExp = RegExp(r'```mermaid\s*\n?([\s\S]*?)(```|$)');
    final matches = mermaidExp.allMatches(bodyText);

    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        final content = bodyText.substring(lastEnd, match.start);
        if (content.trim().isNotEmpty) {
          finalWidgets.add(
            MarkdownBody(
              data: content,
              builders: {
                'table': CustomTableBuilder(context),
                'blockquote': CustomBlockquoteBuilder(),
              },
              styleSheet: style,
            ),
          );
        }
      }
      final mermaidCode = match.group(1) ?? '';
      if (isStreaming && match.group(2) != '```') {
        finalWidgets.add(_buildMermaidLoadingPlaceholder());
      } else if (mermaidCode.trim().isNotEmpty) {
        finalWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: MermaidDiagram(
                code: _sanitizeMermaid(mermaidCode),
                style: MermaidStyle(backgroundColor: 0xFFFAF9F6),
              ),
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < bodyText.length) {
      final content = bodyText.substring(lastEnd);
      if (content.trim().isNotEmpty) {
        finalWidgets.add(const SizedBox(height: 24));
        finalWidgets.add(
          MarkdownBody(
            data: content,
            builders: {
              'table': CustomTableBuilder(context),
              'blockquote': CustomBlockquoteBuilder(),
            },
            styleSheet: style,
          ),
        );
      }
    }

    // Final spacing for readability
    finalWidgets.add(const SizedBox(height: 24));

    return finalWidgets;
  }

  Widget _buildInteractiveCheckTile({
    required String content,
    required bool isChecked,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isChecked
                  ? Icons.task_alt_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isChecked
                  ? const Color(0xFF006D5B)
                  : const Color(0xFFCBD5E1),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: isChecked
                      ? const Color(0xFF64748B)
                      : const Color(0xFF1E293B),
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  fontWeight: isChecked ? FontWeight.normal : FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMermaidLoadingPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF006D5B).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF006D5B).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006D5B)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Synthesizing Clinical Path...",
            style: GoogleFonts.outfit(
              color: const Color(0xFF006D5B),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Drafting secure local diagram",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  String _cleanText(String text) {
    // Stop stripping ALL backticks. Only remove the specific 'markdown' wrapper if it exists at the start/end
    String t = text.trim();
    if (t.startsWith('```markdown')) t = t.replaceFirst('```markdown', '');
    if (t.endsWith('```') && !t.contains('```mermaid'))
      t = t.substring(0, t.length - 3);
    return t.trim();
  }

  String _sanitizeMermaid(String code) {
    String trimmed = code.trim();
    // Ensure all charts are vertical flowcharts for mobile readability
    if (!trimmed.toLowerCase().contains('flowchart') &&
        !trimmed.toLowerCase().contains('graph')) {
      trimmed = "flowchart TD\n$trimmed";
    }
    return trimmed;
  }

  Widget _buildPerformanceReport(Map<String, dynamic> metrics) {
    return ExpansionTile(
      title: const Text(
        "View performance",
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric("Prompt", metrics['ppTps']),
              _metric("Token", metrics['tps']),
              _metric("TTFT", metrics['ttft']),
              _metric("RAM", metrics['peakRam']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, dynamic val) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 10)),
      Text(
        "${val?.toStringAsFixed(1)}",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );

  Widget _buildLoadingWidget() => const Row(
    children: [
      CircularProgressIndicator(strokeWidth: 2),
      SizedBox(width: 12),
      Text("Analyzing..."),
    ],
  );

  Widget _buildInputArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Enter clinical observation...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF006D5B),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => _handleSend(_controller.text),
            ),
          ),
        ],
      ),
    );
  }
}
