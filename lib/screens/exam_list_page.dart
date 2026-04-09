// screens/exam_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'exam_detail_page.dart';
import 'lecture_schedule_page.dart';
import 'library_page.dart';
import 'boards_page.dart';
import 'tools_page.dart';

// ── Data model ───────────────────────────────────────────────────
class ExamItem {
  final String id;
  final String uniqueId;
  final String examTitle;
  final String examDuration;
  final String examCategory;
  final int questions;

  const ExamItem({
    required this.id,
    required this.uniqueId,
    required this.examTitle,
    required this.examDuration,
    required this.examCategory,
    required this.questions,
  });

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      id:           json['id']?.toString() ?? '',
      uniqueId:     json['unique_id']?.toString() ?? '',
      examTitle:    json['exam_title']?.toString() ?? 'Untitled Exam',
      examDuration: json['exam_duration']?.toString() ?? '0',
      examCategory: json['exam_category']?.toString() ?? '',
      questions:    int.tryParse(json['questions']?.toString() ?? '0') ?? 0,
    );
  }
}

class EnrolledCourse {
  final String uniqueId;
  final String courseName;
  final String courseImage;

  const EnrolledCourse({
    required this.uniqueId,
    required this.courseName,
    required this.courseImage,
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    return EnrolledCourse(
      uniqueId:    json['unique_id']?.toString() ?? '',
      courseName:  json['course_name']?.toString() ?? '',
      courseImage: json['course_image']?.toString() ?? '',
    );
  }
}

// ── Main ExamListPage ────────────────────────────────────────────
class ExamListPage extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const ExamListPage({Key? key, required this.loginData}) : super(key: key);

