import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/content_options_page.dart';

/// TopicPage — Figma Image 2 exact:
/// • Black vertical tube sits BEHIND chapter rows (Stack)
/// • Triangle arrow connects to top of black tube
/// • 12 boxes max (6 left + 6 right), More... when > 12
/// • Bigger row gap + bigger mid-column gap

class TopicPage extends StatefulWidget {
  final List<dynamic> topics;
  final int initialSubjectIndex;
  final int grade;
  final String medium;
  final String? courseId;

  const TopicPage({
    Key? key,
    required this.topics,
    this.initialSubjectIndex = 0,
    required this.grade,
    required this.medium,
    this.courseId,
  }) : super(key: key);

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage>
    with SingleTickerProviderStateMixin {

  late int _focusedSubjectIndex;
  int  _focusedChapterIndex = 0;
  bool _sidebarFocused      = true;
  bool _showExpanded        = false; // More... click pe saare boxes dikhao

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _focusedSubjectIndex =
        widget.initialSubjectIndex.clamp(0, widget.topics.length - 1);

    // ── Auto: pehla subject (Math) aur pehla topic sirf highlight hoga ──
    _focusedChapterIndex = 0;
    _sidebarFocused      = false; // chapter grid focus mein — highlight dikhega

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentSubject =>
      Map<String, dynamic>.from(widget.topics[_focusedSubjectIndex] as Map);

  List<dynamic> get _currentChapters =>
      (_currentSubject['chapters'] as List? ?? []).cast<dynamic>();

  String _chName(dynamic ch, int i) {
    if (ch is! Map) return 'Chapter ${i + 1}';
    return ch['sub_topic']?.toString()
        ?? ch['chapter']?.toString()
        ?? ch['subtopic_name']?.toString()
        ?? ch['chapter_name']?.toString()
        ?? ch['name']?.toString()
        ?? 'Chapter ${i + 1}';
  }

  void _selectSubject(int idx) {
    if (idx == _focusedSubjectIndex) return;
    setState(() {
      _focusedSubjectIndex = idx;
      _focusedChapterIndex = 0;     // pehla topic highlight
      _sidebarFocused      = false; // chapter grid pe focus — highlight dikhega
      _showExpanded        = false;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _openChapterContent(Map<String, dynamic> chapter) {
    if (widget.courseId == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ContentOptionsPage(
          chapter: chapter,
          subject: _currentSubject['subject'].toString(),
          grade: widget.grade,
          medium: widget.medium,
          courseId: widget.courseId,
          allChapters: _currentChapters,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Keyboard navigation ─────────────────────────────────────
  // _sidebarFocused=true  → subject list active
  // _sidebarFocused=false → chapter grid active (_focusOnMore=true: More btn)
  bool _focusOnMore = false; // More... button focused

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key      = event.logicalKey;
    final chapters = _currentChapters;
    const cols     = 2;

    // ── OK / Enter ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_sidebarFocused) {
        setState(() { _sidebarFocused = false; _focusOnMore = false; });
      } else if (_focusOnMore) {
        // More... button press
        setState(() { _showExpanded = true; _focusOnMore = false; _focusedChapterIndex = 12; }); // expanded items start at index 12
        _fadeController.reset(); _fadeController.forward();
      } else if (_focusedChapterIndex < chapters.length) {
        _openChapterContent(chapters[_focusedChapterIndex] as Map<String, dynamic>);
      }
      return KeyEventResult.handled;
    }

    // ── Back / Escape ─────────────────────────────────────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_showExpanded) {
        // More ke baad wapas 1-12 pe
        setState(() { _showExpanded = false; _focusedChapterIndex = 0; _focusOnMore = false; });
        _fadeController.reset(); _fadeController.forward();
      } else if (_focusOnMore) {
        setState(() { _focusOnMore = false; });
      } else if (!_sidebarFocused) {
        setState(() { _sidebarFocused = true; _focusedChapterIndex = 0; });
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    // Layout:
    // Normal mode:   displays index 0..11  (leftCount = ceil(12/2) = 6)
    // Expanded mode: displays index 12..N  (leftCount = ceil(remaining/2))
    // _focusedChapterIndex is always the GLOBAL chapter index
    const firstExpanded = 12;
    final startIdx      = _showExpanded ? firstExpanded : 0;
    final endIdx        = _showExpanded ? chapters.length : chapters.length.clamp(0, 12);
    final visibleCount  = endIdx - startIdx;
    final leftCount     = (visibleCount / 2).ceil();
    // local index within the current display (0-based)
    final localIdx      = _focusedChapterIndex - startIdx;
    final inLeftCol     = localIdx < leftCount;
    final rowInCol      = inLeftCol ? localIdx : localIdx - leftCount;

    // ── Arrow LEFT ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusOnMore) {
        setState(() { _focusOnMore = false; });
        return KeyEventResult.handled;
      }
      if (!_sidebarFocused) {
        if (inLeftCol) {
          // Left col se aur left → sidebar
          setState(() => _sidebarFocused = true);
        } else {
          // Right col → left col, same row (global index)
          final target = startIdx + rowInCol.clamp(0, leftCount - 1);
          setState(() => _focusedChapterIndex = target);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // ── Arrow RIGHT ───────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
        return KeyEventResult.handled;
      }
      if (!_focusOnMore) {
        if (inLeftCol) {
          // Left col → right col, same row (global index)
          final target = startIdx + leftCount + rowInCol;
          if (target < chapters.length) {
            setState(() => _focusedChapterIndex = target);
          }
        }
        // Right col pe already hain — aur right nahi jaana
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // ── Arrow UP ──────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusOnMore) {
        // More button se upar → last visible chapter pe jao (always normal mode last = index 11)
        setState(() { _focusOnMore = false; _focusedChapterIndex = (chapters.length.clamp(0,12) - 1).clamp(0, chapters.length - 1); });
        return KeyEventResult.handled;
      }
      if (_sidebarFocused) {
        _selectSubject((_focusedSubjectIndex - 1).clamp(0, widget.topics.length - 1));
        return KeyEventResult.handled;
      }
      // Same column mein ek row upar
      if (rowInCol == 0) {
        if (_showExpanded) {
          // Expanded top row → back to normal view last item
          setState(() { _showExpanded = false; _focusedChapterIndex = 11; });
          _fadeController.reset(); _fadeController.forward();
        } else {
          // Normal top row → sidebar
          setState(() => _sidebarFocused = true);
        }
      } else {
        setState(() => _focusedChapterIndex = _focusedChapterIndex - 1);
      }
      return KeyEventResult.handled;
    }

    // ── Arrow DOWN ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        _selectSubject((_focusedSubjectIndex + 1).clamp(0, widget.topics.length - 1));
        return KeyEventResult.handled;
      }
      if (_focusOnMore) return KeyEventResult.handled;
      // Same column mein ek row neeche
      final rightCount = visibleCount - leftCount;
      final colSize    = inLeftCol ? leftCount : rightCount;
      if (rowInCol >= colSize - 1) {
        // Last row of this column
        final needsMore = !_showExpanded && chapters.length > 12;
        if (needsMore && !inLeftCol) setState(() => _focusOnMore = true);
        // Left col last row — do nothing (right col may have more)
      } else {
        setState(() => _focusedChapterIndex = (_focusedChapterIndex + 1).clamp(0, chapters.length - 1));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── LEFT SIDEBAR ─────────────────────────────────────────────
  // Exactly matches SubjectsPage sidebar: same width, logo box, nav style
  Widget _buildSidebar() {
    // Responsive width — same as SubjectsPage
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 600 ? 180.0 : 240.0;

    return Stack(
      children: [
        Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        // Same rounded right edge as SubjectsPage
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Logo box — same as SubjectsPage ──────────────────
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
                      'assets/images/logo.png',
                      height: screenWidth < 600 ? 36 : 50,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.school,
                        color: const Color(0xFF1A3A7C),
                        size: screenWidth < 600 ? 30 : 42,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EASY LEARN',
                      style: TextStyle(
                        color: const Color(0xFFBF360C),
                        fontSize: screenWidth < 600 ? 9 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'EDUCATION FOR ALL',
                      style: TextStyle(
                        color: const Color(0xFF6B8AB5),
                        fontSize: screenWidth < 600 ? 6 : 7.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Subject list — fixed top gap same as SubjectsPage ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(widget.topics.length, (idx) {
                  final sName    = widget.topics[idx]['subject'].toString();
                  final isActive = idx == _focusedSubjectIndex;
                  return GestureDetector(
                    onTap: () => _selectSubject(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 600 ? 10 : 20,
                        vertical: 10,
                      ),
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          // Same square bullet as SubjectsPage
                          Container(
                            width: 10,
                            height: 10,
                            color: isActive
                                ? const Color(0xFFBF360C)
                                : Colors.white,
                          ),
                          SizedBox(width: screenWidth < 600 ? 6 : 12),
                          Expanded(
                            child: Text(
                              sName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFFBF360C)
                                    : Colors.white,
                                fontSize: screenWidth < 600 ? 13 : 19,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
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


  // ── Single chapter row ───────────────────────────────────────
  Widget _chapterRow(int chIdx, double rowH) {
    final chapters  = _currentChapters;
    final isFocused = !_sidebarFocused && chIdx == _focusedChapterIndex;
    final chapter   = chapters[chIdx] as Map<String, dynamic>;
    final name      = _chName(chapter, chIdx);

    return GestureDetector(
      onTap: () {
        setState(() {
          _focusedChapterIndex = chIdx;
          _sidebarFocused      = false;
        });
        _openChapterContent(chapter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: rowH,
        // gap set via margin — last row ka margin Column ke bahar trim hoga
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFFFFF8F5)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: isFocused
              ? Border.all(color: const Color(0xFFBF360C), width: 2)
              : Border.all(color: const Color(0xFFE8D5CC), width: 1),
          boxShadow: isFocused
              ? [BoxShadow(
                  color: const Color(0xFFBF360C).withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  (chIdx + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isFocused
                        ? const Color(0xFFBF360C)
                        : const Color(0xFF3E1000),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFocused
                        ? const Color(0xFFBF360C)
                        : const Color(0xFF3E1000),
                    fontSize: 26,
                    fontWeight: isFocused
                        ? FontWeight.w700
                        : FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── One column: black tube BEHIND rows (Stack) ───────────────
  // tubeOffset = how far from left edge the tube is (aligns with arrow)
  Widget _buildColumn({
    required List<Widget> rows,
    required double totalHeight,
    required double tubeWidth,
    required double tubeOffset, // left offset of tube inside the column
  }) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // ── Black vertical tube — BEHIND rows ──────────────
          Positioned(
            left: tubeOffset,
            top: 0,
            bottom: 0,
            child: Container(
              width: tubeWidth,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // ── Chapter rows on top of tube ─────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ],
      ),
    );
  }


  // ── RIGHT PANEL ─────────────────────────────────────────────
  Widget _buildChaptersPanel() {
    final chapters    = _currentChapters;
    final subjectName = _currentSubject['subject'].toString();
    final totalCount  = chapters.length;

    const maxVisible = 12;
    final needsMore  = !_showExpanded && totalCount > maxVisible;

    // Normal: pehle 12, More click: sirf 13 ke baad wale
    final displayChapters = _showExpanded
        ? chapters.sublist(maxVisible)          // sirf 13, 14, 15...
        : chapters.sublist(0, totalCount.clamp(0, maxVisible)); // 1-12

    final visibleCount = displayChapters.length;
    final leftCount    = (visibleCount / 2).ceil();
    final rightCount   = visibleCount - leftCount;

    // Chapter index — expanded mode mein original index chahiye
    int chapterIndex(int displayIdx) =>
        _showExpanded ? maxVisible + displayIdx : displayIdx;

    final focusedName = _focusedChapterIndex < chapters.length
        ? '${(_focusedChapterIndex + 1).toString().padLeft(2, '0')}  '
          '${_chName(chapters[_focusedChapterIndex], _focusedChapterIndex)}'
        : '';

    const tubeW      = 11.0;
    const tubeOffset = 10.0;
    const rowGap     = 10.0;
    const buffer     = 20.0;
    const moreH      = 80.0; // fontSize 28 + padding + safe margin

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Expanded mode mein Back button ──────────
                if (_showExpanded)
                  GestureDetector(
                    onTap: () {
                      setState(() { _showExpanded = false; _focusedChapterIndex = 0; _focusOnMore = false; });
                      _fadeController.reset(); _fadeController.forward();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 6),
                          Text('1–12', style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                Text(subjectName,
                    style: const TextStyle(
                      color: Color(0xFFBF360C),
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                if (focusedName.isNotEmpty)
                  Flexible(
                    child: Text(focusedName,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFBF360C),
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
              ],
            ),
          ),

          // ── Arrow ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: CustomPaint(
              size: const Size(26, 18),
              painter: _TriangleUpPainter(),
            ),
          ),

          // ── Chapter grid ──────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH  = constraints.maxHeight;
                // More button ke liye extra 8px top padding bhi include karo
                final usableH = needsMore ? availH - moreH - 16 : availH;

                final rowH = leftCount > 0
                    ? ((usableH - buffer) / leftCount - rowGap)
                        .clamp(48.0, 120.0)
                    : 70.0;
                // colH ko usableH se cap karo — More button kabhi cut off nahi hoga
                final colH = (leftCount * (rowH + rowGap)).clamp(0.0, usableH);

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildColumn(
                                  rows: List.generate(leftCount,
                                      (i) => _chapterRow(chapterIndex(i), rowH)),
                                  totalHeight: colH,
                                  tubeWidth: tubeW,
                                  tubeOffset: tubeOffset,
                                ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: _buildColumn(
                                  rows: List.generate(rightCount,
                                      (i) => _chapterRow(chapterIndex(leftCount + i), rowH)),
                                  totalHeight: colH,
                                  tubeWidth: tubeW,
                                  tubeOffset: tubeOffset,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── More... button ────────────────────────
                      if (needsMore)
                        SizedBox(
                          height: moreH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 20, 14),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() { _showExpanded = true; _focusOnMore = false; });
                                  _fadeController.reset();
                                  _fadeController.forward();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _focusOnMore
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _focusOnMore ? Colors.white54 : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'More...',
                                    style: TextStyle(
                                      color: _focusOnMore ? const Color(0xFFBF360C) : Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _blackSquare() => Container(
        width: 20, height: 16,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── Main build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              _buildChaptersPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Triangle painter ─────────────────────────────────────────
class _TriangleUpPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}