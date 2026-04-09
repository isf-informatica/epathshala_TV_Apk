import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'exam_list_page.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'lecture_schedule_page.dart';
import 'library_page.dart';
import 'tools_page.dart';

// Conditional import: web-only shim vs mobile stub
import 'web_shim_stub.dart'
  if (dart.library.html) 'web_shim_web.dart'
  as webShim;

import 'whiteboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BoardsPage — Left sidebar + boards grid
// ─────────────────────────────────────────────────────────────────────────────

class BoardsPage extends StatefulWidget {
  final Map<String, dynamic> loginData;
  const BoardsPage({Key? key, required this.loginData}) : super(key: key);

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  int _focusedIndex = 0;
  bool _sidebarFocused = false;
  int _sidebarNavIndex = 0;

  static const List<_BoardItem> _boards = [
    _BoardItem(title: 'Basic Whiteboard',    icon: Icons.crop_square_rounded,    gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.miro),
    _BoardItem(title: 'Advanced Whiteboard', icon: Icons.desktop_windows_rounded, gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.advanced),
    _BoardItem(title: 'Mindmap',             icon: Icons.account_tree_rounded,    gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.mindmap),
    _BoardItem(title: 'UML & Flowchart',     icon: Icons.mediation_rounded,       gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.uml),
    _BoardItem(title: 'Mathematics',         icon: Icons.calculate_rounded,       gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.mathematics),
    _BoardItem(title: 'Math Formula',        icon: Icons.functions_rounded,       gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.mathFormula),
    _BoardItem(title: 'Physics',             icon: Icons.bolt_rounded,            gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.physics),
    _BoardItem(title: 'Chemistry',           icon: Icons.science_rounded,         gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)], type: BoardType.chemistry),
  ];

  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards', 'Tools', 'Logout',
  ];

  int get _cols {
    try {
      final w = MediaQuery.of(context).size.width;
      final sw = w < 600 ? 180.0 : 240.0;
      return (w - sw) >= 700 ? 4 : 3;
    } catch (_) { return 4; }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final total = _boards.length;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!_sidebarFocused) {
        _openBoard(_boards[_focusedIndex]);
      } else {
        _executeSidebarItem(_navItems[_sidebarNavIndex]);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (!_sidebarFocused) {
        setState(() { _sidebarFocused = true; });
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_sidebarFocused) {
        if (_focusedIndex % _cols == 0) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedIndex = (_focusedIndex - 1).clamp(0, total - 1));
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
      } else {
        setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, total - 1));
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex > 0) setState(() => _sidebarNavIndex--);
      } else {
        if (_focusedIndex < _cols) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedIndex = (_focusedIndex - _cols).clamp(0, total - 1));
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex < _navItems.length - 1) setState(() => _sidebarNavIndex++);
      } else {
        setState(() => _focusedIndex = (_focusedIndex + _cols).clamp(0, total - 1));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _executeSidebarItem(String label) {
    switch (label) {
      case 'Boards':
        setState(() => _sidebarFocused = false);
        break;
      case 'Courses':
        Navigator.maybePop(context);
        break;
      case 'Exams':
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => ExamListPage(loginData: widget.loginData),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ));
        break;
      case 'Video Conference':
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => LectureSchedulePage(loginData: widget.loginData),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ));
        break;
      case 'Library':
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => LibraryPage(
          regId: (widget.loginData['reg_id'] ?? '').toString(),
          permissions: (widget.loginData['permissions'] ?? 'School').toString(),
        ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ));
        break;
      case 'Tools':
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => ToolsPage(loginData: widget.loginData),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ));
        break;
      case 'Logout':
        _showLogoutDialog();
        break;
      default:
        Navigator.maybePop(context);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1C45),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Color(0xFFFFA600))),
          ),
        ],
      ),
    );
  }

  void _openBoard(_BoardItem board) {
    if (board.type == BoardType.comingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${board.title} — Coming Soon'),
        backgroundColor: const Color(0xFF1A2E55),
        duration: const Duration(milliseconds: 2000),
      ));
      return;
    }

    Widget page;
    if (board.type == BoardType.advanced) {
      page = const WhiteboardPage();
    } else if (board.type == BoardType.mindmap) {
      page = const MindmapPage();
    } else if (board.type == BoardType.uml) {
      page = UmlBoardPage();
    } else if (board.type == BoardType.mathematics) {
      page = const MathsToolPage(); // ✅ GeoGebra directly
    } else if (board.type == BoardType.mathFormula) {
      page = const MathFormulaPage(); // ✅ iMathEQ equation editor
    } else if (board.type == BoardType.physics) {
      page = const PhysicsToolPage(); // ✅ GeoGebra Physics (Basic, Evaluator, Notes)
    } else if (board.type == BoardType.chemistry) {
      page = const ChemistryToolPage(); // ✅ GeoGebra Chemistry (Basic, Graphing, Scientific, Notes)
    } else {
      page = const MiroBoardPage();
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildSidebar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 600 ? 180.0 : 240.0;

    return Stack(
      children: [
        Container(
          width: sidebarWidth,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0800), Color(0xFF3A1200)],
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(3, 0))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth < 600 ? 8 : 14,
                  screenWidth < 600 ? 8 : 14,
                  screenWidth < 600 ? 8 : 14,
                  10,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: screenWidth < 600 ? 6 : 10,
                      horizontal: screenWidth < 600 ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBF360C), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo_easylearn.png',
                          height: screenWidth < 600 ? 36 : 50,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school,
                            color: const Color(0xFFBF360C),
                            size: screenWidth < 600 ? 30 : 42,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('EASY LEARN',
                            style: TextStyle(
                              color: const Color(0xFFBF360C),
                              fontSize: screenWidth < 600 ? 9 : 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            )),
                        Text('EDUCATION FOR ALL',
                            style: TextStyle(
                              color: const Color(0xFF8B3A2A),
                              fontSize: screenWidth < 600 ? 6 : 7.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _navItems.asMap().entries.map((entry) {
                      final navIdx   = entry.key;
                      final label    = entry.value;
                      final isActive  = label == 'Boards';
                      final isTvFocus = _sidebarFocused && navIdx == _sidebarNavIndex;

                      return GestureDetector(
                        onTap: () => _executeSidebarItem(label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth < 600 ? 10 : 20,
                            vertical: isTvFocus ? 6 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isTvFocus ? Colors.white.withOpacity(0.10) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isTvFocus ? Colors.white38 : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isTvFocus ? 12 : 10,
                                height: isTvFocus ? 12 : 10,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFBF360C) : Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: screenWidth < 600 ? 6 : 12),
                              Expanded(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFFBF360C) : Colors.white,
                                    fontSize: screenWidth < 600
                                        ? (isTvFocus ? 14 : 13)
                                        : (isTvFocus ? 20 : 19),
                                    fontWeight: (isActive || isTvFocus) ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

          // ── Powered By Logo ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Powered by',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Image.asset(
                  'assets/images/powered_by_logo.png',
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'EasyLearn',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: Container(
            width: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFBF360C), Colors.transparent],
                stops: [0.0, 0.15, 0.5, 0.85, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF6D00)],
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BOARDS & TOOLS',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Let's Get Started!",
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('Select your Board',
                  style: TextStyle(color: Color(0xFFFFA600), fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(_BoardItem board, int index) {
    final isFocused = !_sidebarFocused && index == _focusedIndex;

    return GestureDetector(
      onTap: () {
        setState(() { _sidebarFocused = false; _focusedIndex = index; });
        _openBoard(board);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused ? const Color(0xFFBF360C) : const Color(0xFFE8D5CC),
            width: isFocused ? 4 : 2,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.4), blurRadius: 18, spreadRadius: 2)]
              : [const BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFFFF8F5),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  board.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                    fontSize: 18,
                    fontWeight: isFocused ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double sidebarWidth = screenSize.width < 600 ? 180.0 : 240.0;
    final double gridWidth = screenSize.width - sidebarWidth;
    final int cols = gridWidth >= 700 ? 4 : 3;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 416 / 262,
                        ),
                        itemCount: _boards.length,
                        itemBuilder: (context, index) =>
                            _buildBoardCard(_boards[index], index),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MiroBoardPage
// ─────────────────────────────────────────────────────────────────────────────

class MiroBoardPage extends StatefulWidget {
  const MiroBoardPage({Key? key}) : super(key: key);

  @override
  State<MiroBoardPage> createState() => _MiroBoardPageState();
}

class _MiroBoardPageState extends State<MiroBoardPage> {
  static const String _miroUrl =
      'https://miro.com/app/live-embed/uXjVNAXRL8I=/?moveToViewport=-1143,-757,2706,1284&embedId=93744866188';
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      webShim.registerIframeFactory('miro-iframe', _miroUrl);
      setState(() => _isLoading = false);
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ))
        ..loadRequest(Uri.parse(_miroUrl));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar('Whiteboard', 'Miro Board', Icons.crop_square_rounded),
              Expanded(
                child: Stack(children: [
                  kIsWeb
                      ? const HtmlElementView(viewType: 'miro-iframe')
                      : WebViewWidget(controller: _controller!),
                  if (_isLoading) _loadingWidget('Loading Miro Board...', Icons.crop_square_rounded),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(String title, String badge, IconData badgeIcon) {
    return Container(
      height: 70, color: const Color(0xFF0D1C45),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        _backBtn(context),
        const Spacer(),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const Spacer(),
        _badgeChip(badge, badgeIcon),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MindmapPage
// ─────────────────────────────────────────────────────────────────────────────

class MindmapPage extends StatefulWidget {
  const MindmapPage({Key? key}) : super(key: key);

  @override
  State<MindmapPage> createState() => _MindmapPageState();
}

class _MindmapPageState extends State<MindmapPage> {
  static const String _mindmapPageUrl = 'https://k12.easylearn.org.in/Easylearn/mindmap_generator';
  static bool _iframeRegistered = false;
  bool _isLoading = true;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (!_iframeRegistered) {
        webShim.registerIframeFactory('mindmap-iframe', _mindmapPageUrl);
        _iframeRegistered = true;
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0D1C45))
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
          onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ))
        ..loadRequest(Uri.parse(_mindmapPageUrl));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 70, color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _backBtn(context),
                  const Spacer(),
                  const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('AI Mindmap Generator', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Generate intelligent mindmaps', style: TextStyle(color: Color(0xFFFFA600), fontSize: 10)),
                  ]),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isLoading = true);
                      _controller?.reload();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A2E55), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2A4070), width: 1)),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: Stack(children: [
                  kIsWeb
                      ? const HtmlElementView(viewType: 'mindmap-iframe')
                      : WebViewWidget(controller: _controller!),
                  if (_isLoading) _loadingWidget('Loading AI Mindmap Generator...', Icons.account_tree_rounded),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _controller = null; super.dispose(); }
}

