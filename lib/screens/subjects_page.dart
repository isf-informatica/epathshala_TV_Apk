import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/profile_storage.dart';
import '../screens/login_page.dart';
import '../screens/filter_page.dart';
import '../screens/content_options_page.dart';
import '../screens/topic_page.dart';
import '../services/api_service.dart';
// import '../screens/whiteboard_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'library_page.dart';
import 'exam_list_page.dart';
import '../screens/boards_page.dart';
import 'lecture_schedule_page.dart';
import '../screens/text_speech_page.dart';
import '../screens/tools_page.dart';

class SubjectsPage extends StatefulWidget {
  final int grade;
  final String medium;
  final List<dynamic> courses;
  final Map<String, dynamic> loginData;

  // Optional: pass all mediums so sidebar can show them
  // If null, sidebar shows only the single medium passed
  final List<Map<String, dynamic>>? allMediumCourses;
  // [{medium: 'Hindi Medium', courses: [...]}, ...]

  const SubjectsPage({
    Key? key,
    required this.grade,
    required this.medium,
    required this.courses,
    required this.loginData,
    this.allMediumCourses,
  }) : super(key: key);

  @override
  _SubjectsPageState createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage>
    with TickerProviderStateMixin {
  // ── Existing state ──────────────────────────────────────────
  List<dynamic> topics = [];
  bool isLoading = true;
  String? selectedCourseId;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── New TV sidebar state ────────────────────────────────────
  late int _selectedMediumIndex;
  int _selectedCourseIndex = 0;
  int _focusedSubjectIndex = 0;
  bool _sidebarFocused = false; // ← false: pehla subject highlighted dikhega

  // Active sidebar nav item
  String _activeSidebarItem = 'Courses';

  // ── Library inline state ────────────────────────────────────
  bool          _showLibrary    = false;
  List<dynamic> _libBooks       = [];
  List<dynamic> _libFiltered    = [];
  bool          _libLoading     = false;
  String?       _libError;
  int           _libFocusedIdx  = 0;
  bool          _libFocusOnMore = false;
  int           _libCurrentPage = 0;
  bool          _libSearchActive= false;
  String        _libSearchQuery = '';
  final TextEditingController _libSearchCtrl = TextEditingController();
  static const int _libPageSize = 12;

  // TV: sidebar mein focused nav item index (0 = Courses ... 7 = Logout)
  int _sidebarNavIndex = 0;
  // TV: sidebar zone — 'medium' (top medium tabs) ya 'nav' (bottom nav items)
  String _sidebarZone = 'nav'; // 'medium' | 'nav'

  // All mediums for sidebar — built from allMediumCourses or single medium
  late List<Map<String, dynamic>> _sidebarItems;

  // ── Logout Handler — disabled for now ───────────────────────
  // Future<void> _handleLogout() async {
  //   final List<String> allMediums = _sidebarItems
  //       .map((item) => item['medium'].toString())
  //       .toList();
  //   final String? partner = widget.loginData['partner'] as String?;
  //   await ApiService.saveLastLogin(
  //     email:    widget.loginData['email']?.toString() ?? '',
  //     password: widget.loginData['password']?.toString() ?? '',
  //     grade:    widget.grade,
  //     mediums:  allMediums,
  //     partner:  partner,
  //   );
  //   await ProfileStorage.setActiveProfile('');
  //   if (!mounted) return;
  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => LoginPage(
  //         onLoginComplete: (email, password) {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(
  //               builder: (_) => FilterPage(
  //                 profile: {'email': email, 'password': password, 'name': '', 'avatar': '????'},
  //               ),
  //             ),
  //           );
  //         },
  //       ),
  //     ),
  //     (route) => false,
  //   );
  // }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://isfinformatica.com');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void initState() {
    super.initState();

    // Build sidebar items
    if (widget.allMediumCourses != null && widget.allMediumCourses!.isNotEmpty) {
      _sidebarItems = widget.allMediumCourses!;
    } else {
      _sidebarItems = [
        {'medium': widget.medium, 'courses': widget.courses},
      ];
    }

    // Find which index matches the initially selected medium
    _selectedMediumIndex = _sidebarItems.indexWhere(
          (item) => item['medium'].toString() == widget.medium,
    );
    if (_selectedMediumIndex < 0) _selectedMediumIndex = 0;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _loadTopics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _libSearchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────
  String get _activeMedium =>
      _sidebarItems[_selectedMediumIndex]['medium'].toString();

  List<dynamic> get _activeCourses =>
      (_sidebarItems[_selectedMediumIndex]['courses'] as List? ?? [])
          .cast<dynamic>();

  // Circular logo widget for header
  Widget _buildCircularLogo({double? size, bool showDebugInfo = false}) {
    return Container(
      width: size ?? 40,
      height: size ?? 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF30363D), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo_easylearn.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                ),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 24,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Data loading (unchanged logic, uses _activeCourses now) ─
  Future<void> _loadTopics() async {
    final mediumWord = _activeMedium.toLowerCase().split(' ')[0];
    final gradeStr = widget.grade.toString();
    final courses = _activeCourses;

    setState(() {
      isLoading = true;
      topics = [];
      _focusedSubjectIndex = 0;
    });

    if (courses.isEmpty) {
      setState(() { isLoading = false; });
      return;
    }

    // Strategy 1: medium word match
    dynamic course = courses.cast<dynamic>().firstWhere(
          (c) => (c['course_name'] ?? '').toString().toLowerCase().contains(mediumWord),
      orElse: () => null,
    );
    // Strategy 2: grade number match
    course ??= courses.cast<dynamic>().firstWhere(
          (c) => (c['course_name'] ?? '').toString().contains(gradeStr),
      orElse: () => null,
    );
    // Strategy 3: first course fallback
    course ??= courses.first;

    final orderedCourses = [
      course,
      ...courses.where((c) => c['id'].toString() != course['id'].toString()),
    ];

    for (var candidate in orderedCourses) {
      final courseId = candidate['id']?.toString() ?? '';
      if (courseId.isEmpty) continue;

      final topicsData = await ApiService.getTopicsByCourseId(courseId);

      if (topicsData.isNotEmpty) {
        selectedCourseId = courseId;

        final Map<String, List<dynamic>> grouped = {};
        for (var topic in topicsData) {
          final name = (topic['topic_name'] ?? 'Unknown').toString();
          grouped.putIfAbsent(name, () => []).add(topic);
        }

        setState(() {
          topics = grouped.entries
              .map((e) => {'subject': e.key, 'chapters': e.value})
              .toList();
          isLoading = false;
          _focusedSubjectIndex = 0; // pehla subject highlight
          _sidebarFocused = false;  // grid pe focus — sirf highlight, open nahi
        });
        _fadeController.reset();
        _fadeController.forward();
        return;
      }
    }

    setState(() { isLoading = false; });
  }

  IconData _getSubjectIcon(String subject) {
    subject = subject.toLowerCase();
    if (subject.contains('math') || subject.contains('गणित')) return Icons.calculate_rounded;
    if (subject.contains('science') || subject.contains('विज्ञान')) return Icons.science_rounded;
    if (subject.contains('geography') || subject.contains('भूगोल')) return Icons.public_rounded;
    if (subject.contains('history') || subject.contains('इतिहास')) return Icons.history_edu_rounded;
    if (subject.contains('programming') || subject.contains('computer')) return Icons.code_rounded;
    if (subject.contains('english') || subject.contains('अंग्रेजी')) return Icons.menu_book_rounded;
    if (subject.contains('social') || subject.contains('सामाजिक')) return Icons.people_rounded;
    if (subject.contains('hindi') || subject.contains('हिंदी')) return Icons.translate_rounded;
    if (subject.contains('odia') || subject.contains('ଓଡ଼ିଆ')) return Icons.translate_rounded;
    return Icons.book_rounded;
  }

  Color _getMediumAccentColor(String medium) {
    if (medium.contains('Odia')) return const Color(0xFF059669);
    if (medium.contains('Hindi')) return const Color(0xFFDC2626);
    if (medium.contains('English')) return const Color(0xFF3B82F6);
    return const Color(0xFF6366F1);
  }

  Color get _activeAccentColor => _getMediumAccentColor(_activeMedium);

  // Convert grade number to Roman numeral
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

  // ── Sidebar medium switcher ──────────────────────────────────
  void _switchMedium(int idx) {
    if (idx == _selectedMediumIndex) return;
    setState(() {
      _selectedMediumIndex = idx;
      _selectedCourseIndex = 0;
    });
    _loadTopics();
  }

  // Only courses matching the selected medium
  List<dynamic> get _mediumCourseList {
    final allCourses = (_sidebarItems[_selectedMediumIndex]['courses'] as List? ?? []).cast<dynamic>();
    final mediumWord = widget.medium.toLowerCase().split(' ')[0]; // e.g. "hindi" or "english"
    final filtered = allCourses.where((c) {
      final name = (c['course_name'] ?? '').toString().toLowerCase();
      return name.contains(mediumWord);
    }).toList();
    // fallback: agar filter se kuch na mile toh saare dikhao
    return filtered.isNotEmpty ? filtered : allCourses;
  }

  // Course ka short display name — sirf "Course 1", "Course 2"
  String _courseDisplayName(String courseName, int idx) {
    return 'Course ${idx + 1}';
  }

  void _switchCourse(int idx) {
    if (idx == _selectedCourseIndex) return;
    setState(() {
      _selectedCourseIndex = idx;
      _focusedSubjectIndex = 0;
    });
    _loadTopicsByCourse();
  }

  Future<void> _loadTopicsByCourse() async {
    final courses = _mediumCourseList;
    if (courses.isEmpty) return;
    final course = courses[_selectedCourseIndex.clamp(0, courses.length - 1)];
    final courseId = course['id']?.toString() ?? '';
    if (courseId.isEmpty) return;

    setState(() { isLoading = true; topics = []; });

    final topicsData = await ApiService.getTopicsByCourseId(courseId);
    if (topicsData.isNotEmpty) {
      selectedCourseId = courseId;
      final Map<String, List<dynamic>> grouped = {};
      for (var topic in topicsData) {
        final name = (topic['topic_name'] ?? 'Unknown').toString();
        grouped.putIfAbsent(name, () => []).add(topic);
      }
      setState(() {
        topics = grouped.entries
            .map((e) => {'subject': e.key, 'chapters': e.value})
            .toList();
        isLoading = false;
        _focusedSubjectIndex = 0;
        _sidebarFocused = false;
      });
      _fadeController.reset();
      _fadeController.forward();
    } else {
      setState(() { isLoading = false; });
    }
  }

  // ── Remote/keyboard navigation ───────────────────────────────
  // ZONES:
  //   _sidebarFocused=false → subject grid active
  //   _sidebarFocused=true  → sidebar active
  //     _sidebarZone='medium' → medium tabs highlighted
  //     _sidebarZone='nav'    → nav items (Courses/Logout etc) highlighted

  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards',
    'Tools',  // 'Logout',
  ];

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ── OK / Enter / Select ──────────────────────────────────
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!_sidebarFocused && _showLibrary) {
        if (_libFocusOnMore) {
          setState(() { _libCurrentPage++; _libFocusedIdx = _libCurrentPage * _libPageSize; _libFocusOnMore = false; });
          _fadeController.reset(); _fadeController.forward();
        } else if (_libFocusedIdx < _libFiltered.length) {
          _openBook(_libFiltered[_libFocusedIdx]);
        }
        return KeyEventResult.handled;
      }
      if (!_sidebarFocused) {
        // Grid pe OK → subject open karo
        if (topics.isNotEmpty) _openChapters(_focusedSubjectIndex);
      } else if (_sidebarZone == 'medium') {
        // Medium tab pe OK → medium switch karo, grid pe jao
        setState(() => _sidebarFocused = false);
      } else {
        // Nav item pe OK → execute karo
        _executeSidebarNavItem(_navItems[_sidebarNavIndex]);
      }
      return KeyEventResult.handled;
    }

    // ── Back / Escape ────────────────────────────────────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_showLibrary && !_sidebarFocused) {
        // Library open hai — sidebar pe jao
        setState(() { _sidebarFocused = true; _sidebarZone = 'nav'; });
      } else if (_showLibrary && _sidebarFocused) {
        // Sidebar pe hai library ke saath — library close karo
        _closeLibrary();
      } else if (!_sidebarFocused) {
        setState(() { _sidebarFocused = true; _sidebarZone = 'nav'; });
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    // ── Arrow LEFT ───────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_sidebarFocused && _showLibrary) {
        final localIdx = _libFocusedIdx - _libCurrentPage * _libPageSize;
        if (localIdx % 2 == 0) {
          setState(() { _sidebarFocused = true; _sidebarZone = 'nav'; });
        } else {
          setState(() => _libFocusedIdx = (_libFocusedIdx - 1).clamp(0, _libFiltered.length - 1));
        }
        return KeyEventResult.handled;
      }
      if (!_sidebarFocused) {
        // Grid se sidebar pe jao (sirf left column se)
        final cols = _gridCols;
        if (_focusedSubjectIndex % cols == 0) {
          setState(() { _sidebarFocused = true; _sidebarZone = 'nav'; });
        } else {
          setState(() => _focusedSubjectIndex =
              (_focusedSubjectIndex - 1).clamp(0, topics.length - 1));
        }
        return KeyEventResult.handled;
      }
      // Sidebar mein left → kuch nahi
      return KeyEventResult.handled;
    }

    // ── Arrow RIGHT ──────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
        return KeyEventResult.handled;
      }
      if (_showLibrary) {
        final localIdx  = _libFocusedIdx - _libCurrentPage * _libPageSize;
        final nextLocal = localIdx + 1;
        if (nextLocal < _libPageBooks.length) setState(() => _libFocusedIdx++);
        return KeyEventResult.handled;
      }
      // Grid mein right
      setState(() => _focusedSubjectIndex =
          (_focusedSubjectIndex + 1).clamp(0, topics.length - 1));
      return KeyEventResult.handled;
    }

    // ── Arrow UP ─────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarFocused) {
        if (_sidebarZone == 'medium') {
          if (_selectedMediumIndex > 0) {
            _switchMedium(_selectedMediumIndex - 1);
          } else {
            // Medium tabs ke upar se nav pe jao
            setState(() => _sidebarZone = 'nav');
          }
        } else {
          // nav zone mein upar
          if (_sidebarNavIndex > 0) {
            setState(() => _sidebarNavIndex--);
          }
        }
      } else if (_showLibrary) {
        // Library grid navigation UP
        final localIdx = _libFocusedIdx - _libCurrentPage * _libPageSize;
        if (_libFocusOnMore) {
          setState(() { _libFocusOnMore = false; _libFocusedIdx = _libCurrentPage * _libPageSize + _libPageBooks.length - 1; });
        } else if (localIdx < 2) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _libFocusedIdx = (_libFocusedIdx - 2).clamp(0, _libFiltered.length - 1));
        }
      } else {
        // Grid mein upar
        final cols = _gridCols;
        if (_focusedSubjectIndex < cols) {
          // Top row se sidebar nav pe jao
          setState(() { _sidebarFocused = true; _sidebarZone = 'nav'; });
        } else {
          setState(() => _focusedSubjectIndex =
              (_focusedSubjectIndex - cols).clamp(0, topics.length - 1));
        }
      }
      return KeyEventResult.handled;
    }

    // ── Arrow DOWN ───────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        if (_sidebarZone == 'nav') {
          if (_sidebarNavIndex < _navItems.length - 1) {
            setState(() => _sidebarNavIndex++);
          } else if (_sidebarItems.length > 1) {
            // Nav ke neeche medium tabs hain
            setState(() { _sidebarZone = 'medium'; });
          }
        } else {
          // medium zone mein neeche
          if (_selectedMediumIndex < _sidebarItems.length - 1) {
            _switchMedium(_selectedMediumIndex + 1);
          }
        }
      } else if (_showLibrary) {
        if (_libFocusOnMore) return KeyEventResult.handled;
        final localIdx  = _libFocusedIdx - _libCurrentPage * _libPageSize;
        final nextLocal = localIdx + 2;
        if (nextLocal >= _libPageBooks.length) {
          if (_libHasNext) setState(() => _libFocusOnMore = true);
        } else {
          setState(() => _libFocusedIdx = _libFocusedIdx + 2);
        }
      } else {
        // Grid mein neeche
        final cols = _gridCols;
        setState(() => _focusedSubjectIndex =
            (_focusedSubjectIndex + cols).clamp(0, topics.length - 1));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // Grid columns — screen size se determine karo
  int get _gridCols {
    try {
      final w = MediaQuery.of(context).size.width;
      final sidebarW = w < 600 ? 180.0 : 240.0;
      return (w - sidebarW) >= 700 ? 3 : 2;
    } catch (_) {
      return 3;
    }
  }

  // ✅ FIX: _executeSidebarNavItem mein 'Video Conference' case add kiya
  void _executeSidebarNavItem(String label) {
    // if (label == 'Logout') {
    //   _handleLogout();
    // } else
    if (label == 'Courses') {
      setState(() {
        _activeSidebarItem = 'Courses';
        _focusedSubjectIndex = 0;
        _sidebarFocused = false;
        _showLibrary    = false;
      });
    } else if (label == 'Exams') {
      setState(() => _activeSidebarItem = 'Exams');
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ExamListPage(
            loginData: widget.loginData,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ).then((_) {
        if (mounted) setState(() {
          _activeSidebarItem  = 'Courses';
          _sidebarNavIndex    = 0;
          _sidebarFocused     = false;
        });
      });
    } else if (label == 'Video Conference') {
      // ✅ FIX: LectureSchedulePage pe navigate karo
      setState(() => _activeSidebarItem = 'Video Conference');
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LectureSchedulePage(
            loginData: widget.loginData,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ).then((_) {
        if (mounted) setState(() {
          _activeSidebarItem  = 'Courses';
          _sidebarNavIndex    = 0;
          _sidebarFocused     = false;
        });
      });
    } else if (label == 'Library') {
      final regId = widget.loginData['reg_id']?.toString() ?? '';
      final permissions = widget.loginData['permissions']?.toString() ?? 'Student';
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => LibraryPage(
          regId: regId,
          permissions: permissions,
          loginData: widget.loginData,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ));
    } else if (label == 'Boards') {
      _openBoards();

    } else if (label == 'Tools') {
      _openTools();
    } else {
      // Other items — sidebar mein active mark karo
      setState(() => _activeSidebarItem = label);
    }
  }

  void _openTools() {
    setState(() => _activeSidebarItem = 'Tools');
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ToolsPage(loginData: widget.loginData),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      if (mounted) setState(() {
        _activeSidebarItem  = 'Courses';
        _sidebarNavIndex    = 0;
        _sidebarFocused     = false;
      });
    });
  }

  // void _openWhiteboard() {
  //   setState(() => _activeSidebarItem = 'White Board');
  //   Navigator.push(
  //     context,
  //     PageRouteBuilder(
  //       pageBuilder: (_, __, ___) => const WhiteboardPage(),
  //       transitionsBuilder: (_, anim, __, child) =>
  //           FadeTransition(opacity: anim, child: child),
  //       transitionDuration: const Duration(milliseconds: 300),
  //     ),
  //   );
  // }

  void _openBoards() {
    setState(() => _activeSidebarItem = 'Boards');
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => BoardsPage(loginData: widget.loginData),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      if (mounted) setState(() {
        _activeSidebarItem  = 'Courses';
        _sidebarNavIndex    = 0;
        _sidebarFocused     = false;
      });
    });
  }

  // ── White Board open karo ────────────────────────────────────

  // ── Library inline open ────────────────────────────────────
  void _openLibrary() {
    setState(() {
      _activeSidebarItem = 'Library';
      _showLibrary       = true;
      _sidebarFocused    = false;
      _libFocusedIdx     = 0;
      _libCurrentPage    = 0;
      _libFocusOnMore    = false;
    });
    _loadLibraryBooks();
  }

  void _closeLibrary() {
    setState(() {
      _showLibrary       = false;
      _activeSidebarItem = 'Courses';
      _sidebarNavIndex   = 0;
      _sidebarFocused    = false;
    });
  }

  Future<void> _loadLibraryBooks() async {
    setState(() { _libLoading = true; _libError = null; });
    try {
      final regId      = widget.loginData['reg_id']?.toString() ??
          widget.loginData['reg_id_k12']?.toString() ?? '';
      final permissions = widget.loginData['permissions']?.toString() ?? 'School';
      final books = await ApiService.getLibraryBooks(
        regId: regId, permissions: permissions,
      );
      setState(() {
        _libBooks    = books;
        _libFiltered = books;
        _libLoading  = false;
        _libFocusedIdx  = 0;
        _libCurrentPage = 0;
        _libFocusOnMore = false;
      });
      _fadeController.reset(); _fadeController.forward();
    } catch (e) {
      setState(() { _libError = 'Books load nahi hue.'; _libLoading = false; });
    }
  }

  void _applyLibSearch(String q) {
    setState(() {
      _libSearchQuery = q;
      _libFiltered = q.trim().isEmpty ? _libBooks : _libBooks.where((b) {
        final n = (b['book_name'] ?? '').toString().toLowerCase();
        final a = (b['author_name'] ?? '').toString().toLowerCase();
        return n.contains(q.toLowerCase()) || a.contains(q.toLowerCase());
      }).toList();
      _libCurrentPage = 0; _libFocusedIdx = 0; _libFocusOnMore = false;
    });
  }

  List<dynamic> get _libPageBooks {
    final s = _libCurrentPage * _libPageSize;
    final e = (s + _libPageSize).clamp(0, _libFiltered.length);
    if (s >= _libFiltered.length) return [];
    return _libFiltered.sublist(s, e);
  }
  bool get _libHasNext => (_libCurrentPage + 1) * _libPageSize < _libFiltered.length;

  void _openBook(dynamic book) {
    final bookName = book['book_name']?.toString() ?? 'Book';
    final bookDoc  = book['book_doc']?.toString()  ?? '';
    if (bookDoc.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF available nahi hai.'), backgroundColor: Colors.orange));
      return;
    }
    final chapterMap = {
      'id': book['id']?.toString() ?? '0', 'sub_topic': bookName,
      'topic_docs': bookDoc, 'video_links': '', 'book_name': bookName,
      'book_image': book['book_image']?.toString() ?? '',
    };
    final allBooks = _libFiltered.map<Map<String,dynamic>>((b) => {
      'id': b['id']?.toString() ?? '0', 'sub_topic': b['book_name']?.toString() ?? 'Book',
      'topic_docs': b['book_doc']?.toString() ?? '', 'video_links': '',
    }).toList();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => ContentOptionsPage(
        chapter: chapterMap, subject: 'Library', grade: 0,
        medium: '', courseId: null, allChapters: allBooks,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ));
  }

  void _openChapters(int idx) {
    // Navigate to TopicPage (alag page) — Image 3 ka 3-panel layout
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TopicPage(
          topics: topics,
          initialSubjectIndex: idx,
          grade: widget.grade,
          medium: _activeMedium,
          courseId: selectedCourseId,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Color _subjectColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('math') || n.contains('गणित')) return const Color(0xFF3B82F6);
    if (n.contains('science') || n.contains('विज्ञान')) return const Color(0xFF059669);
    if (n.contains('geography') || n.contains('भूगोल')) return const Color(0xFF10B981);
    if (n.contains('history') || n.contains('इतिहास')) return const Color(0xFFF59E0B);
    if (n.contains('english') || n.contains('अंग्रेजी')) return const Color(0xFF8B5CF6);
    if (n.contains('hindi') || n.contains('हिंदी')) return const Color(0xFFDC2626);
    if (n.contains('odia') || n.contains('ଓଡ଼ିଆ')) return const Color(0xFF059669);
    if (n.contains('social') || n.contains('सामाजिक')) return const Color(0xFFEF4444);
    if (n.contains('computer') || n.contains('programming')) return const Color(0xFF6366F1);
    return _activeAccentColor;
  }


  // ── Loading state ────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [_activeAccentColor, _activeAccentColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: _activeAccentColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
                const Icon(Icons.auto_stories_rounded, size: 28, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading Subjects',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preparing your curriculum...',
            style: TextStyle(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF8B949E), Color(0xFF6B7280)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.book_outlined, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Subjects Found',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'No subjects available for this course.\nPlease try again later.',
            style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  // ── Library inline panel ────────────────────────────────────
  Widget _buildLibraryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            children: [
              const Text('Library Collection',
                  style: TextStyle(color: Color(0xFFBF360C),
                      fontSize: 40, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_libSearchActive)
                Expanded(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0C00),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBF360C), width: 2),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search, color: Color(0xFFBF360C), size: 22),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: _libSearchCtrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        cursorColor: const Color(0xFFBF360C),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _applyLibSearch,
                      )),
                      GestureDetector(
                        onTap: () {
                          setState(() { _libSearchActive = false; _libSearchQuery = ''; });
                          _libSearchCtrl.clear();
                          _applyLibSearch('');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.close, color: Color(0xFFBF360C), size: 22),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => setState(() => _libSearchActive = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0C00),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFBF360C).withOpacity(0.5), width: 1.5),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search, color: Color(0xFFBF360C), size: 24),
                      SizedBox(width: 8),
                      Text('Search', style: TextStyle(color: Color(0xFFBF360C),
                          fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        // Triangle arrow
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: CustomPaint(size: const Size(26, 18), painter: _TriangleUpPainter()),
        ),
        // Books grid
        if (_libLoading)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: Color(0xFFBF360C))))
        else if (_libError != null)
          Expanded(child: Center(child: Text(_libError!,
              style: const TextStyle(color: Colors.red, fontSize: 16))))
        else if (_libFiltered.isEmpty)
            const Expanded(child: Center(child: Text('No books found',
                style: TextStyle(color: Colors.white70, fontSize: 20))))
          else
            _buildLibGrid(),
      ],
    );
  }

  Widget _buildLibGrid() {
    final pageBks   = _libPageBooks;
    final pageStart = _libCurrentPage * _libPageSize;
    final leftCount  = (pageBks.length / 2).ceil();
    final rightCount = pageBks.length - leftCount;
    const tubeW = 11.0; const tubeOffset = 10.0;
    const rowGap = 10.0; const buffer = 20.0; const moreH = 80.0;

    return Expanded(
      child: LayoutBuilder(builder: (ctx, constraints) {
        final availH  = constraints.maxHeight;
        final usableH = _libHasNext ? availH - moreH - 16 : availH;
        final rowH    = leftCount > 0
            ? ((usableH - buffer) / leftCount - rowGap).clamp(48.0, 120.0)
            : 70.0;
        final colH = (leftCount * (rowH + rowGap)).clamp(0.0, usableH);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _libColWidget(
                    List.generate(leftCount, (i) => _libBookRow(pageStart + i, rowH)),
                    colH, tubeW, tubeOffset)),
                const SizedBox(width: 30),
                Expanded(child: _libColWidget(
                    List.generate(rightCount,
                            (i) => _libBookRow(pageStart + leftCount + i, rowH)),
                    colH, tubeW, tubeOffset)),
              ]),
            )),
            if (_libHasNext)
              SizedBox(height: moreH, child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 20, 14),
                child: Align(alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _libCurrentPage++;
                      _libFocusedIdx  = _libCurrentPage * _libPageSize;
                      _libFocusOnMore = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _libFocusOnMore
                            ? Colors.white.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _libFocusOnMore ? Colors.white54 : Colors.transparent,
                            width: 1.5),
                      ),
                      child: Text('More...', style: TextStyle(
                          color: _libFocusOnMore
                              ? const Color(0xFFBF360C) : Colors.white,
                          fontSize: 28, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              )),
          ]),
        );
      }),
    );
  }

  Widget _libColWidget(List<Widget> rows, double h, double tubeW, double tubeOffset) {
    return SizedBox(height: h, child: Stack(children: [
      Positioned(left: tubeOffset, top: 0, bottom: 0,
          child: Container(width: tubeW, decoration: BoxDecoration(
              color: Colors.black87, borderRadius: BorderRadius.circular(6)))),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    ]));
  }

  Widget _libBookRow(int globalIdx, double rowH) {
    if (globalIdx >= _libFiltered.length) return SizedBox(height: rowH + 10);
    final book      = _libFiltered[globalIdx];
    final isFocused = !_sidebarFocused && globalIdx == _libFocusedIdx;
    final bookName  = book['book_name']?.toString()  ?? 'Unknown';
    final author    = book['author_name']?.toString() ?? '';
    final hasDoc    = (book['book_doc']?.toString()  ?? '').isNotEmpty;
    final displayNum = (globalIdx + 1).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () {
        setState(() { _libFocusedIdx = globalIdx; _sidebarFocused = false; });
        _openBook(book);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: rowH,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isFocused ? const Color(0xFFFFF8F5) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: isFocused
              ? Border.all(color: const Color(0xFFBF360C), width: 2)
              : Border.all(color: const Color(0xFFE8D5CC), width: 1),
          boxShadow: isFocused
              ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.25),
              blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 46, child: Text(displayNum, style: TextStyle(
                color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                fontSize: 26, fontWeight: FontWeight.w700))),
            Expanded(child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bookName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                        fontSize: 24,
                        fontWeight: isFocused ? FontWeight.w700 : FontWeight.w600)),
                if (author.isNotEmpty)
                  Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF8B5E52), fontSize: 14)),
              ],
            )),
            if (hasDoc)
              Icon(Icons.picture_as_pdf_rounded,
                  color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000).withOpacity(0.4),
                  size: 22),
          ]),
        ),
      ),
    );
  }

  // ── Left sidebar — Image 2 exact, full height top to bottom ─
  Widget _buildSidebar() {
    // Responsive sidebar width: chhoti screen pe 160, badi pe 200
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 600 ? 180.0 : 240.0;

    return Stack(
      children: [
        Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0800), Color(0xFF3A1200)],
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 16,
                offset: Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Logo box top ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth < 600 ? 8 : 14,
                  screenWidth < 600 ? 8 : 14,
                  screenWidth < 600 ? 8 : 14,
                  10,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: screenWidth < 600 ? 6 : 10,
                      horizontal: screenWidth < 600 ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBF360C).withOpacity(0.3), width: 1.5),
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
                            color: const Color(0xFFBF7060),
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

              // ── Nav items — evenly fill all remaining height ──────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _navItems.asMap().entries.map((entry) {
                      final navIdx = entry.key;
                      final label  = entry.value;
                      final isActive   = label == _activeSidebarItem;
                      final isTvFocus  = _sidebarFocused &&
                          _sidebarZone == 'nav' &&
                          navIdx == _sidebarNavIndex;
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
                            color: isTvFocus
                                ? Colors.white.withOpacity(0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isTvFocus
                                  ? Colors.white38
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isTvFocus ? 12 : 10,
                                height: isTvFocus ? 12 : 10,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFFBF360C)
                                      : isTvFocus
                                      ? Colors.white
                                      : Colors.white60,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: screenWidth < 600 ? 6 : 12),
                              Expanded(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFFBF360C)
                                        : isTvFocus
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: screenWidth < 600
                                        ? (isTvFocus ? 14 : 13)
                                        : (isTvFocus ? 20 : 19),
                                    fontWeight: (isActive || isTvFocus)
                                        ? FontWeight.w700
                                        : FontWeight.w400,
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

              // Powered by section removed
            ],
          ),
        ),
        // ── Right side vertical border line ─────────────────────
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

  // ── Top header bar — Image 2 exact ───────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF6D00)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // CLASS/MEDIUM — left
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CLASS — ${_toRoman(widget.grade)}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('MEDIUM — ${_activeMedium.split(' ')[0]}',
                  style: const TextStyle(color: Color(0xFFFFD0B0), fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          // Right: title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text("Let's Get Started!",
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('Select your Subject',
                  style: TextStyle(color: Color(0xFFFFE0B2), fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Subject icon helper ─────────────────────────────────────
  IconData _getCardIcon(String subject) {
    final n = subject.toLowerCase();
    if (n.contains('math') || n.contains('\u0917\u0923\u093f\u0924')) return Icons.calculate_rounded;
    if (n.contains('science') || n.contains('\u0935\u093f\u091c\u094d\u091e\u093e\u0928')) return Icons.science_rounded;
    if (n.contains('social') || n.contains('\u0938\u093e\u092e\u093e\u091c\u093f\u0915')) return Icons.people_alt_rounded;
    if (n.contains('hindi') || n.contains('\u0939\u093f\u0902\u0926\u0940')) return Icons.translate_rounded;
    if (n.contains('english') || n.contains('\u0905\u0902\u0917\u094d\u0930\u0947\u091c\u0940')) return Icons.menu_book_rounded;
    if (n.contains('sanskrit')) return Icons.auto_stories_rounded;
    if (n.contains('history') || n.contains('\u0907\u0924\u093f\u0939\u093e\u0938')) return Icons.history_edu_rounded;
    if (n.contains('geography') || n.contains('\u092d\u0942\u0917\u094b\u0932')) return Icons.public_rounded;
    if (n.contains('computer')) return Icons.computer_rounded;
    return Icons.book_rounded;
  }

  // ── Subject grid — epathshala inspired card design ──────────
  Widget _buildSubjectGrid(Size screenSize) {
    final double sidebarWidth = screenSize.width < 600 ? 180.0 : 240.0;
    final double gridWidth = screenSize.width - sidebarWidth;
    int cols = gridWidth >= 700 ? 3 : 2;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 416 / 262,
        ),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final subject     = topics[index];
          final subjectName = subject['subject'].toString();
          final isFocused   = !_sidebarFocused && index == _focusedSubjectIndex;
          final icon        = _getCardIcon(subjectName);

          return GestureDetector(
            onTap: () {
              setState(() {
                _sidebarFocused = false;
                _focusedSubjectIndex = index;
              });
              _openChapters(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : const Color(0xFFFFF3EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused
                      ? const Color(0xFFBF360C)
                      : const Color(0xFFD4A090),
                  width: isFocused ? 5.0 : 1.5,
                ),
                boxShadow: isFocused
                    ? [
                  BoxShadow(
                    color: const Color(0xFFBF360C).withOpacity(0.6),
                    blurRadius: 28,
                    spreadRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [
                  const BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: isFocused ? Colors.white : const Color(0xFFFFF3EE),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        subjectName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isFocused
                              ? const Color(0xFFBF360C)
                              : const Color(0xFF5A2000),
                          fontSize: isFocused ? 24 : 22,
                          fontWeight: isFocused ? FontWeight.w900 : FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Main build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar: full height, top to bottom
              _buildSidebar(),

              // Right panel: header + content (or Library)
              Expanded(
                child: _showLibrary
                    ? _buildLibraryPanel()
                    : Container(
                  color: const Color(0xFF1A0800),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: isLoading
                            ? _buildLoadingState()
                            : topics.isEmpty
                            ? _buildEmptyState()
                            : _buildSubjectGrid(screenSize),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Triangle up-arrow painter (also used in TopicPage) ──────────
// Added as a standalone class — does NOT affect anything else.
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