import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'enhanced_video_player.dart';
import 'webview_page.dart'; // ✅ WebViewPage import kiya
import '../services/api_service.dart';

class ContentOptionsPage extends StatefulWidget {
  final Map<String, dynamic> chapter;
  final String subject;
  final int grade;
  final String medium;
  final String? courseId;
  final List<dynamic>? allChapters;

  const ContentOptionsPage({
    Key? key,
    required this.chapter,
    required this.subject,
    required this.grade,
    required this.medium,
    this.courseId,
    this.allChapters,
  }) : super(key: key);

  @override
  State<ContentOptionsPage> createState() => _ContentOptionsPageState();
}

class _ContentOptionsPageState extends State<ContentOptionsPage>
    with TickerProviderStateMixin {

  // ── State ────────────────────────────────────────────────────
  int     _focusedButtonIndex = 0;
  String? _activeTab;
  String? _videoUrl;
  bool    _videoLoading  = false;
  bool    _videoError    = false;   // ✅ NEW: video error state
  String  _videoErrorMsg = '';      // ✅ NEW: error message for overlay
  int     _retryCount    = 0;       // ✅ NEW: retry counter

  // ✅ Book ke liye state — WebView ke andar dikhane ke liye
  String? _bookUrl;
  bool    _bookLoading   = false;

  bool    _autoOpenDone  = false;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoOpenDone) {
      _autoOpenDone = true;
      // ✅ Auto-open: Book ho to book load karo, warna Video
      if (_hasBook) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadBook());
      } else if (_hasVideo) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadVideo());
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────
  bool get _hasBook =>
      widget.chapter['topic_docs'] != null &&
      widget.chapter['topic_docs'].toString().trim().isNotEmpty;

  bool get _hasVideo =>
      widget.chapter['video_links'] != null &&
      widget.chapter['video_links'].toString().trim().isNotEmpty;

  String get _chapterName {
    // Library book ke liye book_name use karo
    if (widget.subject == 'Library') {
      return widget.chapter['book_name']?.toString()
          ?? widget.chapter['sub_topic']?.toString()
          ?? 'Book';
    }
    return widget.chapter['sub_topic']?.toString()
        ?? widget.chapter['chapter']?.toString()
        ?? widget.chapter['subtopic_name']?.toString()
        ?? widget.chapter['chapter_name']?.toString()
        ?? 'Chapter';
  }

  String _getChapterNumber() {
    final all = widget.allChapters ?? [];
    if (all.isEmpty) return '01';
    final id  = widget.chapter['id']?.toString() ?? '';
    final idx = all.indexWhere((c) => (c as Map)['id']?.toString() == id);
    return (idx >= 0 ? idx + 1 : 1).toString().padLeft(2, '0');
  }

  // Library se aaya hai ya normal chapter — check karo
  bool get _isLibraryBook => widget.subject == 'Library';

  // ── ✅ Book: PDF/URL ko WebView mein open karo ──────────────
  String _buildViewerUrl(String rawUrl) {
    final lower = rawUrl.toLowerCase();

    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return rawUrl;
    }

    if (lower.endsWith('.pdf') || lower.contains('.pdf')) {
      final encoded = Uri.encodeComponent(rawUrl);
      return 'https://mozilla.github.io/pdf.js/web/viewer.html?file=$encoded';
    }

    return rawUrl;
  }

  Future<void> _loadBook() async {
    final rawUrl = widget.chapter['topic_docs']?.toString() ?? '';
    if (rawUrl.trim().isEmpty) {
      _showComingSoonDialog('Book not available for this chapter.');
      return;
    }

    setState(() {
      _activeTab          = 'book';
      _bookUrl            = null;
      _bookLoading        = true;
      _focusedButtonIndex = 1;
    });

    try {
      final viewerUrl = _buildViewerUrl(rawUrl);
      Uri.parse(viewerUrl); // validate
      setState(() {
        _bookUrl     = viewerUrl;
        _bookLoading = false;
      });
    } catch (e) {
      setState(() => _bookLoading = false);
      _showErrorDialog('Book open nahi hua: $e');
    }
  }

  // ── ✅ Video: fetch URL with retry logic ─────────────────────
  Future<void> _loadVideo({bool isRetry = false}) async {
    setState(() {
      _videoLoading  = true;
      _videoError    = false;
      _videoErrorMsg = '';
      if (!isRetry) {
        _videoUrl   = null;
        _retryCount = 0;
      }
      _activeTab             = 'video';
      _focusedButtonIndex    = 0;
    });

    // ✅ 3 baar retry karein auto
    const maxRetries = 3;
    String? url;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        String? fresh;
        if (widget.courseId != null && widget.chapter['id'] != null) {
          fresh = await ApiService.refreshVideoLinkByTopicId(
            widget.courseId!, widget.chapter['id'].toString());
        }
        url = fresh ?? widget.chapter['video_links']?.toString() ?? '';

        if (url.isNotEmpty) {
          if (mounted) {
            setState(() {
              _videoUrl     = url;
              _videoLoading = false;
              _videoError   = false;
              _retryCount   = attempt;
            });
          }
          return; // ✅ Success — bahar nikal jao
        }
      } catch (e) {
        // Last attempt fail hua
        if (attempt == maxRetries) {
          if (mounted) {
            setState(() {
              _videoLoading  = false;
              _videoError    = true;
              // ✅ Error sirf content area mein dikhao — neeche nahi
              _videoErrorMsg = 'Network issue. Video load nahi hua.\nRetry button dabao.';
            });
          }
          return;
        }
        // ✅ Retry se pehle thoda wait karo (exponential backoff)
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    // URL empty tha
    if (mounted) {
      setState(() {
        _videoLoading  = false;
        _videoError    = true;
        _videoErrorMsg = 'Is chapter ke liye video available nahi hai.';
      });
    }
  }

  // ── Keyboard nav ─────────────────────────────────────────────
  bool _contentAreaFocused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ── Back / Escape ─────────────────────────────────────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_contentAreaFocused) {
        setState(() => _contentAreaFocused = false);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    // ── Arrow UP ──────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_contentAreaFocused) {
        final maxBtn = _isLibraryBook ? 1 : 2;
        final minBtn = _isLibraryBook ? 1 : 0;
        setState(() => _focusedButtonIndex =
            (_focusedButtonIndex - 1).clamp(minBtn, maxBtn));
      }
      return KeyEventResult.handled;
    }

    // ── Arrow DOWN ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_contentAreaFocused) {
        final maxBtn = _isLibraryBook ? 1 : 2;
        final minBtn = _isLibraryBook ? 1 : 0;
        setState(() => _focusedButtonIndex =
            (_focusedButtonIndex + 1).clamp(minBtn, maxBtn));
      }
      return KeyEventResult.handled;
    }

    // ── Arrow RIGHT → content area pe focus ───────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!_contentAreaFocused && _activeTab != null) {
        setState(() => _contentAreaFocused = true);
      }
      return KeyEventResult.handled;
    }

    // ── Arrow LEFT → sidebar pe wapas ─────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_contentAreaFocused) {
        setState(() => _contentAreaFocused = false);
      }
      return KeyEventResult.handled;
    }

    // ── OK / Enter / Select ───────────────────────────────────
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!_contentAreaFocused) {
        _activateButton(_focusedButtonIndex);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _activateButton(int idx) {
    setState(() => _focusedButtonIndex = idx);
    if (idx == 0) {
      if (_hasVideo) _loadVideo();
      else _showComingSoonDialog('Video not available for this chapter.');
    } else if (idx == 1) {
      if (_hasBook) _loadBook();
      else _showComingSoonDialog('Book not available for this chapter.');
    } else {
      setState(() { _activeTab = 'qa'; });
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 600 ? 180.0 : 240.0;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── LEFT SIDEBAR ──────────────────────────────
                _buildSidebar(sidebarWidth, screenWidth),
                // ── RIGHT CONTENT AREA ────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      Expanded(child: _buildContentScreen()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────
  Widget _buildSidebar(double sidebarWidth, double screenWidth) {
    return Stack(
      children: [
        Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Logo box ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBF360C), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school,
                        color: Color(0xFF1A3A7C),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'EASY LEARN',
                      style: TextStyle(
                        color: Color(0xFFBF360C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'EDUCATION FOR ALL',
                      style: TextStyle(
                        color: Color(0xFF6B8AB5),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Nav Buttons ────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  _isLibraryBook ? 1 : 3,
                  (idx) {
                  final realIdx   = _isLibraryBook ? 1 : idx;
                  final labels    = ['Video', 'Books', 'Q & A'];
                  final tabMap    = {0: 'video', 1: 'book', 2: 'qa'};
                  final isActive  = _activeTab == tabMap[realIdx];
                  final isFocused = _focusedButtonIndex == realIdx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GestureDetector(
                      onTap: () => _activateButton(realIdx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFBF360C)
                              : isFocused
                                  ? const Color(0xFF3A1200)
                                  : const Color(0xFF2A0800),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFBF360C)
                                : isFocused
                                    ? Colors.white54
                                    : const Color(0xFF3A1200),
                            width: 2,
                          ),
                          boxShadow: isActive
                              ? [BoxShadow(
                                  color: const Color(0xFFBF360C).withOpacity(0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Text(
                          labels[realIdx],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFFFFF8F5),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
      ),

        // ── Right side white border line ─────────────────────────
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xFFBF360C),
                  Color(0xFFE64A19),
                  Color(0xFFBF360C),
                  Colors.transparent,
                ],
                stops: [0.0, 0.15, 0.5, 0.85, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF6D00)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(
        '${_getChapterNumber()}  $_chapterName',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Right content screen ──────────────────────────────────────
  Widget _buildContentScreen() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A1200), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildScreenContent(),
      ),
    );
  }

  Widget _buildScreenContent() {

    // ── Video tab ──────────────────────────────────────────────
    if (_activeTab == 'video') {
      // ✅ Loading spinner with message
      if (_videoLoading) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFBF360C)),
              const SizedBox(height: 16),
              Text(
                _retryCount > 0
                    ? 'try to load... ($_retryCount/3)'
                    : 'Video loading...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      // ✅ Error state — sirf content area ke andar dikhao, neeche nahi
      if (_videoError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFF6B6B),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _videoErrorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // ✅ Retry button
              GestureDetector(
                onTap: () => _loadVideo(isRetry: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF360C),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBF360C).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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

      if (_videoUrl != null && _videoUrl!.isNotEmpty) {
        return WebViewPage(
          url: _videoUrl!,
          title: 'Video — $_chapterName',
        );
      }
      return _infoScreen(
        Icons.play_circle_outline,
        'Tap Video to load',
        subtitle: 'Press the Video button on the left',
      );
    }

    // ── Book tab ───────────────────────────────────────────────
    if (_activeTab == 'book') {
      if (_bookLoading) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBF360C)));
      }
      if (_bookUrl != null && _bookUrl!.isNotEmpty) {
        return WebViewPage(
          url: _bookUrl!,
          title: 'Book — $_chapterName',
        );
      }
      return _infoScreen(
        Icons.menu_book_rounded,
        'Book load failed',
        subtitle: 'please click book button',
        iconColor: const Color(0xFFBF360C),
        textColor: const Color(0xFFBF360C),
      );
    }

    // ── Q&A tab ────────────────────────────────────────────────
    if (_activeTab == 'qa') {
      return _infoScreen(
        Icons.construction_rounded,
        'Q & A Coming Soon!',
        subtitle: 'comming soon',
        iconColor: const Color(0xFF059669),
        textColor: const Color(0xFF059669),
      );
    }

    // ── Kuch select nahi kiya ──────────────────────────────────
    return _infoScreen(
      Icons.touch_app_rounded,
      'Select content from the left',
      subtitle: 'Choose Video, Books, or Q&A',
    );
  }

  Widget _infoScreen(
    IconData icon,
    String title, {
    String? subtitle,
    Color iconColor = const Color(0xFF5C3020),
    Color textColor = const Color(0xFF5C3020),
  }) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: iconColor, size: 56),
        const SizedBox(height: 16),
        Text(title,
            style: TextStyle(
                color: textColor, fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
              textAlign: TextAlign.center),
        ],
      ]),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────
  void _showComingSoonDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0C00),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF059669).withOpacity(0.4), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction_rounded,
                color: Color(0xFF059669), size: 40),
            const SizedBox(height: 16),
            const Text('Coming Soon!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF8B949E)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Got It!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF0B0E13))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ✅ _showErrorDialog hataya — ab errors content area mein dikhte hain
  // Agar kisi jagah zaroorat pade to ye backup rakhte hain
  void _showErrorDialog(String message) {
    if (mounted) {
      setState(() {
        _videoLoading  = false;
        _videoError    = true;
        _videoErrorMsg = message;
        _activeTab     = 'video';
      });
    }
  }
}