import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'isolate_runner.dart';
import 'services/download_service.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final downloadService = DownloadService();
  final isReady = await downloadService.isModelDownloaded();

  runApp(CareNestApp(isReady: isReady));
}

class CareNestApp extends StatelessWidget {
  final bool isReady;
  const CareNestApp({super.key, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareNest AI',
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
          displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), letterSpacing: -1.0),
          headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          bodyLarge: GoogleFonts.outfit(fontSize: 17, height: 1.6, color: const Color(0xFF334155), letterSpacing: 0.2),
          bodyMedium: GoogleFonts.outfit(fontSize: 15, height: 1.5, color: const Color(0xFF475569)),
          labelSmall: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 1.2),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      home: isReady 
          ? const ChatScreen() 
          : Builder(
              builder: (context) => SetupScreen(
                onComplete: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
            ),
    );
  }
}

class CustomTableBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    List<Widget> headerWidgets = [];
    List<List<Widget>> rowWidgets = [];
    
    for (var child in element.children ?? []) {
      if (child is md.Element && child.tag == 'thead') {
        for (var tr in child.children ?? []) {
          if (tr is md.Element && tr.tag == 'tr') {
            for (var th in tr.children ?? []) {
              headerWidgets.add(Padding(
                padding: const EdgeInsets.all(12),
                child: Text(th.textContent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
              ));
            }
          }
        }
      }
      if (child is md.Element && child.tag == 'tbody') {
        for (var tr in child.children ?? []) {
          if (tr is md.Element && tr.tag == 'tr') {
            List<Widget> rowCells = [];
            for (var td in tr.children ?? []) {
              rowCells.add(Padding(
                padding: const EdgeInsets.all(12),
                child: Text(td.textContent, style: const TextStyle(fontSize: 15, color: Color(0xFF475569))),
              ));
            }
            if (rowCells.isNotEmpty) rowWidgets.add(rowCells);
          }
        }
      }
    }
    
    // Build a data model first so we can calculate fixed column widths
    final int colCount = headerWidgets.isEmpty ? 0 : headerWidgets.length;
    if (colCount == 0 && rowWidgets.isNotEmpty) return const SizedBox();
    if (headerWidgets.isEmpty && rowWidgets.isEmpty) return const SizedBox();

    const double colWidth = 160.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(colWidth),
          border: TableBorder(
            horizontalInside: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 0.5),
            verticalInside: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 0.5),
          ),
          children: [
            if (headerWidgets.isNotEmpty)
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                children: headerWidgets.map((w) => SizedBox(
                  width: colWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: w,
                  ),
                )).toList(),
              ),
            ...rowWidgets.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: idx % 2 == 1 ? const Color(0xFFF8FAFC) : Colors.white,
                ),
                children: row.map((w) => SizedBox(
                  width: colWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: w,
                  ),
                )).toList(),
              );
            }),
          ],
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
            child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF006D5B), size: 14),
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
  final String text;
  final bool isUser;
  bool isStreaming;
  Map<String, dynamic>? metrics;

  Message({
    required this.text, 
    required this.isUser, 
    this.isStreaming = false,
    this.metrics,
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

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      final mPath = await _downloadService.getModelPath();
      setState(() {
        _modelPath = mPath;
        _isLoadingModel = false;
        _messages.add(Message(
          text: "CareNest active. I'm ready for your medical queries.",
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _isLoadingModel = false;
        _messages.add(Message(text: "Error initializing AI: $e", isUser: false));
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
    if (_modelPath == null) return;

    setState(() {
      _messages.add(Message(
        text: text, 
        isUser: true,
      ));
      _controller.clear();
      _messages.add(Message(text: "", isUser: false, isStreaming: true));
      _lastMetrics = null;
    });
    _scrollToBottom();

    String conversationContext = "";
    int contextCount = 0;
    for (int i = _messages.length - 2; i >= 0 && contextCount < 3; i--) {
      final msg = _messages[i];
      if (msg.text.isNotEmpty && !msg.text.contains("```mermaid")) {
        // Hard cap each message at 200 chars to prevent long responses from bloating prefill
        final snippet = msg.text.length > 200 ? msg.text.substring(0, 200) : msg.text;
        conversationContext = "${msg.isUser ? 'User' : 'Assistant'}: $snippet\n" + conversationContext;
        contextCount++;
      }
    }

    String finalPrompt = text;
    if (conversationContext.isNotEmpty) {
      finalPrompt = "PREVIOUS HISTORY FOR CONTEXT:\n$conversationContext\n\nCURRENT QUERY:\n$text";
    }

    try {
      final stream = await runLlamaStreaming(
        finalPrompt, 
        _modelPath!,
      );
      
      String fullResponse = "";
      stream.listen((event) {
        if (event is String) {
          setState(() {
            fullResponse += event;
            _messages.last = Message(
              text: fullResponse, 
              isUser: false,
              isStreaming: true,
            );
          });
          _scrollToBottom();
        } else if (event is Map<String, dynamic> && event["type"] == "metrics") {
          setState(() {
            _lastMetrics = event;
            _messages.last.metrics = event;
          });
        }
      }, onDone: () {
        setState(() {
          _messages.last.isStreaming = false;
        });
      });
      
    } catch (e) {
      setState(() {
        _messages.last = Message(text: "Error: $e", isUser: false);
      });
    }
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
              child: const Icon(Icons.shield_rounded, color: Color(0xFF006D5B), size: 24),
            ),
            const SizedBox(width: 14),
            const Text("CareNest"),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: const [
                  Icon(Icons.circle, color: Color(0xFF006D5B), size: 8),
                  SizedBox(width: 8),
                  Text(
                    "Secure AI",
                    style: TextStyle(color: Color(0xFF006D5B), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // TODAY Divider
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return msg.isUser ? _buildUserMessage(msg) : _buildAssistantMessage(msg);
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
          const SizedBox(width: 48), // Padding from left
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006D5B).withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanText(String text) {
    String cleaned = text.trim();
    // Strip ```markdown ... ``` or ``` ... ``` wrappers if they encapsulate the text
    if (cleaned.startsWith('```markdown')) {
      cleaned = cleaned.replaceFirst('```markdown', '').trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    } else if (cleaned.startsWith('```') && !cleaned.startsWith('```mermaid')) {
      // Only strip generic backticks if they appear to be a wrapper (matching pair at start/end)
      // but be careful not to strip if it's just a starting backtick for a different block
      RegExp wrapper = RegExp(r'^```\w*\n?([\s\S]*)\n?```$', multiLine: true);
      final match = wrapper.firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1)?.trim() ?? cleaned;
      }
    }
    return cleaned;
  }

  List<Widget> _parseMessageWithMermaid(String text, bool isStreaming) {
    if (text.isEmpty && isStreaming) {
      return [const Text("●", style: TextStyle(color: Color(0xFF5A877E), fontSize: 18))];
    }

    final String processedText = _cleanText(text);

    final textTheme = Theme.of(context).textTheme;
    final style = MarkdownStyleSheet(
      p: textTheme.bodyLarge,
      strong: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
      em: textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF334155)),
      h1: textTheme.headlineSmall?.copyWith(color: const Color(0xFF006D5B), fontWeight: FontWeight.w700),
      h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
      h2: textTheme.titleLarge?.copyWith(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
      h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
      h3: textTheme.titleMedium?.copyWith(color: const Color(0xFF475569), fontWeight: FontWeight.w600),
      h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
      listBullet: textTheme.bodyLarge?.copyWith(color: const Color(0xFF006D5B)),
      blockquote: textTheme.bodyMedium?.copyWith(color: const Color(0xFF006D5B), fontStyle: FontStyle.italic),
      tableHead: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
      tableBody: textTheme.bodyMedium,
      code: GoogleFonts.firaCode(fontSize: 13, backgroundColor: const Color(0xFFF1F5F9), color: const Color(0xFF006D5B)),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      pPadding: const EdgeInsets.only(bottom: 12),
      blockSpacing: 16,
      listIndent: 28,
      listBulletPadding: const EdgeInsets.only(right: 12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: const Color(0xFFCBD5E1), width: 1.0)),
      ),
    );

    final List<Widget> finalWidgets = [];
    final RegExp exp = RegExp(r'```mermaid\s*\n?([\s\S]*?)(```|$)');
    final matches = exp.allMatches(processedText);
    
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        finalWidgets.add(MarkdownBody(
          data: processedText.substring(lastEnd, match.start),
          extensionSet: md.ExtensionSet.gitHubFlavored,
          builders: {
            'table': CustomTableBuilder(),
            'blockquote': CustomBlockquoteBuilder(),
          },
          styleSheet: style,
        ));
      }
      
      final mermaidCode = match.group(1) ?? '';
      final isClosed = match.group(2) == '```';
      String safeMermaid = _sanitizeMermaid(mermaidCode);
      
      if (isStreaming && !isClosed) {
        // Show a placeholder while the diagram is still being typed out
        finalWidgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6), // Match Canvas
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF006D5B)),
                ),
                const SizedBox(width: 16),
                Text(
                  "Generating Clinical Path...",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF006D5B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Only attempt to render the actual Mermaid diagram if it's closed (or stream finished)
        if (safeMermaid.isNotEmpty && safeMermaid.length > 20) {
          const mermaidStyle = MermaidStyle(
            backgroundColor: 0xFFFAF9F6, // Match Canvas
            defaultNodeStyle: NodeStyle(
              fillColor: 0xFFE6F4F1,    
              strokeColor: 0xFF006D5B,  
              textColor: 0xFF1E293B,    
            ),
            defaultEdgeStyle: EdgeStyle(strokeColor: 0xFF006D5B),
            nodeSpacingX: 50,
            nodeSpacingY: 60,
            padding: 20,
          );

          finalWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width - 40;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 100,
                      maxWidth: availableWidth,
                    ),
                    child: MermaidDiagram(
                      code: safeMermaid,
                      style: mermaidStyle,
                      width: availableWidth,
                      errorBuilder: (context, error) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("Clinic Analysis Rendering... ($error)", style: const TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
      
      lastEnd = match.end;
    }
    
    if (lastEnd < processedText.length) {
      finalWidgets.add(MarkdownBody(
        data: processedText.substring(lastEnd),
        extensionSet: md.ExtensionSet.gitHubFlavored,
        builders: {
          'table': CustomTableBuilder(),
          'blockquote': CustomBlockquoteBuilder(),
        },
        styleSheet: style,
      ));
    }
    
    return finalWidgets;
  }

  String _sanitizeMermaid(String code) {
    String trimmed = code.trim();
    if (trimmed.isEmpty) return "";
    
    // 1. Ensure flowchart TD header
    if (!trimmed.toLowerCase().startsWith('graph') && !trimmed.toLowerCase().startsWith('flowchart')) {
      trimmed = "flowchart TD\n$trimmed";
    }

    List<String> lines = trimmed.split('\n');
    List<String> sanitizedLines = [];
    int nodeCounter = 1;
    Map<String, String> labelToId = {};

    for (var line in lines) {
      String l = line.trim();
      if (l.isEmpty || l.toLowerCase().startsWith('flowchart') || l.toLowerCase().startsWith('graph')) {
        sanitizedLines.add(l);
        continue;
      }

      // Handle raw [Text] --> [More Text] which LLMs like to output but crashes this library
      // We look for any [bracketed text] and ensure it has an ID prefix
      l = l.replaceAllMapped(RegExp(r'(\s|^)\[([^\]]+)\]'), (match) {
        String label = match.group(2)!;
        if (!labelToId.containsKey(label)) {
          labelToId[label] = "n${nodeCounter++}";
        }
        return "${match.group(1)}${labelToId[label]}[$label]";
      });

      // Handle IDs with spaces like "Step 1[Text]" which also crashes
      l = l.replaceAllMapped(RegExp(r'([\w\s]+)\[([^\]]+)\]'), (match) {
        String idPart = match.group(1)!.trim().replaceAll(' ', '_');
        String labelPart = match.group(2)!;
        return "$idPart[$labelPart]";
      });

      // Strip forbidden shapes {} and () for vertical clinical path
      l = l.replaceAll('{', '[').replaceAll('}', ']').replaceAll('(', '[').replaceAll(')', ']');
      
      sanitizedLines.add(l);
    }

    return sanitizedLines.join('\n');
  }

  Widget _buildAssistantMessage(Message msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isStreaming || msg.text.isNotEmpty)
            ..._parseMessageWithMermaid(msg.text, msg.isStreaming),
          if (msg.isStreaming && msg.text.isEmpty)
            _buildLoadingWidget(),
          if (msg.metrics != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${(msg.metrics!['tps'] as double).toStringAsFixed(1)} t/s",
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF5A877E),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            "Analyzing health data...",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Ask CareNest...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _handleSend(_controller.text),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Color(0xFF006D5B), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
