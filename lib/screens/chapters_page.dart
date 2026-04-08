import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'content_options_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ChaptersPage extends StatefulWidget {
  final String subject;
  final List<dynamic> chapters;
  final int grade;
  final String medium;
  final String courseId;

  const ChaptersPage({
    Key? key,
    required this.subject,
    required this.chapters,
    required this.grade,
    required this.medium,
    required this.courseId,
  }) : super(key: key);

  @override
  State<ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<ChaptersPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _focusedChapterIndex = 0;
  bool _sidebarFocused = false;

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://isfinformatica.com');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Colors & Icons ───────────────────────────────────────────
  Color get _subjectColor {
    final s = widget.subject.toLowerCase();
    if (s.contains('math') || s.contains('गणित')) return const Color(0xFF3B82F6);
    if (s.contains('science') || s.contains('विज्ञान')) return const Color(0xFF059669);
    if (s.contains('english') || s.contains('अंग्रेजी')) return const Color(0xFF8B5CF6);
    if (s.contains('hindi') || s.contains('हिंदी')) return const Color(0xFFDC2626);
    if (s.contains('social') || s.contains('सामाजिक')) return const Color(0xFFEF4444);
    if (s.contains('odia') || s.contains('ଓଡ଼ିଆ')) return const Color(0xFF059669);
    if (s.contains('geography') || s.contains('भूगोल')) return const Color(0xFF10B981);
    if (s.contains('history') || s.contains('इतिहास')) return const Color(0xFFF59E0B);
    if (s.contains('computer') || s.contains('programming')) return const Color(0xFF6366F1);
    return const Color(0xFF6366F1);
  }

  IconData get _subjectIcon {
    final s = widget.subject.toLowerCase();
    if (s.contains('math')) return Icons.calculate_rounded;
    if (s.contains('science')) return Icons.science_rounded;
    if (s.contains('geography')) return Icons.public_rounded;
    if (s.contains('history')) return Icons.history_edu_rounded;
    if (s.contains('computer') || s.contains('programming')) return Icons.code_rounded;
    if (s.contains('english')) return Icons.menu_book_rounded;
    if (s.contains('hindi') || s.contains('odia')) return Icons.translate_rounded;
    if (s.contains('social')) return Icons.people_rounded;
    return Icons.book_rounded;
  }

  String _toRoman(int num) {
    const vals = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
    const syms = ['X', 'IX', 'VIII', 'VII', 'VI', 'V', 'IV', 'III', 'II', 'I'];
    var result = '';
    var n = num;
    for (var i = 0; i < vals.length; i++) {
      while (n >= vals[i]) {
        result += syms[i];
        n -= vals[i];
      }
    }
    return result;
  }

  // ── Keyboard navigation ──────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!_sidebarFocused && widget.chapters.isNotEmpty) {
        _openChapter(_focusedChapterIndex);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_sidebarFocused && _focusedChapterIndex % 8 == 0) {
        setState(() => _sidebarFocused = true);
      } else if (!_sidebarFocused) {
        setState(() => _focusedChapterIndex =
            (_focusedChapterIndex - 1).clamp(0, widget.chapters.length - 1));
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
      } else {
        setState(() => _focusedChapterIndex =
            (_focusedChapterIndex + 1).clamp(0, widget.chapters.length - 1));
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown && !_sidebarFocused) {
      setState(() => _focusedChapterIndex =
          (_focusedChapterIndex + 8).clamp(0, widget.chapters.length - 1));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp && !_sidebarFocused) {
      setState(() => _focusedChapterIndex =
          (_focusedChapterIndex - 8).clamp(0, widget.chapters.length - 1));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openChapter(int idx) {
    final chapter = widget.chapters[idx];
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ContentOptionsPage(
          chapter: chapter,
          subject: widget.subject,
          grade: widget.grade,
          medium: widget.medium,
          courseId: widget.courseId,
          allChapters: widget.chapters,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
            bottom: BorderSide(color: _subjectColor.withOpacity(0.25), width: 1)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: _subjectColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                        colors: [_subjectColor, _subjectColor.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // CLASS / MEDIUM
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
              children: [
                const TextSpan(
                    text: 'CLASS - ',
                    style: TextStyle(color: Color(0xFFAABBCC))),
                TextSpan(
                    text: _toRoman(widget.grade),
                    style: TextStyle(
                        color: _subjectColor, fontWeight: FontWeight.w800)),
                const TextSpan(
                    text: '   MEDIUM - ',
                    style: TextStyle(color: Color(0xFFAABBCC))),
                TextSpan(
                    text: widget.medium.split(' ')[0],
                    style: TextStyle(
                        color: _subjectColor, fontWeight: FontWeight.w800)),
              ],
            ),
          ),

          const Spacer(),

          const Text(
            "Let's Get Started!",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3),
          ),
          const SizedBox(width: 8),
          Text(
            'Select your Chapter',
            style: TextStyle(
                color: _subjectColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),

          // Chapter count badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _subjectColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _subjectColor.withOpacity(0.5)),
            ),
            child: Text(
              '${widget.chapters.length} Chapters',
              style: TextStyle(
                  color: _subjectColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────
  Widget _buildSidebar() {
    final color = _subjectColor;
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.06), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject info block
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                child: Icon(_subjectIcon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.subject,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text('CHAPTERS', style: TextStyle(
                color: Color(0xFF4B5A7A), fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),

          // ── Scrollable chapters list ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemCount: widget.chapters.length,
              itemBuilder: (context, idx) {
                final chapter = widget.chapters[idx] as Map<String, dynamic>;
                final chapterName = chapter['sub_topic']?.toString()
                    ?? chapter['chapter']?.toString()
                    ?? chapter['subtopic_name']?.toString()
                    ?? chapter['chapter_name']?.toString()
                    ?? chapter['name']?.toString()
                    ?? 'Chapter ${idx + 1}';
                final isSelected = idx == _focusedChapterIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _focusedChapterIndex = idx;
                      _sidebarFocused = true;
                    });
                    _openChapter(idx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color.withOpacity(0.6) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${idx + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontSize: 9, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(chapterName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFAABBCC),
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                      if (isSelected)
                        Icon(Icons.chevron_right, color: color, size: 12),
                    ]),
                  ),
                );
              },
            ),
          ),

          // Back button at bottom
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Row(children: [
                Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 11),
                SizedBox(width: 6),
                Text('Back',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

        ],
      ),
    );
  }

  // ── Chapter Grid ─────────────────────────────────────────────
  Widget _buildChapterGrid() {
    final color = _subjectColor;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const int cols = 8;
          const int visibleRows = 6;
          const double pad = 10;
          const double gap = 8;

          final double cardW =
              (constraints.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
          final double cardH =
              (constraints.maxHeight - pad * 2 - gap * (visibleRows - 1)) /
                  visibleRows;

          return GridView.builder(
            padding: const EdgeInsets.all(pad),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: cardW / cardH,
            ),
            itemCount: widget.chapters.length,
            itemBuilder: (context, idx) {
              final chapter =
                  widget.chapters[idx] as Map<String, dynamic>;
              final chapterName = chapter['sub_topic']?.toString()
                  ?? chapter['chapter']?.toString()
                  ?? chapter['subtopic_name']?.toString()
                  ?? chapter['chapter_name']?.toString()
                  ?? chapter['name']?.toString()
                  ?? 'Chapter ${idx + 1}';
              final isFocused =
                  !_sidebarFocused && idx == _focusedChapterIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _focusedChapterIndex = idx;
                    _sidebarFocused = false;
                  });
                  _openChapter(idx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? color.withOpacity(0.2)
                        : const Color(0xFF141A2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? color
                          : const Color(0xFF1E2A4A),
                      width: isFocused ? 2.5 : 1,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]
                        : [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isFocused
                              ? color
                              : color.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              color: isFocused ? Colors.white : color,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          chapterName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isFocused
                                ? Colors.white
                                : const Color(0xFFCDD5E0),
                            fontSize: 9,
                            fontWeight: isFocused
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline,
                              size: 9,
                              color: isFocused
                                  ? color
                                  : const Color(0xFF4B5A7A)),
                          const SizedBox(width: 2),
                          Text(
                            'Start',
                            style: TextStyle(
                              color: isFocused
                                  ? color
                                  : const Color(0xFF4B5A7A),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        body: Column(
          children: [
            SafeArea(child: _buildHeader()),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildChapterGrid()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}