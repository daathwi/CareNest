import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:typed_data';
import 'isolate_runner.dart';
import 'vision_service.dart';
import 'services/download_service.dart';
import 'package:image_picker/image_picker.dart';
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
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D5B), // Primary Medical Teal
          brightness: Brightness.light,
          surface: const Color(0xFFFFFFFF),
          background: const Color(0xFFF9FAFB),
        ),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme).copyWith(
          bodyLarge: GoogleFonts.outfit(color: const Color(0xFF1E293B)),
          bodyMedium: GoogleFonts.outfit(color: const Color(0xFF334155)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9FAFB),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
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
                child: Text(th.textContent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
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
                child: Text(td.textContent, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ));
            }
            if (rowCells.isNotEmpty) rowWidgets.add(rowCells);
          }
        }
      }
    }
    
    if (headerWidgets.isEmpty && rowWidgets.isNotEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.symmetric(inside: const BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: headerWidgets,
            ),
            ...rowWidgets.map((row) => TableRow(children: row)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006D5B).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF006D5B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              element.textContent,
              style: const TextStyle(color: Color(0xFF006D5B), height: 1.5, fontSize: 13),
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
  final List<Uint8List>? images;
  Map<String, dynamic>? metrics;

  Message({
    required this.text, 
    required this.isUser, 
    this.isStreaming = false,
    this.images,
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
  final VisionService _visionService = VisionService();
  final DownloadService _downloadService = DownloadService();
  
  String? _modelPath;
  String? _projectorPath;
  bool _isLoadingModel = true;
  bool _isScanning = false;
  Map<String, dynamic>? _lastMetrics;  
  List<VisionResult> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      final mPath = await _downloadService.getModelPath();
      final pPath = await _downloadService.getProjectorPath();
      setState(() {
        _modelPath = mPath;
        _projectorPath = pPath;
        _isLoadingModel = false;
        _messages.add(Message(
          text: "CareNest Pro active. I can now see and analyze medical images and reports directly using Gemma 4.",
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

  Future<void> _handleImagePick(ImageSource source) async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can attach only max 3 files only", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isScanning = true);
    
    final result = await _visionService.pickAndProcessImage(
      source: source,
      totalAttachments: _selectedImages.length + 1
    );
    
    setState(() {
      _isScanning = false;
      if (result != null) {
        _selectedImages.add(result);
      }
    });
  }

  void _handleSend(String text) async {
    if (text.trim().isEmpty && _selectedImages.isEmpty) return;
    if (_modelPath == null || _projectorPath == null) return;

    final imagesToDisplay = _selectedImages.map((e) => e.displayBytes).toList();
    final imagesToModel = _selectedImages.map((e) => e.rawBytes).toList();
    final widths = _selectedImages.map((e) => e.width).toList();
    final heights = _selectedImages.map((e) => e.height).toList();

    setState(() {
      _messages.add(Message(
        text: text, 
        isUser: true,
        images: imagesToDisplay.isNotEmpty ? imagesToDisplay : null,
      ));
      _controller.clear();
      _selectedImages.clear();
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
        _projectorPath!,
        imagesData: imagesToModel.isNotEmpty ? imagesToModel : null,
        widths: widths.isNotEmpty ? widths : null,
        heights: heights.isNotEmpty ? heights : null,
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
        elevation: 0,
        backgroundColor: const Color(0xFFFAF9F6),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF5A877E), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("CareNest", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Color(0xFF1E293B))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB2DFDB))),
              child: Row(
                children: const [
                  Icon(Icons.circle, color: Color(0xFF006D5B), size: 8),
                  SizedBox(width: 6),
                  Text("AI Doctor Online", style: TextStyle(color: Color(0xFF006D5B), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          ],
        ),
      ),
      body: Column(
        children: [
          // Suggestions row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildSuggestionPill("I have a headache"),
                _buildSuggestionPill("Check my symptoms"),
                _buildSuggestionPill("Medication quick check"),
              ],
            ),
          ),
          // TODAY Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text("TODAY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.2)),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
          ),
          if (_isScanning) const LinearProgressIndicator(color: Color(0xFF006D5B), backgroundColor: Colors.white),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildSuggestionPill(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
    );
  }



  Widget _buildUserMessage(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF193A36), // Dark Teal User bubble
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (msg.images != null && msg.images!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.images!.map((imgBytes) {
                        return Container(
                          height: 80,
                          width: 80,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: MemoryImage(imgBytes),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (msg.text.isNotEmpty)
                    Text(msg.text, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _parseMessageWithMermaid(String text, bool isStreaming) {
    if (text.isEmpty && isStreaming) {
      return [const Text("●", style: TextStyle(color: Color(0xFF5A877E), fontSize: 18))];
    }

    final style = MarkdownStyleSheet(
      p: GoogleFonts.outfit(fontSize: 15, height: 1.6, color: const Color(0xFF334155)),
      h1: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
      h2: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
      h3: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
      listBullet: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF334155)),
      blockquote: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF006D5B)),
      tableHead: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
      tableBody: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
    );

    final List<Widget> widgets = [];
    final RegExp exp = RegExp(r'```mermaid\n([\s\S]*?)(```|$)');
    final matches = exp.allMatches(text);
    
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        widgets.add(MarkdownBody(
          data: text.substring(lastEnd, match.start),
          extensionSet: md.ExtensionSet.gitHubFlavored,
          builders: {
            'table': CustomTableBuilder(),
            'blockquote': CustomBlockquoteBuilder(),
          },
          styleSheet: style,
        ));
      }
      
      final mermaidCode = match.group(1) ?? '';
      widgets.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MermaidDiagram(code: mermaidCode.trim()),
        ),
      ));
      
      lastEnd = match.end;
    }
    
    if (lastEnd < text.length) {
      widgets.add(MarkdownBody(
        data: text.substring(lastEnd),
        extensionSet: md.ExtensionSet.gitHubFlavored,
        builders: {
          'table': CustomTableBuilder(),
          'blockquote': CustomBlockquoteBuilder(),
        },
        styleSheet: style,
      ));
    }
    
    return widgets;
  }

  Widget _buildAssistantMessage(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32), // More space between turns
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF5A877E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!msg.isStreaming || msg.text.isNotEmpty)
                  ..._parseMessageWithMermaid(msg.text, msg.isStreaming),
                if (msg.isStreaming && msg.text.isEmpty)
                  _buildLoadingWidget(),
                if (msg.metrics != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "TTFT: ${(msg.metrics!['ttft'] as double).toStringAsFixed(0)}ms  •  ${(msg.metrics!['tps'] as double).toStringAsFixed(1)} tokens/sec",
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.w700, 
                        color: Colors.grey.shade400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
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

  Widget _buildAttachmentStrip() {
    if (_selectedImages.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: MemoryImage(_selectedImages[index].displayBytes),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          _buildAttachmentStrip(),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _showAttachmentOptions,
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF006D5B), size: 28),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: "Message CareNest...",
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleSend(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 4, right: 4),
                      decoration: const BoxDecoration(color: Color(0xFF006D5B), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(Icons.camera_alt, "Camera", () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.camera);
                }),
                _buildAttachmentOption(Icons.photo_library, "Gallery", () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.gallery);
                }),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF006D5B), size: 30),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
