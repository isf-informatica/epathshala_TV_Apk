// screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'exam_list_page.dart';
import 'lecture_schedule_page.dart';
import 'boards_page.dart';
import 'tools_page.dart';
import 'login_page.dart';
import 'filter_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content_options_page.dart';

class LibraryPage extends StatefulWidget {
  final String regId;
  final String permissions;
  final Map<String, dynamic> loginData;

  const LibraryPage({
    Key? key,
    required this.regId,
    required this.permissions,
    this.loginData = const {},
  }) : super(key: key);

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {

  List<dynamic> _books       = [];
  List<dynamic> _filteredBooks = []; // search result
  bool          _isLoading   = true;
  String?       _error;

  int  _focusedIndex   = 0;
  bool _sidebarFocused = false;
  bool _focusOnMore    = false;
  int  _currentPage    = 0;

  // Search state
  bool   _searchActive = false;
  String _searchQuery  = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode             _searchFocusNode  = FocusNode();

  // TV sidebar nav state
  int _sidebarNavIndex = 3; // Library = index 3
  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards', 'Tools',
  ];

  static const int _pageSize = 10;

  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _loadBooks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final books = await ApiService.getLibraryBooks(
        regId: widget.regId,
        permissions: widget.permissions,
      );
      setState(() {
        _books         = books;
        _filteredBooks = books;
        _isLoading     = false;
        _focusedIndex  = 0;
        _currentPage   = 0;
        _focusOnMore   = false;
      });
      _fadeController.reset();
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _error     = 'Books load nahi hue. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Search filter
  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredBooks = _books;
      } else {
        final q = query.toLowerCase();
        _filteredBooks = _books.where((b) {
          final name   = (b['book_name']   ?? '').toString().toLowerCase();
          final author = (b['author_name'] ?? '').toString().toLowerCase();
          return name.contains(q) || author.contains(q);
        }).toList();
      }
      _currentPage  = 0;
      _focusedIndex = 0;
      _focusOnMore  = false;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _openSearch() {
    setState(() {
      _searchActive   = true;
      _sidebarFocused = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery  = '';
    });
    _searchController.clear();
    _applySearch('');
    _searchFocusNode.unfocus();
  }

  // Active books list (filtered or all)
  List<dynamic> get _activeBooks => _filteredBooks;

  // Current page books
  List<dynamic> get _pageBooks {
    final start = _currentPage * _pageSize;
    final end   = (start + _pageSize).clamp(0, _activeBooks.length);
    if (start >= _activeBooks.length) return [];
    return _activeBooks.sublist(start, end);
  }

  bool get _hasNextPage =>
      (_currentPage + 1) * _pageSize < _activeBooks.length;

  void _goNextPage() {
    if (!_hasNextPage) return;
    setState(() {
      _currentPage++;
      _focusedIndex = _currentPage * _pageSize;
      _focusOnMore  = false;
      _sidebarFocused = false;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _openBook(dynamic book) {
    final String bookName = book['book_name']?.toString() ?? 'Book';
    final String bookDoc  = book['book_doc']?.toString()  ?? '';

    if (bookDoc.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF available nahi hai is book ke liye.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Map<String, dynamic> chapterMap = {
      'id':          book['id']?.toString() ?? '0',
      'sub_topic':   bookName,
      'topic_docs':  bookDoc,
      'video_links': '',
      'book_name':   bookName,
      'book_image':  book['book_image']?.toString() ?? '',
    };

    final allBooks = _activeBooks.map<Map<String, dynamic>>((b) => {
      'id':          b['id']?.toString() ?? '0',
      'sub_topic':   b['book_name']?.toString() ?? 'Book',
      'topic_docs':  b['book_doc']?.toString() ?? '',
      'video_links': '',
    }).toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ContentOptionsPage(
          chapter:     chapterMap,
          subject:     'Library',
          grade:       0,
          medium:      '',
          courseId:    null,
          allChapters: allBooks,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Keyboard navigation ──────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Search active hone par keyboard ignore karo (TextField handle karega)
    if (_searchActive) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeSearch();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key     = event.logicalKey;
    final pageBks = _pageBooks;
    final pageLen = pageBks.length;
    const cols    = 2;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_sidebarFocused) {
        _executeSidebarNavItem(_navItems[_sidebarNavIndex]);
      } else if (_focusOnMore) {
        _goNextPage();
      } else if (_activeBooks.isNotEmpty && _focusedIndex < _activeBooks.length) {
        _openBook(_activeBooks[_focusedIndex]);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_focusOnMore) {
        setState(() => _focusOnMore = false);
      } else if (!_sidebarFocused) {
        setState(() => _sidebarFocused = true);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusOnMore) {
        setState(() => _focusOnMore = false);
        return KeyEventResult.handled;
      }
      if (!_sidebarFocused) {
        final localIdx = _focusedIndex - _currentPage * _pageSize;
        if (localIdx % cols == 0) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedIndex =
              (_focusedIndex - 1).clamp(0, _activeBooks.length - 1));
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
        return KeyEventResult.handled;
      }
      if (!_focusOnMore) {
        final localIdx  = _focusedIndex - _currentPage * _pageSize;
        final nextLocal = localIdx + 1;
        if (nextLocal < pageLen) {
          setState(() => _focusedIndex++);
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusOnMore) {
        setState(() {
          _focusOnMore  = false;
          _focusedIndex = _currentPage * _pageSize + pageLen - 1;
        });
        return KeyEventResult.handled;
      }
      if (_sidebarFocused) {
        if (_sidebarNavIndex > 0) setState(() => _sidebarNavIndex--);
        return KeyEventResult.handled;
      }
      final localIdx = _focusedIndex - _currentPage * _pageSize;
      if (localIdx == 0) {
        setState(() => _sidebarFocused = true);
      } else {
        setState(() => _focusedIndex =
            (_focusedIndex - 1).clamp(0, _activeBooks.length - 1));
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex < _navItems.length - 1) setState(() => _sidebarNavIndex++);
        return KeyEventResult.handled;
      }
      if (_focusOnMore) return KeyEventResult.handled;
      final localIdx  = _focusedIndex - _currentPage * _pageSize;
      final nextLocal = localIdx + 1;
      if (nextLocal >= pageLen) {
        if (_hasNextPage) setState(() => _focusOnMore = true);
      } else {
        setState(() => _focusedIndex = _focusedIndex + 1);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }


  // ── Sidebar nav execute ──────────────────────────────────────
  void _executeSidebarNavItem(String label) {
    switch (label) {
      case 'Library':
      // Already here
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
      case 'Boards':
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => BoardsPage(loginData: widget.loginData),
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
        Navigator.popUntil(context, (r) => r.isFirst);
        break;
      default:
        Navigator.maybePop(context);
    }
  }

  // ── LEFT SIDEBAR ─────────────────────────────────────────────
  Widget _buildSidebar() {
    final screenWidth  = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 600 ? 180.0 : 240.0;

    return Stack(
      children: [
        Container(
          width: sidebarWidth,
          decoration: const BoxDecoration(
            color: Color(0xFF1A0800),
            borderRadius: BorderRadius.only(
              topRight:    Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(3, 0)),
            ],
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
                      vertical:   screenWidth < 600 ? 6 : 10,
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
                            size:  screenWidth < 600 ? 30 : 42,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('EASY LEARN',
                            style: TextStyle(
                              color:        const Color(0xFFBF360C),
                              fontSize:     screenWidth < 600 ? 9 : 11,
                              fontWeight:   FontWeight.w900,
                              letterSpacing: 1.2,
                            )),
                        Text('EDUCATION FOR ALL',
                            style: TextStyle(
                              color:        const Color(0xFF6B8AB5),
                              fontSize:     screenWidth < 600 ? 6 : 7.5,
                              fontWeight:   FontWeight.w600,
                              letterSpacing: 0.8,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Nav items — same as SubjectsPage ──────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Column(
                    mainAxisAlignment:  MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _navItems.asMap().entries.map((entry) {
                      final navIdx  = entry.key;
                      final label   = entry.value;
                      final isActive   = label == 'Library';
                      final isTvFocus  = _sidebarFocused && navIdx == _sidebarNavIndex;
                      return GestureDetector(
                        onTap: () => _executeSidebarNavItem(label),
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
                                width:  isTvFocus ? 12 : 10,
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
                                    fontSize: screenWidth < 600 ? (isTvFocus ? 14 : 13) : (isTvFocus ? 20 : 19),
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
              // Powered by removed
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


  // ── Single book row — exact _chapterRow from TopicPage ───────
  Widget _bookRow(int globalIdx, double rowH) {
    final books     = _activeBooks;
    final book      = books[globalIdx];
    final isFocused = !_sidebarFocused && !_focusOnMore &&
        globalIdx == _focusedIndex;
    final bookName  = book['book_name']?.toString() ?? 'Unknown Book';
    final author    = book['author_name']?.toString() ?? '';
    final hasDoc    = (book['book_doc']?.toString() ?? '').isNotEmpty;

    // Serial number: use original index from _books for display
    final originalIdx = _books.indexWhere(
            (b) => b['id']?.toString() == book['id']?.toString());
    final displayNum  = (originalIdx >= 0 ? originalIdx + 1 : globalIdx + 1)
        .toString()
        .padLeft(2, '0');

    return GestureDetector(
      onTap: () {
        setState(() {
          _focusedIndex   = globalIdx;
          _sidebarFocused = false;
          _focusOnMore    = false;
        });
        _openBook(book);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: rowH,
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
              color:      const Color(0xFFBF360C).withOpacity(0.25),
              blurRadius: 8,
              offset:     const Offset(0, 2))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  displayNum,
                  style: TextStyle(
                    color:      isFocused
                        ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment:  MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:      isFocused
                            ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                        fontSize:   16,
                        fontWeight: isFocused
                            ? FontWeight.w700 : FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (author.isNotEmpty)
                      Text(author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF8B5E52), fontSize: 12)),
                  ],
                ),
              ),
              if (hasDoc)
                Icon(Icons.picture_as_pdf_rounded,
                    color: isFocused
                        ? const Color(0xFFBF360C) : const Color(0xFF3E1000).withOpacity(0.4),
                    size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Black tube column — exact TopicPage ──────────────────────
  Widget _buildColumn({
    required List<Widget> rows,
    required double       totalHeight,
    required double       tubeWidth,
    required double       tubeOffset,
  }) {
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            left: tubeOffset, top: 0, bottom: 0,
            child: Container(
              width: tubeWidth,
              decoration: BoxDecoration(
                color:        Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ],
      ),
    );
  }

  // ── HEADER with Search button ─────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: const Text(
        'Library Collection',
        style: TextStyle(
          color:      Color(0xFFBF360C),
          fontSize:   40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── RIGHT PANEL ──────────────────────────────────────────────
  Widget _buildBooksPanel() {
    if (_isLoading) {
      return Expanded(
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFBF360C)),
              SizedBox(height: 16),
              Text('Loading books...',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loadBooks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFBF360C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No results after search
    if (_activeBooks.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off,
                  color: Color(0xFFBF360C), size: 72),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? '"$_searchQuery" ke liye koi book nahi mili'
                    : 'No Books Available',
                style: const TextStyle(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _closeSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFBF360C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Clear Search',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final pageBks   = _pageBooks;
    final leftCount  = (pageBks.length / 2).ceil();
    final rightCount = pageBks.length - leftCount;
    final pageStart  = _currentPage * _pageSize;

    const tubeW      = 11.0;
    const tubeOffset = 10.0;
    const rowGap     = 10.0;
    const buffer     = 20.0;
    const moreH      = 80.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header with Search button ─────────────────────────
          _buildHeader(),

          // ── Triangle arrow ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: CustomPaint(
              size: const Size(26, 18),
              painter: _TriangleUpPainter(),
            ),
          ),

          // ── Books + More ──────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH  = constraints.maxHeight;
                final usableH = _hasNextPage ? availH - moreH - 16 : availH;

                final rowH = leftCount > 0
                    ? ((usableH - buffer) / leftCount - rowGap)
                    .clamp(48.0, 120.0)
                    : 70.0;
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
                                          (i) => _bookRow(pageStart + i, rowH)),
                                  totalHeight: colH,
                                  tubeWidth:   tubeW,
                                  tubeOffset:  tubeOffset,
                                ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: _buildColumn(
                                  rows: List.generate(rightCount,
                                          (i) => _bookRow(
                                          pageStart + leftCount + i, rowH)),
                                  totalHeight: colH,
                                  tubeWidth:   tubeW,
                                  tubeOffset:  tubeOffset,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // More... button
                      if (_hasNextPage)
                        SizedBox(
                          height: moreH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 20, 14),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _goNextPage,
                                child: AnimatedContainer(
                                  duration:
                                  const Duration(milliseconds: 130),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _focusOnMore
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.transparent,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _focusOnMore
                                          ? Colors.white54
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'More...',
                                    style: TextStyle(
                                      color: _focusOnMore
                                          ? const Color(0xFFBF360C)
                                          : Colors.white,
                                      fontSize:   28,
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
              _buildBooksPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Triangle painter ─────────────────────────────────────────────
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