// ─────────────────────────────────────────────────────────────────────────────
// UmlBoardPage
// ─────────────────────────────────────────────────────────────────────────────

class UmlBoardPage extends StatefulWidget {
  const UmlBoardPage({Key? key}) : super(key: key);

  @override
  State<UmlBoardPage> createState() => _UmlBoardPageState();
}

class _UmlBoardPageState extends State<UmlBoardPage> {
  static const String _umlUrl = 'https://k12.easylearn.org.in/uml_diagram_generator';
  static bool _iframeRegistered = false;
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (!_iframeRegistered) {
        webShim.registerIframeFactory('uml-iframe', _umlUrl);
        _iframeRegistered = true;
      }
      setState(() => _isLoading = false);
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ))
        ..loadRequest(Uri.parse(_umlUrl));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 70, color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  _backBtn(context),
                  const Spacer(),
                  const Text('UML & Flowchart', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  _badgeChip('AI UML Generator', Icons.mediation_rounded),
                ]),
              ),
              Expanded(
                child: Stack(children: [
                  kIsWeb ? const HtmlElementView(viewType: 'uml-iframe') : WebViewWidget(controller: _controller!),
                  if (_isLoading) _loadingWidget('Loading UML Generator...', Icons.mediation_rounded),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _controller = null; super.dispose(); }
}

// ═════════════════════════════════════════════════════════════════════════════
// ✅ MathsToolPage
//    GeoGebra deployggb.js ko DIRECTLY call karta hai
//    Koi PHP page nahi — HTML string WebView/iframe mein inject hota hai
//    Tab switch karne par naya appName load hota hai
// ═════════════════════════════════════════════════════════════════════════════

class MathsToolPage extends StatefulWidget {
  const MathsToolPage({Key? key}) : super(key: key);

  @override
  State<MathsToolPage> createState() => _MathsToolPageState();
}

class _MathsToolPageState extends State<MathsToolPage> {
  // ── 7 GeoGebra tools — appName PHP se same hai ──
  static const List<_MathTab> _tabs = [
    _MathTab(label: 'Basic',      icon: Icons.calculate_rounded,     appName: 'classic'),
    _MathTab(label: 'Geometry',   icon: Icons.hexagon_rounded,       appName: 'geometry'),
    _MathTab(label: 'Graphing',   icon: Icons.show_chart_rounded,    appName: 'graphing'),
    _MathTab(label: '3D',         icon: Icons.view_in_ar_rounded,    appName: '3d'),
    _MathTab(label: 'Evaluator',  icon: Icons.functions_rounded,     appName: 'evaluator'),
    _MathTab(label: 'Scientific', icon: Icons.science_rounded,       appName: 'scientific'),
    _MathTab(label: 'Notes',      icon: Icons.sticky_note_2_rounded, appName: 'notes'),
  ];

  int _selectedTab = 0;
  bool _isLoading = true;
  WebViewController? _controller;

  // Web iframe guard
  static bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebIframe();
    } else {
      _loadMobileTab(0);
    }
  }

  // ── Web: srcdoc se HTML inject karo ────────────────────────────────────
  void _registerWebIframe() {
    if (!_iframeRegistered) {
      webShim.registerIframeFactory(
        'mathstool-ggb-iframe',
        '',
        iframeId: 'ggb-main-iframe',
        useSrcdoc: true,
        srcdocContent: _buildGeoGebraHtml(_tabs[0].appName),
      );
      _iframeRegistered = true;
    }
    setState(() => _isLoading = false);
  }

  // ── Mobile/TV: WebViewController mein HTML string load karo ────────────
  void _loadMobileTab(int index) {
    if (_controller == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
          onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ));
    }
    _controller!.loadHtmlString(
      _buildGeoGebraHtml(_tabs[index].appName),
      // baseUrl GeoGebra CDN ke liye zaroori — JS fetch karne ke liye
      baseUrl: 'https://www.geogebra.org',
    );
  }

  // ── Tab switch ──────────────────────────────────────────────────────────
  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _isLoading = true;
    });

    if (kIsWeb) {
      webShim.updateIframeSrcdoc('ggb-main-iframe', _buildGeoGebraHtml(_tabs[index].appName));
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } else {
      _loadMobileTab(index);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // ✅ YAHI HAI CORE FUNCTION
  //    deployggb.js ko directly CDN se call karta hai
  //    PHP ki zarurat bilkul nahi
  // ════════════════════════════════════════════════════════════════════════
  String _buildGeoGebraHtml(String appName) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>GeoGebra $appName</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: #fff; }
    #ggb-container { width: 100%; height: 100%; }

    /* Flutter-style loading overlay */
    #ggb-overlay {
      position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: #0D1C45;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      z-index: 9999;
      transition: opacity 0.4s ease;
    }
    #ggb-overlay.done { opacity: 0; pointer-events: none; }

    .spinner {
      width: 48px; height: 48px;
      border: 4px solid #1A2E55;
      border-top-color: #FFA600;
      border-radius: 50%;
      animation: spin 0.75s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    .ov-title { color: #fff; font-family: Arial, sans-serif; font-size: 15px; font-weight: 700; margin-top: 16px; }
    .ov-sub   { color: #8B949E; font-family: Arial, sans-serif; font-size: 11px; margin-top: 5px; }
  </style>
</head>
<body>

  <div id="ggb-container"></div>

  <div id="ggb-overlay">
    <div class="spinner"></div>
    <div class="ov-title">GeoGebra load ho raha hai...</div>
    <div class="ov-sub">$appName &nbsp;•&nbsp; deployggb.js</div>
  </div>

  <!-- ✅ Yahi woh line hai — directly CDN se deployggb.js call -->
  <script src="https://www.geogebra.org/apps/deployggb.js"></script>

  <script>
    function hideOverlay() {
      var el = document.getElementById('ggb-overlay');
      if (el) el.classList.add('done');
    }

    var W = window.innerWidth  || 800;
    var H = window.innerHeight || 600;

    var params = {
      "appName"            : "$appName",
      "width"              : W,
      "height"             : H,
      "showToolBar"        : true,
      "showAlgebraInput"   : true,
      "showMenuBar"        : true,
      "borderColor"        : null,
      "allowStyleBar"      : true,
      "enableUndoRedo"     : true,
      "enableFileFeatures" : true,
      "language"           : "en",
      "appletOnLoad"       : function(api) {
        // GeoGebra fully ready
        hideOverlay();
      }
    };

    var applet = new GGBApplet(params, true);

    window.addEventListener("load", function() {
      applet.inject('ggb-container');
      // Safety fallback — 10s baad bhi hide karo
      setTimeout(hideOverlay, 10000);
    });

    // Resize ke saath GeoGebra bhi resize ho
    window.addEventListener("resize", function() {
      var app = applet.getAppletObject ? applet.getAppletObject() : null;
      if (app && app.setSize) {
        app.setSize(window.innerWidth, window.innerHeight);
      }
    });
  </script>

</body>
</html>''';
  }

  // ── TV remote back ────────────────────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                height: 70,
                color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _backBtn(context),
                    const Spacer(),
                    const Text('Mathematics Tools',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    _badgeChip('Powered by GeoGebra', Icons.calculate_rounded),
                  ],
                ),
              ),

              // ── Clickable tab bar ────────────────────────────────
              Container(
                height: 50,
                color: const Color(0xFF0A1530),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final i   = e.key;
                      final tab = e.value;
                      final sel = i == _selectedTab;
                      return GestureDetector(
                        onTap: () => _switchTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFFA600) : const Color(0xFF1A2E55).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? const Color(0xFFFFA600) : const Color(0xFF2A4070).withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: sel
                                ? [BoxShadow(color: const Color(0xFFFFA600).withOpacity(0.4), blurRadius: 8)]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon,
                                  color: sel ? const Color(0xFF0D1C45) : Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(tab.label,
                                  style: TextStyle(
                                    color: sel ? const Color(0xFF0D1C45) : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── GeoGebra area ────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    kIsWeb
                        ? const HtmlElementView(viewType: 'mathstool-ggb-iframe')
                        : WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      _loadingWidget(
                        'GeoGebra ${_tabs[_selectedTab].label} load ho raha hai...',
                        _tabs[_selectedTab].icon,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChemistryToolPage — GeoGebra Chemistry Tools (Basic, Graphing, Scientific, Notes)
// ─────────────────────────────────────────────────────────────────────────────

class ChemistryToolPage extends StatefulWidget {
  const ChemistryToolPage({Key? key}) : super(key: key);

  @override
  State<ChemistryToolPage> createState() => _ChemistryToolPageState();
}

class _ChemistryToolPageState extends State<ChemistryToolPage> {
  // ── 4 tabs — matching Chemistry Tools screenshot ──
  static const List<_MathTab> _tabs = [
    _MathTab(label: 'Basic',      icon: Icons.calculate_rounded,     appName: 'classic'),
    _MathTab(label: 'Graphing',   icon: Icons.show_chart_rounded,    appName: 'graphing'),
    _MathTab(label: 'Scientific', icon: Icons.biotech_rounded,       appName: 'scientific'),
    _MathTab(label: 'Notes',      icon: Icons.sticky_note_2_rounded, appName: 'notes'),
  ];

  int _selectedTab = 0;
  bool _isLoading = true;
  WebViewController? _controller;

  static bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebIframe();
    } else {
      _loadMobileTab(0);
    }
  }

  void _registerWebIframe() {
    if (!_iframeRegistered) {
      webShim.registerIframeFactory(
        'chemistrytool-ggb-iframe',
        '',
        iframeId: 'chemistry-ggb-iframe',
        useSrcdoc: true,
        srcdocContent: _buildGeoGebraHtml(_tabs[0].appName),
      );
      _iframeRegistered = true;
    }
    setState(() => _isLoading = false);
  }

  void _loadMobileTab(int index) {
    if (_controller == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
          onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ));
    }
    _controller!.loadHtmlString(
      _buildGeoGebraHtml(_tabs[index].appName),
      baseUrl: 'https://www.geogebra.org',
    );
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _isLoading = true;
    });

    if (kIsWeb) {
      webShim.updateIframeSrcdoc('chemistry-ggb-iframe', _buildGeoGebraHtml(_tabs[index].appName));
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } else {
      _loadMobileTab(index);
    }
  }

  String _buildGeoGebraHtml(String appName) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Chemistry $appName</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: #fff; }
    #ggb-container { width: 100%; height: 100%; }
    #ggb-overlay {
      position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: #0D1C45;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      z-index: 9999; transition: opacity 0.4s ease;
    }
    #ggb-overlay.done { opacity: 0; pointer-events: none; }
    .spinner {
      width: 48px; height: 48px;
      border: 4px solid #1A2E55; border-top-color: #FFA600;
      border-radius: 50%; animation: spin 0.75s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .ov-title { color: #fff; font-family: Arial, sans-serif; font-size: 15px; font-weight: 700; margin-top: 16px; }
    .ov-sub   { color: #8B949E; font-family: Arial, sans-serif; font-size: 11px; margin-top: 5px; }
  </style>
</head>
<body>
  <div id="ggb-container"></div>
  <div id="ggb-overlay">
    <div class="spinner"></div>
    <div class="ov-title">GeoGebra load ho raha hai...</div>
    <div class="ov-sub">$appName &nbsp;•&nbsp; Chemistry Tools</div>
  </div>
  <script src="https://www.geogebra.org/apps/deployggb.js"></script>
  <script>
    function hideOverlay() {
      var el = document.getElementById('ggb-overlay');
      if (el) el.classList.add('done');
    }
    var W = window.innerWidth  || 800;
    var H = window.innerHeight || 600;
    var params = {
      "appName"            : "$appName",
      "width"              : W,
      "height"             : H,
      "showToolBar"        : true,
      "showAlgebraInput"   : true,
      "showMenuBar"        : true,
      "borderColor"        : null,
      "allowStyleBar"      : true,
      "enableUndoRedo"     : true,
      "enableFileFeatures" : true,
      "language"           : "en",
      "appletOnLoad"       : function(api) { hideOverlay(); }
    };
    var applet = new GGBApplet(params, true);
    window.addEventListener("load", function() {
      applet.inject('ggb-container');
      setTimeout(hideOverlay, 10000);
    });
    window.addEventListener("resize", function() {
      var app = applet.getAppletObject ? applet.getAppletObject() : null;
      if (app && app.setSize) app.setSize(window.innerWidth, window.innerHeight);
    });
  </script>
</body>
</html>''';
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                height: 70,
                color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _backBtn(context),
                    const Spacer(),
                    const Text(
                      'Chemistry Tools',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _badgeChip('Powered by GeoGebra', Icons.science_rounded),
                  ],
                ),
              ),

              // ── Clickable Tab Bar ─────────────────────────────────────────
              Container(
                height: 50,
                color: const Color(0xFF0A1530),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final i   = e.key;
                      final tab = e.value;
                      final sel = i == _selectedTab;
                      return GestureDetector(
                        onTap: () => _switchTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFFA600) : const Color(0xFF1A2E55).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? const Color(0xFFFFA600) : const Color(0xFF2A4070).withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: sel
                                ? [BoxShadow(color: const Color(0xFFFFA600).withOpacity(0.4), blurRadius: 8)]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon,
                                  color: sel ? const Color(0xFF0D1C45) : Colors.white70,
                                  size: 14),
                              const SizedBox(width: 6),
                              Text(tab.label,
                                  style: TextStyle(
                                    color: sel ? const Color(0xFF0D1C45) : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── GeoGebra Area ─────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    kIsWeb
                        ? const HtmlElementView(viewType: 'chemistrytool-ggb-iframe')
                        : WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      _loadingWidget(
                        'GeoGebra ${_tabs[_selectedTab].label} load ho raha hai...',
                        _tabs[_selectedTab].icon,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhysicsToolPage — GeoGebra Physics Tools (Basic, Evaluator, Notes)
// Physicstool.php ki tarah same 3 tabs: classic, evaluator, notes
// ─────────────────────────────────────────────────────────────────────────────

class PhysicsToolPage extends StatefulWidget {
  const PhysicsToolPage({Key? key}) : super(key: key);

  @override
  State<PhysicsToolPage> createState() => _PhysicsToolPageState();
}

class _PhysicsToolPageState extends State<PhysicsToolPage> {
  // ── 3 tabs — same as Physicstool.php ──
  static const List<_MathTab> _tabs = [
    _MathTab(label: 'Basic',     icon: Icons.calculate_rounded,  appName: 'classic'),
    _MathTab(label: 'Evaluator', icon: Icons.functions_rounded,  appName: 'evaluator'),
    _MathTab(label: 'Notes',     icon: Icons.sticky_note_2_rounded, appName: 'notes'),
  ];

  int _selectedTab = 0;
  bool _isLoading = true;
  WebViewController? _controller;

  static bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebIframe();
    } else {
      _loadMobileTab(0);
    }
  }

  void _registerWebIframe() {
    if (!_iframeRegistered) {
      webShim.registerIframeFactory(
        'physicstool-ggb-iframe',
        '',
        iframeId: 'physics-ggb-iframe',
        useSrcdoc: true,
        srcdocContent: _buildGeoGebraHtml(_tabs[0].appName),
      );
      _iframeRegistered = true;
    }
    setState(() => _isLoading = false);
  }

  void _loadMobileTab(int index) {
    if (_controller == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
          onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ));
    }
    _controller!.loadHtmlString(
      _buildGeoGebraHtml(_tabs[index].appName),
      baseUrl: 'https://www.geogebra.org',
    );
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _isLoading = true;
    });

    if (kIsWeb) {
      webShim.updateIframeSrcdoc('physics-ggb-iframe', _buildGeoGebraHtml(_tabs[index].appName));
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } else {
      _loadMobileTab(index);
    }
  }

  String _buildGeoGebraHtml(String appName) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Physics $appName</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: #fff; }
    #ggb-container { width: 100%; height: 100%; }
    #ggb-overlay {
      position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: #0D1C45;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      z-index: 9999; transition: opacity 0.4s ease;
    }
    #ggb-overlay.done { opacity: 0; pointer-events: none; }
    .spinner {
      width: 48px; height: 48px;
      border: 4px solid #1A2E55; border-top-color: #FFA600;
      border-radius: 50%; animation: spin 0.75s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .ov-title { color: #fff; font-family: Arial, sans-serif; font-size: 15px; font-weight: 700; margin-top: 16px; }
    .ov-sub   { color: #8B949E; font-family: Arial, sans-serif; font-size: 11px; margin-top: 5px; }
  </style>
</head>
<body>
  <div id="ggb-container"></div>
  <div id="ggb-overlay">
    <div class="spinner"></div>
    <div class="ov-title">GeoGebra load ho raha hai...</div>
    <div class="ov-sub">$appName &nbsp;•&nbsp; Physics Tools</div>
  </div>
  <script src="https://www.geogebra.org/apps/deployggb.js"></script>
  <script>
    function hideOverlay() {
      var el = document.getElementById('ggb-overlay');
      if (el) el.classList.add('done');
    }
    var W = window.innerWidth  || 800;
    var H = window.innerHeight || 600;
    var params = {
      "appName"            : "$appName",
      "width"              : W,
      "height"             : H,
      "showToolBar"        : true,
      "showAlgebraInput"   : true,
      "showMenuBar"        : true,
      "borderColor"        : null,
      "allowStyleBar"      : true,
      "enableUndoRedo"     : true,
      "enableFileFeatures" : true,
      "language"           : "en",
      "appletOnLoad"       : function(api) { hideOverlay(); }
    };
    var applet = new GGBApplet(params, true);
    window.addEventListener("load", function() {
      applet.inject('ggb-container');
      setTimeout(hideOverlay, 10000);
    });
    window.addEventListener("resize", function() {
      var app = applet.getAppletObject ? applet.getAppletObject() : null;
      if (app && app.setSize) app.setSize(window.innerWidth, window.innerHeight);
    });
  </script>
</body>
</html>''';
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                height: 70,
                color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _backBtn(context),
                    const Spacer(),
                    const Text(
                      'Physics Tools',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _badgeChip('Powered by GeoGebra', Icons.bolt_rounded),
                  ],
                ),
              ),

              // ── Clickable Tab Bar ─────────────────────────────────────────
              Container(
                height: 50,
                color: const Color(0xFF0A1530),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final i   = e.key;
                      final tab = e.value;
                      final sel = i == _selectedTab;
                      return GestureDetector(
                        onTap: () => _switchTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFFA600) : const Color(0xFF1A2E55).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? const Color(0xFFFFA600) : const Color(0xFF2A4070).withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: sel
                                ? [BoxShadow(color: const Color(0xFFFFA600).withOpacity(0.4), blurRadius: 8)]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon,
                                  color: sel ? const Color(0xFF0D1C45) : Colors.white70,
                                  size: 14),
                              const SizedBox(width: 6),
                              Text(tab.label,
                                  style: TextStyle(
                                    color: sel ? const Color(0xFF0D1C45) : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── GeoGebra Area ─────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    kIsWeb
                        ? const HtmlElementView(viewType: 'physicstool-ggb-iframe')
                        : WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      _loadingWidget(
                        'GeoGebra ${_tabs[_selectedTab].label} load ho raha hai...',
                        _tabs[_selectedTab].icon,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MathFormulaPage — iMathEQ Equation Editor
// mathformula.php ki tarah same iframe load karta hai
// ─────────────────────────────────────────────────────────────────────────────

class MathFormulaPage extends StatefulWidget {
  const MathFormulaPage({Key? key}) : super(key: key);

  @override
  State<MathFormulaPage> createState() => _MathFormulaPageState();
}

class _MathFormulaPageState extends State<MathFormulaPage> {
  static const String _mathFormulaUrl =
      'https://www.imatheq.com/imatheq/com/imatheq/math-equation-editor.html';

  static bool _iframeRegistered = false;

  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (!_iframeRegistered) {
        webShim.registerIframeFactory('mathformula-iframe', _mathFormulaUrl);
        _iframeRegistered = true;
      }
      setState(() => _isLoading = false);
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
          onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
        ))
        ..loadRequest(Uri.parse(_mathFormulaUrl));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                height: 70,
                color: const Color(0xFF0D1C45),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _backBtn(context),
                    const Spacer(),
                    const Text(
                      'Math Formula',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _badgeChip('Powered by iMathEQ', Icons.functions_rounded),
                  ],
                ),
              ),

              // ── iMathEQ iFrame ────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    kIsWeb
                        ? const HtmlElementView(viewType: 'mathformula-iframe')
                        : WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      _loadingWidget(
                          'Loading Math Formula Editor...', Icons.functions_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets (top-level functions)
// ─────────────────────────────────────────────────────────────────────────────

Widget _backBtn(BuildContext context) => GestureDetector(
  onTap: () => Navigator.maybePop(context),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2E55), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2A4070), width: 1),
    ),
    child: const Row(children: [
      Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
      SizedBox(width: 6),
      Text('Back', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    ]),
  ),
);

Widget _badgeChip(String label, IconData icon) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(color: const Color(0xFF1A2E55), borderRadius: BorderRadius.circular(8)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: const Color(0xFFFFA600), size: 16),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: Color(0xFFFFA600), fontSize: 13, fontWeight: FontWeight.w600)),
  ]),
);

Widget _loadingWidget(String msg, IconData icon) => Container(
  color: const Color(0xFF0D1C45),
  child: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeInOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFA600), width: 2),
            ),
            child: Icon(icon, color: const Color(0xFFFFA600), size: 36),
          ),
        ),
        const SizedBox(height: 22),
        const CircularProgressIndicator(color: Color(0xFFFFA600), strokeWidth: 3),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Please wait...', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
      ],
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Models
// ─────────────────────────────────────────────────────────────────────────────

enum BoardType { miro, advanced, mindmap, uml, mathematics, mathFormula, physics, chemistry, comingSoon }

class _BoardItem {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final BoardType type;
  const _BoardItem({required this.title, required this.icon, required this.gradient, required this.type});
}

class _MathTab {
  final String label;
  final IconData icon;
  final String appName; // GeoGebra appName: classic, geometry, graphing, 3d, evaluator, scientific, notes
  const _MathTab({required this.label, required this.icon, required this.appName});
}