  @override
  _ExamListPageState createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage>
    with TickerProviderStateMixin {
  static const String _baseUrl = 'https://k12.easylearn.org.in/Easylearn';

  // ── State ──────────────────────────────────────────────────────
  List<EnrolledCourse> _courses = [];
  List<ExamItem> _exams = [];
  bool _loadingCourses = true;
  bool _loadingExams = false;
  EnrolledCourse? _selectedCourse;
  int _selectedCourseIndex = 0;
  int _focusedExamIndex = 0;
  int _focusedCourseIndex = 0; // separate from exam index
  String _errorMessage = '';

  // TV sidebar state
  bool _sidebarFocused = false;
  int _sidebarNavIndex = 1; // 'Exams' default selected
  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards', 'Tools', 'Logout',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fetchEnrolledCourses();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────────────────────
  Future<void> _fetchEnrolledCourses() async {
    setState(() { _loadingCourses = true; _errorMessage = ''; });
    try {
      final userId      = widget.loginData['id']?.toString() ?? '';
      final classroomId = widget.loginData['classroom_id']?.toString() ?? '';
      final regId       = widget.loginData['reg_id']?.toString() ?? '';

      final response = await http.post(
        Uri.parse('$_baseUrl/Course_Controller/enrolledcourse_details_getdata'),
        body: {
          'id':           userId,
          'classroom_id': classroomId,
          'reg_id':       regId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dataArray = data['data'] as List<dynamic>? ?? [];
        final courses = dataArray.map((e) => EnrolledCourse.fromJson(e)).toList();
        setState(() {
          _courses = courses;
          _loadingCourses = false;
        });
            // Courses fetch hone ke baad cards dikhao (auto-select nahi)
        _fadeController.reset();
        _fadeController.forward();
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _loadingCourses = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check connection.';
        _loadingCourses = false;
      });
    }
  }

  void _selectCourse(EnrolledCourse course, int idx) {
    setState(() {
      _selectedCourse = course;
      _selectedCourseIndex = idx;
      _focusedExamIndex = 0;
    });
    _fetchExamsForCourse(course.uniqueId);
  }

  Future<void> _fetchExamsForCourse(String uniqueId) async {
    setState(() { _loadingExams = true; _exams = []; _errorMessage = ''; });
    try {
      final userId      = widget.loginData['id']?.toString() ?? '';
      final classroomId = widget.loginData['classroom_id']?.toString() ?? '';
      final regId       = widget.loginData['reg_id']?.toString() ?? '';
      final permissions = widget.loginData['permissions']?.toString() ?? '';

      final response = await http.post(
        Uri.parse('$_baseUrl/Exam_Controller/exam_list'),
        body: {
          'id':           userId,
          'classroom_id': classroomId,
          'reg_id':       regId,
          'permissions':  permissions,
          'unique_id':    uniqueId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as int? ?? 0;
        if (status == 200 && data['data'] != null) {
          final dataArray = data['data'] as List<dynamic>;
          final exams = dataArray.map((e) => ExamItem.fromJson(e)).toList();
          setState(() {
            _exams = exams;
            _loadingExams = false;
            _focusedExamIndex = 0;
          });
          _fadeController.reset();
          _fadeController.forward();
        } else {
          setState(() {
            _exams = [];
            _loadingExams = false;
            _errorMessage = 'No exams found for this course.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error loading exams.';
          _loadingExams = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check connection.';
        _loadingExams = false;
      });
    }
  }

  String _formatDuration(String duration) {
    try {
      final mins = int.parse(duration);
      if (mins < 60) return '$mins min';
      final hrs = mins ~/ 60;
      final rem = mins % 60;
      return rem == 0 ? '$hrs hr' : '$hrs hr : $rem min';
    } catch (_) {
      return duration;
    }
  }

  // ── TV Remote navigation ──────────────────────────────────────
  // Grid cols for exam cards
  int get _gridCols {
    try {
      final w = MediaQuery.of(context).size.width;
      const sidebarW = 240.0;
      return (w - sidebarW) >= 700 ? 3 : 2;
    } catch (_) { return 3; }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ── ENTER / OK ───────────────────────────────────────────────
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_sidebarFocused) {
        _executeSidebarItem(_navItems[_sidebarNavIndex]);
      } else if (_selectedCourse == null) {
        // Course view: selected course pe navigate karo
        if (_courses.isNotEmpty) {
          final course = _courses[_focusedCourseIndex];
          _selectCourse(course, _focusedCourseIndex);
        }
      } else {
        // Exam view: selected exam start karo
        if (_exams.isNotEmpty) _startExam(_exams[_focusedExamIndex]);
      }
      return KeyEventResult.handled;
    }

    // ── BACK / ESC ───────────────────────────────────────────────
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (!_sidebarFocused && _selectedCourse != null) {
        // Exam list se wapas course list pe jao
        setState(() {
          _selectedCourse = null;
          _exams = [];
          _focusedExamIndex = 0;
        });
        _fadeController.reset();
        _fadeController.forward();
      } else if (!_sidebarFocused) {
        setState(() => _sidebarFocused = true);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    // ── ARROW LEFT ───────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_sidebarFocused) return KeyEventResult.handled;
      if (_selectedCourse == null) {
        // Course view
        final cols = _gridCols;
        if (_focusedCourseIndex % cols == 0) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedCourseIndex =
              (_focusedCourseIndex - 1).clamp(0, _courses.length - 1));
        }
      } else {
        // Exam view
        final cols = _gridCols;
        if (_focusedExamIndex % cols == 0) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedExamIndex =
              (_focusedExamIndex - 1).clamp(0, _exams.length - 1));
        }
      }
      return KeyEventResult.handled;
    }

    // ── ARROW RIGHT ──────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        setState(() => _sidebarFocused = false);
      } else if (_selectedCourse == null) {
        setState(() => _focusedCourseIndex =
            (_focusedCourseIndex + 1).clamp(0, _courses.length - 1));
      } else {
        setState(() => _focusedExamIndex =
            (_focusedExamIndex + 1).clamp(0, _exams.length - 1));
      }
      return KeyEventResult.handled;
    }

    // ── ARROW UP ─────────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex > 0) setState(() => _sidebarNavIndex--);
      } else if (_selectedCourse == null) {
        final cols = _gridCols;
        if (_focusedCourseIndex < cols) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedCourseIndex =
              (_focusedCourseIndex - cols).clamp(0, _courses.length - 1));
        }
      } else {
        final cols = _gridCols;
        if (_focusedExamIndex < cols) {
          setState(() => _sidebarFocused = true);
        } else {
          setState(() => _focusedExamIndex =
              (_focusedExamIndex - cols).clamp(0, _exams.length - 1));
        }
      }
      return KeyEventResult.handled;
    }

    // ── ARROW DOWN ───────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex < _navItems.length - 1) setState(() => _sidebarNavIndex++);
      } else if (_selectedCourse == null) {
        final cols = _gridCols;
        setState(() => _focusedCourseIndex =
            (_focusedCourseIndex + cols).clamp(0, _courses.length - 1));
      } else {
        final cols = _gridCols;
        setState(() => _focusedExamIndex =
            (_focusedExamIndex + cols).clamp(0, _exams.length - 1));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _executeSidebarItem(String label) {
    switch (label) {
      case 'Exams':
        // Already here
        break;
      case 'Courses':
        Navigator.maybePop(context);
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

  void _startExam(ExamItem exam) {
    final studentId   = int.tryParse(widget.loginData['id']?.toString() ?? '') ?? -1;
    final classroomId = int.tryParse(widget.loginData['classroom_id']?.toString() ?? '') ?? -1;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExamDetailPage(
          examId:         int.tryParse(exam.id) ?? -1,
          examUniqueId:   exam.uniqueId,
          studentId:      studentId,
          classroomId:    classroomId,
          examTitle:      exam.examTitle,
          examCategory:   exam.examCategory,
          examDuration:   exam.examDuration,
          questionsCount: exam.questions,
          uniqueIdString: exam.uniqueId,
          loginData:      widget.loginData,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
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
              _buildSidebar(screenSize),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(screenSize),
                    // TV hint bar removed
                    Expanded(child: _buildBody(screenSize)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sidebar — subjects page exact copy ───────────────────────
  Widget _buildSidebar(Size screenSize) {
    final sidebarWidth = screenSize.width < 600 ? 180.0 : 240.0;
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
        boxShadow: [
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
          // Logo box
          Padding(
            padding: EdgeInsets.fromLTRB(
              screenSize.width < 600 ? 8 : 14,
              screenSize.width < 600 ? 8 : 14,
              screenSize.width < 600 ? 8 : 14,
              10,
            ),
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: screenSize.width < 600 ? 6 : 10,
                  horizontal: screenSize.width < 600 ? 6 : 10,
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
                      height: screenSize.width < 600 ? 36 : 50,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.school,
                        color: const Color(0xFFBF360C),
                        size: screenSize.width < 600 ? 30 : 42,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EASY LEARN',
                      style: TextStyle(
                        color: const Color(0xFFBF360C),
                        fontSize: screenSize.width < 600 ? 9 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'EDUCATION FOR ALL',
                      style: TextStyle(
                        color: const Color(0xFFBF7060),
                        fontSize: screenSize.width < 600 ? 6 : 7.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _navItems.asMap().entries.map((entry) {
                  final navIdx  = entry.key;
                  final label   = entry.value;
                  final isActive = label == 'Exams';
                  final isTvFocus = _sidebarFocused && navIdx == _sidebarNavIndex;
                  return GestureDetector(
                    onTap: () => _executeSidebarItem(label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width < 600 ? 10 : 20,
                        vertical: isTvFocus ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isTvFocus
                            ? Colors.white.withOpacity(0.10)
                            : Colors.transparent,
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
                              color: isActive
                                  ? const Color(0xFFBF360C)
                                  : Colors.white60,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: screenSize.width < 600 ? 6 : 12),
                          Expanded(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFFBF360C)
                                    : Colors.white70,
                                fontSize: screenSize.width < 600
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


  Widget _tvHint(String key, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF3A1200),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFE64A19), width: 1),
        ),
        child: Text(key, style: const TextStyle(
            color: Color(0xFFFF8A50), fontSize: 10, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]);
  }

  // ── Header — subjects page style ─────────────────────────────
  Widget _buildHeader(Size screenSize) {
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
          GestureDetector(
            onTap: () {
              if (_selectedCourse != null) {
                // Exam list se wapas course cards pe jao
                setState(() {
                  _selectedCourse = null;
                  _exams = [];
                  _focusedExamIndex = 0;
                });
                _fadeController.reset();
                _fadeController.forward();
              } else {
                Navigator.maybePop(context);
              }
            },
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXAMS',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              if (_selectedCourse != null)
                Text(
                  _selectedCourse!.courseName,
                  style: const TextStyle(
                      color: Color(0xFFFFD0B0), fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Let's Get Started!",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                  _selectedCourse == null ? 'Select your Course' : 'Select your Exam',
                  style: const TextStyle(
                      color: Color(0xFFFFE0B2), fontSize: 17,
                      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Course cards grid — subjects page exact style ───────────
  Widget _buildCourseCards(Size screenSize) {
    final sidebarW = screenSize.width < 600 ? 180.0 : 240.0;
    final gridWidth = screenSize.width - sidebarW;
    final cols = gridWidth >= 700 ? 3 : 2;

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
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          final isFocused = !_sidebarFocused && (_selectedCourse == null ? index == _focusedCourseIndex : false);

          return GestureDetector(
            onTap: () {
              setState(() {
                _sidebarFocused = false;
                _focusedExamIndex = index;
              });
              _selectCourse(course, index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused
                      ? const Color(0xFFBF360C)
                      : const Color(0xFFE8D5CC),
                  width: isFocused ? 3.5 : 1.5,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(
                        color: const Color(0xFFBF360C).withOpacity(0.45),
                        blurRadius: 24, spreadRadius: 3, offset: const Offset(0, 4),
                      )]
                    : [const BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10, offset: Offset(0, 4),
                      )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.5),
                child: Container(
                  color: const Color(0xFFFFF8F5),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        course.courseName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isFocused
                              ? const Color(0xFFBF360C)
                              : const Color(0xFF3E1000),
                          fontSize: 22,
                          fontWeight: isFocused ? FontWeight.w800 : FontWeight.w700,
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

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody(Size screenSize) {
    // Courses select nahi hua → course cards dikhao
    if (!_loadingCourses && _selectedCourse == null && _courses.isNotEmpty) {
      return _buildCourseCards(screenSize);
    }

    if (_loadingCourses || _loadingExams) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFFBF360C), Color(0xFFE64A19)],
                ),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBF360C).withOpacity(0.4),
                    blurRadius: 16, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  const Icon(Icons.assignment_rounded, size: 28, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Loading Exams',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3E1000))),
            const SizedBox(height: 8),
            const Text('Preparing your exams...',
                style: TextStyle(fontSize: 14, color: Color(0xFF8B5E50))),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty && _exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined,
                color: Color(0xFFBF7060), size: 60),
            const SizedBox(height: 20),
            Text(_errorMessage,
                style: const TextStyle(color: Color(0xFF7A4030), fontSize: 16),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_exams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, color: Color(0xFF8B949E), size: 60),
            SizedBox(height: 20),
            Text('No Exams Available',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(height: 8),
            Text('No exams available for this course.\nPlease try again later.',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF8B949E), height: 1.4),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // ── Exam cards grid — subjects page exact design ──────────
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridCols,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 416 / 262,
        ),
        itemCount: _exams.length,
        itemBuilder: (context, index) {
          final exam = _exams[index];
          final isFocused = !_sidebarFocused && index == _focusedExamIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _sidebarFocused = false;
                _focusedExamIndex = index;
              });
              _startExam(exam);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused
                      ? const Color(0xFFBF360C)
                      : const Color(0xFFE8D5CC),
                  width: isFocused ? 3.5 : 1.5,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(
                        color: const Color(0xFFBF360C).withOpacity(0.45),
                        blurRadius: 24, spreadRadius: 3, offset: const Offset(0, 4),
                      )]
                    : [const BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10, offset: Offset(0, 4),
                      )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.5),
                child: Container(
                  color: const Color(0xFFFFF8F5),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 44),
                          child: Text(
                            exam.examTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFocused
                                  ? const Color(0xFFBF360C)
                                  : const Color(0xFF3E1000),
                              fontSize: 20,
                              fontWeight: isFocused ? FontWeight.w800 : FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? const Color(0xFFBF360C).withOpacity(0.08)
                                : const Color(0xFFEEE0D8),
                            border: Border(
                              top: BorderSide(
                                color: isFocused
                                    ? const Color(0xFFBF360C).withOpacity(0.3)
                                    : const Color(0xFFDDC8BC),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              _miniChip(Icons.help_outline_rounded,
                                  '${exam.questions} Qs', const Color(0xFF8B5E50)),
                              const SizedBox(width: 8),
                              _miniChip(Icons.timer_outlined,
                                  _formatDuration(exam.examDuration), const Color(0xFF8B5E50)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? const Color(0xFFBF360C)
                                      : const Color(0xFFE64A19).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Start',
                                  style: TextStyle(
                                    color: isFocused ? Colors.white : const Color(0xFFBF360C),
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}