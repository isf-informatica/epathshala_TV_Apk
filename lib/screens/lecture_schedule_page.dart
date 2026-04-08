import 'package:flutter/material.dart';
import 'exam_list_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'library_page.dart';
import 'boards_page.dart';
import 'tools_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LectureSchedulePage
// Exam page jaisi sidebar + header layout
// Middle: Calendar
// Bottom: Selected day ki schedule list
// Top-right: + Add button
// ─────────────────────────────────────────────────────────────────────────────

enum _CalendarView { month, week, day, list }

class LectureSchedulePage extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const LectureSchedulePage({Key? key, required this.loginData})
      : super(key: key);

  @override
  State<LectureSchedulePage> createState() => _LectureSchedulePageState();
}

class _LectureSchedulePageState extends State<LectureSchedulePage>
    with TickerProviderStateMixin {
  static const String _baseUrl = 'https://k12.easylearn.org.in';

  // Calendar state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  // Schedule data
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String? _errorMsg;

  // Dropdown data for Add Schedule
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _mentors = [];

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // View mode (month / week / day / list)
  _CalendarView _calendarView = _CalendarView.month;

  // TV sidebar state (same as exam page)
  bool _sidebarFocused = true;  // sidebar se start karo
  int _sidebarNavIndex = 2; // 'Video Conference' = index 2
  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards', 'Tools', 'Logout',
  ];

  // ── Date format helpers ───────────────────────────────────────────────────
  static const List<String> _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  String _fmtDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtMonthYear(DateTime d) => '${_monthNames[d.month]} ${d.year}';

  String _fmtFullDate(DateTime d) {
    final dow = _dayNames[d.weekday - 1];
    return '$dow, ${d.day} ${_monthNames[d.month]} ${d.year}';
  }

  // ── Permission helpers ────────────────────────────────────────────────────
  String get _permissions =>
      widget.loginData['permissions']?.toString() ?? 'Student';
  String get _regId => widget.loginData['reg_id']?.toString() ?? '';
  String get _accountId =>
      (widget.loginData['id'] ?? widget.loginData['user_id'] ?? '').toString();
  String get _classroomId =>
      (widget.loginData['classroom_id'] ?? 0).toString();

  bool get _canAddSchedule =>
      ['School', 'Jr College', 'College', 'Classroom', 'Mentor', 'Admin', 'Student']
          .contains(_permissions); // TODO: Remove 'Student' in production

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadSchedules();
    if (_canAddSchedule) _loadDropdownData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── API: Load schedules ───────────────────────────────────────────────────
  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Easylearn/Classroom_Controller/load_schedule'),
        body: {
          'permissions': _permissions,
          'reg_id': _regId,
          'classroom_id': _classroomId,
          'id': _accountId,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<')) {
          setState(() {
            _isLoading = false;
            _schedules = [];
            _errorMsg = null;
          });
          return;
        }
        final data = json.decode(response.body);
        if (data['Response'] == 'OK' && data['data'] is List) {
          setState(() {
            _schedules =
                List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
          _fadeCtrl.reset();
          _fadeCtrl.forward();
          return;
        }
      }
      setState(() {
        _isLoading = false;
        _schedules = [];
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Failed to load: $e';
      });
    }
  }

  // ── API: Load dropdown data ───────────────────────────────────────────────
  Future<void> _loadDropdownData() async {
    try {
      final batchRes = await http.post(
        Uri.parse(
            '$_baseUrl/Easylearn/Classroom_Controller/get_batches'),
        body: {
          'permissions': _permissions,
          'reg_id': _regId,
          'classroom_id': _classroomId,
        },
      ).timeout(const Duration(seconds: 10));
      if (batchRes.statusCode == 200) {
        final d = json.decode(batchRes.body);
        debugPrint('[Schedule] batch response: ${batchRes.body}');
        if (d['Response'] == 'OK' && d['data'] is List) {
          final list = List<Map<String, dynamic>>.from(d['data']);
          // Normalize: ensure 'batch_name' key exists (some APIs use 'name')
          final normalized = list.map((item) {
            if (item['batch_name'] == null && item['name'] != null) {
              return {...item, 'batch_name': item['name']};
            }
            return item;
          }).toList();
          setState(() => _batches = normalized);
        }
      }

      final mentorRes = await http.post(
        Uri.parse(
            '$_baseUrl/Easylearn/Classroom_Controller/get_all_mentors'),
        body: {'reg_id': _regId},
      ).timeout(const Duration(seconds: 10));
      if (mentorRes.statusCode == 200) {
        final d = json.decode(mentorRes.body);
        debugPrint('[Schedule] mentor response: ${mentorRes.body}');
        if (d['Response'] == 'OK' && d['data'] is List) {
          setState(() =>
              _mentors = List<Map<String, dynamic>>.from(d['data']));
        }
      }
    } catch (e) {
      debugPrint('[Schedule] dropdown load error: $e');
    }
  }

  // ── API: Delete ───────────────────────────────────────────────────────────
  Future<bool> _deleteSchedule(String id) async {
    try {
      final res = await http.post(
        Uri.parse(
            '$_baseUrl/Easylearn/Classroom_Controller/remove_schedule'),
        body: {'id': id},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['status'] == 200;
      }
    } catch (e) {
      debugPrint('[Schedule] delete error: $e');
    }
    return false;
  }

  // ── API: Save ─────────────────────────────────────────────────────────────
  Future<bool> _saveSchedule(Map<String, String> formData) async {
    try {
      final res = await http.post(
        Uri.parse(
            '$_baseUrl/Easylearn/Classroom_Controller/add_schedule_mobile'),
        body: {
          'account_id': _accountId,
          'reg_id': _regId,
          ...formData,
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['status'] == 200;
      }
    } catch (e) {
      debugPrint('[Schedule] save error: $e');
    }
    return false;
  }

  // ── API: Edit ─────────────────────────────────────────────────────────────
  Future<bool> _editSchedule(String id, Map<String, String> formData) async {
    try {
      final res = await http.post(
        Uri.parse(
            '$_baseUrl/Easylearn/Classroom_Controller/edit_schedule'),
        body: {
          'id': id,
          'edit_schedule_token': 'bypass_mobile',
          ...formData,
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['status'] == 200;
      }
    } catch (e) {
      debugPrint('[Schedule] edit error: $e');
    }
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _schedulesForDay(DateTime day) {
    final dayStr = _fmtDate(day);
    return _schedules.where((s) {
      final sd = s['start_date']?.toString() ?? '';
      return sd == dayStr || sd.startsWith(dayStr);
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedDaySchedules =>
      _selectedDay != null ? _schedulesForDay(_selectedDay!) : [];

  Color _classColor(String? className) {
    switch ((className ?? '').toLowerCase()) {
      case 'green':
        return const Color(0xFF10B981);
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      case 'purple':
        return const Color(0xFF8B5CF6);
      case 'teal':
        return const Color(0xFF14B8A6);
      case 'pink':
        return const Color(0xFFEC4899);
      case 'orange':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      final parts = t.split(':');
      int h = int.parse(parts[0]);
      final m = parts.length > 1 ? parts[1] : '00';
      final ampm = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return '$h:$m $ampm';
    } catch (_) {
      return t;
    }
  }

  // ── TV key navigation ─────────────────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_sidebarFocused) {
        _executeSidebarItem(_navItems[_sidebarNavIndex]);
      } else if (_calendarView == _CalendarView.month && _selectedDay != null) {
        // Enter pe selected day ki schedule show karo (already showing below)
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (!_sidebarFocused) {
        setState(() => _sidebarFocused = true);
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_sidebarFocused) {
        // Calendar se sidebar pe jao
        setState(() => _sidebarFocused = true);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) {
        // Sidebar se calendar pe jao
        setState(() => _sidebarFocused = false);
      } else if (_calendarView == _CalendarView.month) {
        // Calendar mein right — next day
        setState(() {
          final base = _selectedDay ?? DateTime.now();
          _selectedDay = base.add(const Duration(days: 1));
          if (_selectedDay!.month != _focusedMonth.month ||
              _selectedDay!.year  != _focusedMonth.year) {
            _focusedMonth = DateTime(_selectedDay!.year, _selectedDay!.month);
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex > 0) setState(() => _sidebarNavIndex--);
      } else if (_calendarView == _CalendarView.month) {
        setState(() {
          final base = _selectedDay ?? DateTime.now();
          _selectedDay = base.subtract(const Duration(days: 7));
          if (_selectedDay!.month != _focusedMonth.month ||
              _selectedDay!.year  != _focusedMonth.year) {
            _focusedMonth = DateTime(_selectedDay!.year, _selectedDay!.month);
          }
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) {
        if (_sidebarNavIndex < _navItems.length - 1) setState(() => _sidebarNavIndex++);
      } else if (_calendarView == _CalendarView.month) {
        setState(() {
          final base = _selectedDay ?? DateTime.now();
          _selectedDay = base.add(const Duration(days: 7));
          if (_selectedDay!.month != _focusedMonth.month ||
              _selectedDay!.year  != _focusedMonth.year) {
            _focusedMonth = DateTime(_selectedDay!.year, _selectedDay!.month);
          }
        });
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _executeSidebarItem(String label) {
    switch (label) {
      case 'Video Conference':
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

  // ── Modals ────────────────────────────────────────────────────────────────
  void _showAddScheduleModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddScheduleDialog(
        batches: _batches,
        mentors: _mentors,
        loginData: widget.loginData,
        onSave: (formData) async {
          Navigator.pop(ctx);
          final ok = await _saveSchedule(formData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? '✅ Schedule added!' : '❌ Failed to add'),
              backgroundColor:
                  ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ));
            if (ok) _loadSchedules();
          }
        },
      ),
    );
  }

  void _showEditScheduleModal(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditScheduleDialog(
        schedule: schedule,
        canEdit: _canAddSchedule,
        onSave: (id, formData) async {
          Navigator.pop(ctx);
          final ok = await _editSchedule(id, formData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  ok ? '✅ Schedule updated!' : '❌ Update failed'),
              backgroundColor:
                  ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ));
            if (ok) _loadSchedules();
          }
        },
        onDelete: (id) async {
          Navigator.pop(ctx);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF1A2E55),
              title: const Text('Delete Schedule',
                  style: TextStyle(color: Colors.white)),
              content: const Text('Are you sure?',
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            final ok = await _deleteSchedule(id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(ok ? '✅ Deleted!' : '❌ Delete failed'),
                backgroundColor:
                    ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ));
              if (ok) _loadSchedules();
            }
          }
        },
        onJoinMeet: (url) => _launchMeetUrl(url),
      ),
    );
  }

  Future<void> _launchMeetUrl(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No meeting URL available')));
      return;
    }

    // Fix domain: easylearn.org.in → k12.easylearn.org.in
    String fixedUrl = url
        .replaceAll('https://easylearn.org.in/', 'https://k12.easylearn.org.in/')
        .replaceAll('http://easylearn.org.in/',  'https://k12.easylearn.org.in/');
    if (!fixedUrl.startsWith('http')) {
      fixedUrl = 'https://k12.easylearn.org.in/$fixedUrl';
    }

    // APK mein WebView page pe navigate karo (camera/mic support ke liye)
    if (!kIsWeb) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoConferenceWebView(url: fixedUrl),
        ),
      );
      return;
    }

    // Web pe external tab mein kholo
    try {
      final uri = Uri.parse(fixedUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Cannot open: $fixedUrl')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD — Exam page jaisi full layout
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── LEFT SIDEBAR (exact exam page style) ──────────────
              _buildSidebar(screenSize),

              // ── RIGHT CONTENT ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(screenSize),
                    // Body
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sidebar — exam page jaisi exact copy (original style) ───────────────
  Widget _buildSidebar(Size screenSize) {
    final sidebarWidth = screenSize.width < 600 ? 180.0 : 240.0;
    return Stack(
      children: [
        Container(
          width: sidebarWidth,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1A3E),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
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
              // Logo box (original style)
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo_easylearn.png',
                          height: screenSize.width < 600 ? 36 : 50,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school,
                            color: const Color(0xFF1A3A7C),
                            size: screenSize.width < 600 ? 30 : 42,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EASY LEARN',
                          style: TextStyle(
                            color: const Color(0xFF1A3A7C),
                            fontSize: screenSize.width < 600 ? 9 : 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'EDUCATION FOR ALL',
                          style: TextStyle(
                            color: const Color(0xFF6B8AB5),
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
                      final isActive  = label == 'Video Conference';
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
                                      ? const Color(0xFFFFA600)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(
                                  width: screenSize.width < 600 ? 6 : 12),
                              Expanded(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFFFFA600)
                                        : Colors.white,
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
            ],
          ),
        ),

        // Right border line
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
                  Colors.white,
                  Color(0xFFCCCCCC),
                  Colors.white,
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

  // ── Header — exam page style (original) ──────────────────────────────────
  Widget _buildHeader(Size screenSize) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: const Color(0xFF0D1C45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back arrow
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Icon(Icons.arrow_back_ios,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          // Title
          const Text(
            'Video Conference',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // + Add button (top right)
          if (_canAddSchedule)
            GestureDetector(
              onTap: _showAddScheduleModal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4169E1).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '+ Add',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Refresh
          GestureDetector(
            onTap: _loadSchedules,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body: Calendar + Schedule list ───────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                    colors: [Color(0xFF4169E1), Color(0xFF1A3A7C)]),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4169E1).withOpacity(0.4),
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
                  const Icon(Icons.calendar_month_rounded,
                      size: 28, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Loading Schedule',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Preparing your schedule...',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF8B949E))),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 60),
            const SizedBox(height: 16),
            Text(_errorMsg!,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4169E1)),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── VIEW TABS (month / week / day / list) ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildViewTabs(),
          ),

          // ── CONTENT based on selected view ─────────────────────
          if (_calendarView == _CalendarView.month) ...[
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildCalendar(),
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildScheduleList(),
            ),
          ] else if (_calendarView == _CalendarView.week) ...[
            Expanded(child: _buildWeekView()),
          ] else if (_calendarView == _CalendarView.day) ...[
            Expanded(child: _buildDayView()),
          ] else ...[
            Expanded(child: _buildListView()),
          ],
        ],
      ),
    );
  }

  // ── View Tabs ─────────────────────────────────────────────────────────────
  Widget _buildViewTabs() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTv = screenWidth > 1200;
    final tabs = [
      (_CalendarView.month, 'month',  Icons.calendar_month_rounded),
      (_CalendarView.week,  'week',   Icons.view_week_rounded),
      (_CalendarView.day,   'day',    Icons.today_rounded),
      (_CalendarView.list,  'list',   Icons.format_list_bulleted_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF091530),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A3060), width: 1.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((t) {
          final isActive = _calendarView == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _calendarView = t.$1;
                if (t.$1 == _CalendarView.day) {
                  _selectedDay ??= DateTime.now();
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    vertical: isTv ? 12 : 9),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF3A5FD5), Color(0xFF5479F7)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4169E1).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      t.$3,
                      size: isTv ? 18 : 14,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF4B6080),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t.$2,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF4B6080),
                        fontSize: isTv ? 15 : 12,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Week View ─────────────────────────────────────────────────────────────
  Widget _buildWeekView() {
    // Find start of week (Sunday) for focused day or today
    final base = _selectedDay ?? DateTime.now();
    final startOfWeek = base.subtract(Duration(days: base.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    // Collect all events for this week
    final weekEvents = <DateTime, List<Map<String, dynamic>>>{};
    for (final d in weekDays) {
      weekEvents[d] = _schedulesForDay(d);
    }

    // Navigator header (prev/next week + "today")
    return Column(
      children: [
        // Week navigator
        _buildNavigatorBar(
          title: () {
            final s = weekDays.first;
            final e = weekDays.last;
            if (s.month == e.month) {
              return '${_monthNames[s.month]} ${s.year}';
            }
            return '${_monthNames[s.month]} – ${_monthNames[e.month]} ${e.year}';
          }(),
          onPrev: () => setState(() {
            _selectedDay = (base).subtract(const Duration(days: 7));
          }),
          onToday: () => setState(() {
            _selectedDay = DateTime.now();
          }),
          onNext: () => setState(() {
            _selectedDay = (base).add(const Duration(days: 7));
          }),
        ),

        // Week day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 44), // time gutter
              ...weekDays.map((d) {
                final isToday = DateUtils.isSameDay(d, DateTime.now());
                final isSelected = DateUtils.isSameDay(d, _selectedDay);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = d),
                    child: Column(
                      children: [
                        Text(
                          ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d.weekday % 7],
                          style: TextStyle(
                            color: isToday ? const Color(0xFFFFA600) : const Color(0xFF8B949E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4169E1)
                                : isToday
                                    ? const Color(0xFFFFA600).withOpacity(0.2)
                                    : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSelected
                                ? Border.all(color: const Color(0xFFFFA600), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                color: isSelected || isToday ? Colors.white : const Color(0xFF8B949E),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 4),
        const Divider(color: Color(0xFF1A2E55), height: 1),

        // Scrollable time grid
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List.generate(14, (hi) {
                  final hour = hi + 8; // 8 AM to 9 PM
                  final label = hour <= 12
                      ? '${hour}am'
                      : hour == 12
                          ? '12pm'
                          : '${hour - 12}pm';
                  return SizedBox(
                    height: 56,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(label,
                                style: const TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 10)),
                          ),
                        ),
                        ...weekDays.map((d) {
                          final dayEvts = (weekEvents[d] ?? []).where((s) {
                            final t = s['start_time']?.toString() ?? '';
                            if (t.isEmpty) return false;
                            final h = int.tryParse(t.split(':')[0]) ?? -1;
                            return h == hour;
                          }).toList();
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: const Color(0xFF1A2E55).withOpacity(0.5),
                                      width: 0.5),
                                ),
                              ),
                              child: Column(
                                children: dayEvts.map((s) {
                                  final color = _classColor(s['class_name']?.toString());
                                  final title = s['lecture_title']?.toString() ??
                                      s['title']?.toString() ?? 'Untitled';
                                  return GestureDetector(
                                    onTap: () => _showEditScheduleModal(s),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 1),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Day View ──────────────────────────────────────────────────────────────
  Widget _buildDayView() {
    final day = _selectedDay ?? DateTime.now();
    final dayEvts = _schedulesForDay(day);
    final dow = _dayNames[day.weekday - 1];

    return Column(
      children: [
        _buildNavigatorBar(
          title: '$dow, ${day.day} ${_monthNames[day.month]} ${day.year}',
          onPrev: () => setState(() => _selectedDay = day.subtract(const Duration(days: 1))),
          onToday: () => setState(() => _selectedDay = DateTime.now()),
          onNext: () => setState(() => _selectedDay = day.add(const Duration(days: 1))),
        ),
        const Divider(color: Color(0xFF1A2E55), height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List.generate(14, (hi) {
                  final hour = hi + 8;
                  final label = hour < 12
                      ? '${hour}am'
                      : hour == 12
                          ? '12pm'
                          : '${hour - 12}pm';
                  final hourEvts = dayEvts.where((s) {
                    final t = s['start_time']?.toString() ?? '';
                    if (t.isEmpty) return false;
                    final h = int.tryParse(t.split(':')[0]) ?? -1;
                    return h == hour;
                  }).toList();
                  return Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: const Color(0xFF1A2E55).withOpacity(0.5)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Text(label,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 11)),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: hourEvts.map((s) {
                                final color = _classColor(s['class_name']?.toString());
                                final title = s['lecture_title']?.toString() ??
                                    s['title']?.toString() ?? 'Untitled';
                                final startTime = _formatTime(s['start_time']?.toString());
                                final endTime = _formatTime(s['end_time']?.toString());
                                return GestureDetector(
                                  onTap: () => _showEditScheduleModal(s),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$startTime - $endTime',
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 11),
                                        ),
                                        Text(
                                          title,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── List View ─────────────────────────────────────────────────────────────
  Widget _buildListView() {
    // Group schedules by date, sorted
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _schedules) {
      final key = s['start_date']?.toString().substring(0, 10) ?? '';
      if (key.isNotEmpty) {
        grouped.putIfAbsent(key, () => []).add(s);
      }
    }
    final sortedKeys = grouped.keys.toList()..sort();

    // Filter to current month
    final monthStr =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
    final monthKeys = sortedKeys.where((k) => k.startsWith(monthStr)).toList();

    return Column(
      children: [
        _buildNavigatorBar(
          title: _fmtMonthYear(_focusedMonth),
          onPrev: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month - 1);
          }),
          onToday: () => setState(() {
            _focusedMonth = DateTime.now();
          }),
          onNext: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month + 1);
          }),
        ),
        const Divider(color: Color(0xFF1A2E55), height: 1),
        if (monthKeys.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No schedules this month',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 15),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: monthKeys.length,
              itemBuilder: (ctx, gi) {
                final dateKey = monthKeys[gi];
                final dayItems = grouped[dateKey]!;
                DateTime dateObj;
                try {
                  final parts = dateKey.split('-');
                  dateObj = DateTime(int.parse(parts[0]),
                      int.parse(parts[1]), int.parse(parts[2]));
                } catch (_) {
                  dateObj = DateTime.now();
                }
                final dow = _dayNames[dateObj.weekday - 1];
                final isToday = DateUtils.isSameDay(dateObj, DateTime.now());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header row
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFFFA600).withOpacity(0.15)
                            : const Color(0xFF0D1A3E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isToday
                                ? const Color(0xFFFFA600).withOpacity(0.5)
                                : const Color(0xFF1A2E55)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$dateKey',
                            style: TextStyle(
                                color: isToday
                                    ? const Color(0xFFFFA600)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            dow,
                            style: TextStyle(
                                color: isToday
                                    ? const Color(0xFFFFA600)
                                    : const Color(0xFF8B949E),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Events for that day
                    ...dayItems.map((s) {
                      final color =
                          _classColor(s['class_name']?.toString());
                      final title = s['lecture_title']?.toString() ??
                          s['title']?.toString() ?? 'Untitled';
                      final startTime =
                          _formatTime(s['start_time']?.toString());
                      final endTime =
                          _formatTime(s['end_time']?.toString());
                      final meetUrl = s['meet_url']?.toString() ?? '';
                      return GestureDetector(
                        onTap: () => _showEditScheduleModal(s),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$startTime – $endTime',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (meetUrl.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _launchMeetUrl(meetUrl),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.video_call_rounded,
                                            color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Join',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white54, size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Shared Navigator Bar (prev/today/next + title) ────────────────────────
  Widget _buildNavigatorBar({
    required String title,
    required VoidCallback onPrev,
    required VoidCallback onToday,
    required VoidCallback onNext,
  }) {
    final isTv = MediaQuery.of(context).size.width > 1200;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isTv ? 12 : 8, 16, isTv ? 12 : 8),
      child: Row(
        children: [
          // Prev
          GestureDetector(
            onTap: onPrev,
            child: Container(
              width:  isTv ? 44 : 36,
              height: isTv ? 44 : 36,
              decoration: BoxDecoration(
                color: const Color(0xFF091530),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1A3060)),
              ),
              child: Icon(Icons.chevron_left,
                  color: Colors.white54, size: isTv ? 24 : 18),
            ),
          ),
          const SizedBox(width: 8),
          // Today
          GestureDetector(
            onTap: onToday,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 18 : 12,
                  vertical:   isTv ? 11 : 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A3A7C), Color(0xFF2B4FA3)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF3A5FD5).withOpacity(0.5)),
              ),
              child: Text('today',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isTv ? 15 : 12,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          const SizedBox(width: 8),
          // Next
          GestureDetector(
            onTap: onNext,
            child: Container(
              width:  isTv ? 44 : 36,
              height: isTv ? 44 : 36,
              decoration: BoxDecoration(
                color: const Color(0xFF091530),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1A3060)),
              ),
              child: Icon(Icons.chevron_right,
                  color: Colors.white54, size: isTv ? 24 : 18),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTv ? 18 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar (Month View with event chips inside cells) ──────────────────
  Widget _buildCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(
        _focusedMonth.year, _focusedMonth.month);
    final firstDay =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    const double headerH = 44.0;
    const double labelH = 28.0;

    return LayoutBuilder(builder: (context, constraints) {
      // TV/large screen pe available height se cellH compute karo
      final totalRows = ((startWeekday + daysInMonth) / 7).ceil();
      final availableH = constraints.maxHeight - headerH - labelH;
      final cellH = (availableH / totalRows).clamp(52.0, 100.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2E55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigator
          SizedBox(
            height: headerH,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white70, size: 22),
                  onPressed: () => setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1);
                    _selectedDay = null;
                  }),
                ),
                Expanded(
                  child: Text(
                    _fmtMonthYear(_focusedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white70, size: 22),
                  onPressed: () => setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month + 1);
                    _selectedDay = null;
                  }),
                ),
              ],
            ),
          ),

          // Day labels (S M T W T F S)
          Container(
            height: labelH,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1A2E55)),
                bottom: BorderSide(color: Color(0xFF1A2E55)),
              ),
            ),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Date grid with event chips
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
                mainAxisExtent: cellH,
              ),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < startWeekday) {
                  // Empty cell before month start
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF1A2E55).withOpacity(0.4),
                          width: 0.5),
                    ),
                  );
                }
                final day = index - startWeekday + 1;
                final date = DateTime(
                    _focusedMonth.year, _focusedMonth.month, day);
                final dayEvents = _schedulesForDay(date);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                final isSelected = DateUtils.isSameDay(date, _selectedDay);

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay =
                        DateUtils.isSameDay(date, _selectedDay)
                            ? null
                            : date);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4169E1).withOpacity(0.25)
                          : isToday
                              ? const Color(0xFFFFA600).withOpacity(0.08)
                              : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4169E1)
                            : isToday
                                ? const Color(0xFFFFA600).withOpacity(0.5)
                                : const Color(0xFF1A2E55).withOpacity(0.4),
                        width: isSelected || isToday ? 1.5 : 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date number top-right
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4169E1)
                                  : isToday
                                      ? const Color(0xFFFFA600)
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: isSelected || isToday
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Event chips (max 2, then "+N more")
                        if (dayEvents.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...dayEvents.take(2).map((s) {
                                    final color = _classColor(
                                        s['class_name']?.toString());
                                    final title = s['lecture_title']
                                            ?.toString() ??
                                        s['title']?.toString() ??
                                        'Untitled';
                                    final startTime = _formatTime(
                                        s['start_time']?.toString());
                                    // Short time e.g. "12:45p"
                                    String shortTime = '';
                                    try {
                                      final parts = (s['start_time']
                                                  ?.toString() ??
                                              '')
                                          .split(':');
                                      int h = int.parse(parts[0]);
                                      final m = parts.length > 1
                                          ? parts[1]
                                          : '00';
                                      final ampm = h >= 12 ? 'p' : 'a';
                                      if (h > 12) h -= 12;
                                      if (h == 0) h = 12;
                                      shortTime = '$h:${m}$ampm';
                                    } catch (_) {
                                      shortTime = startTime;
                                    }
                                    return LayoutBuilder(
                                      builder: (ctx, bc) {
                                        // Cell width se font size compute karo
                                        final chipFontSize = (bc.maxWidth / 9).clamp(7.0, 11.0);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 1),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 3, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            '$shortTime $title',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: chipFontSize,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }
                                    );
                                  }),
                                  if (dayEvents.length > 2)
                                    Text(
                                      '+${dayEvents.length - 2} more',
                                      style: const TextStyle(
                                        color: Color(0xFF8B949E),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    }); // end LayoutBuilder
  }

  // ── Schedule list (bottom section) ───────────────────────────────────────
  Widget _buildScheduleList() {
    final screenWidth  = MediaQuery.of(context).size.width;
    final isTv  = screenWidth > 1200;
    final isTab = screenWidth > 600;

    // No day selected
    if (_selectedDay == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF091530),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1A3060), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isTv ? 70 : 54,
                height: isTv ? 70 : 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.touch_app_rounded,
                    color: const Color(0xFF4169E1).withOpacity(0.5),
                    size: isTv ? 36 : 28),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a date to view schedule',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: isTv ? 18 : isTab ? 15 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final daySchedules = _selectedDaySchedules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: EdgeInsets.symmetric(
              horizontal: isTv ? 20 : 14,
              vertical:   isTv ? 12 : 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2050), Color(0xFF091A40)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1A3060)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: isTv ? 28 : 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5479F7), Color(0xFF3A5FD5)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _fmtFullDate(_selectedDay!),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTv ? 18 : isTab ? 15 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isTv ? 14 : 10,
                    vertical:   isTv ? 6 : 4),
                decoration: BoxDecoration(
                  gradient: daySchedules.isEmpty
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF3A5FD5), Color(0xFF5479F7)],
                        ),
                  color: daySchedules.isEmpty
                      ? const Color(0xFF1A3060)
                      : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${daySchedules.length} class${daySchedules.length != 1 ? 'es' : ''}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTv ? 14 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cards list
        Expanded(
          child: daySchedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isTv ? 70 : 54,
                        height: isTv ? 70 : 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_busy_rounded,
                            color: Colors.white.withOpacity(0.25),
                            size: isTv ? 36 : 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No classes scheduled',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: isTv ? 18 : 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_canAddSchedule) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _showAddScheduleModal,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isTv ? 28 : 20,
                                vertical:   isTv ? 14 : 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3A5FD5), Color(0xFF5479F7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4169E1)
                                      .withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline_rounded,
                                    color: Colors.white, size: isTv ? 22 : 16),
                                SizedBox(width: isTv ? 10 : 6),
                                Text('Add Schedule',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isTv ? 16 : 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: daySchedules.length,
                  itemBuilder: (ctx, i) {
                    final s = daySchedules[i];
                    final color = _classColor(s['class_name']?.toString());
                    final title = s['lecture_title']?.toString() ??
                        s['title']?.toString() ?? 'Untitled';
                    final startTime = _formatTime(s['start_time']?.toString());
                    final endTime   = _formatTime(s['end_time']?.toString());
                    final mentor = s['mentor_name']?.toString() ??
                        s['teacher']?.toString() ?? '';
                    final batch   = s['batch_name']?.toString() ?? '';
                    final meetUrl = s['meet_url']?.toString() ?? '';

                    return GestureDetector(
                      onTap: () => _showEditScheduleModal(s),
                      child: Container(
                        margin: EdgeInsets.only(bottom: isTv ? 14 : 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF091530),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF1A3060), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Color accent left bar
                            Container(
                              width: isTv ? 8 : 6,
                              height: isTv ? 90 : 76,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            SizedBox(width: isTv ? 18 : 14),

                            // Time block
                            Container(
                              width: isTv ? 90 : 72,
                              padding: EdgeInsets.symmetric(
                                  vertical: isTv ? 10 : 8,
                                  horizontal: isTv ? 8 : 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withOpacity(0.3)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    startTime,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: isTv ? 14 : 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 3),
                                    color: color.withOpacity(0.3),
                                  ),
                                  Text(
                                    endTime,
                                    style: TextStyle(
                                      color: color.withOpacity(0.7),
                                      fontSize: isTv ? 13 : 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: isTv ? 16 : 12),

                            // Main info
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: isTv ? 14 : 10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isTv ? 18 : isTab ? 15 : 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: isTv ? 6 : 4),
                                    if (mentor.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.person_rounded,
                                              color: Colors.white38,
                                              size: isTv ? 16 : 13),
                                          const SizedBox(width: 4),
                                          Text(mentor,
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: isTv ? 14 : 11,
                                              )),
                                        ],
                                      ),
                                    if (batch.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.group_rounded,
                                              color: Colors.white38,
                                              size: isTv ? 16 : 13),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(batch,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: isTv ? 13 : 11,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Right: join + chevron
                            Padding(
                              padding: EdgeInsets.only(right: isTv ? 16 : 12),
                              child: Row(
                                children: [
                                  if (meetUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _launchMeetUrl(meetUrl),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: isTv ? 16 : 12,
                                            vertical:   isTv ? 10 : 7),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0EA877),
                                              Color(0xFF14B8A6),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF14B8A6)
                                                  .withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.video_call_rounded,
                                                color: Colors.white,
                                                size: isTv ? 20 : 15),
                                            SizedBox(width: isTv ? 6 : 4),
                                            Text('Join',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: isTv ? 15 : 12,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  SizedBox(width: isTv ? 10 : 8),
                                  Icon(Icons.chevron_right_rounded,
                                      color: Colors.white24,
                                      size: isTv ? 26 : 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddScheduleDialog
// ─────────────────────────────────────────────────────────────────────────────
class _AddScheduleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  final List<Map<String, dynamic>> mentors;
  final Map<String, dynamic> loginData;
  final Future<void> Function(Map<String, String>) onSave;

  const _AddScheduleDialog({
    required this.batches,
    required this.mentors,
    required this.loginData,
    required this.onSave,
  });

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  final _titleCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _meetCtrl = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _batchId;
  String? _mentorId;
  String _color = 'Green';
  bool _isSaving = false;

  static const List<String> _colorOptions = [
    'Green', 'Blue', 'Red', 'Yellow', 'Purple', 'Teal', 'Pink', 'Orange'
  ];

  Color _colorSwatch(String c) {
    switch (c.toLowerCase()) {
      case 'green':  return const Color(0xFF10B981);
      case 'blue':   return const Color(0xFF3B82F6);
      case 'red':    return const Color(0xFFEF4444);
      case 'yellow': return const Color(0xFFF59E0B);
      case 'purple': return const Color(0xFF8B5CF6);
      case 'teal':   return const Color(0xFF14B8A6);
      case 'pink':   return const Color(0xFFEC4899);
      case 'orange': return const Color(0xFFF97316);
      default:       return const Color(0xFF10B981);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4169E1),
              surface: Color(0xFF0D1A3E)),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      _dateCtrl.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4169E1),
              surface: Color(0xFF0D1A3E)),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() {
        if (isStart) _startTime = t;
        else _endTime = t;
      });
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _dateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and Date are required')));
      return;
    }
    setState(() => _isSaving = true);
    await widget.onSave({
      'lecture_title': _titleCtrl.text.trim(),
      'start_date':    _dateCtrl.text,
      'start_time':    _startTime != null ? _fmtTime(_startTime!) : '',
      'end_time':      _endTime   != null ? _fmtTime(_endTime!)   : '',
      'batch_id':      _batchId   ?? '',
      'mentor_id':     _mentorId  ?? '',
      'class_name':    _color,
      'meet_url':      _meetCtrl.text.trim(),
    });
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _meetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1A2E55)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF4169E1),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Add Schedule',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildField('Lecture Title',
                        ctrl: _titleCtrl,
                        hint: 'Enter lecture title'),
                    const SizedBox(height: 14),
                    _buildDateField(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTimePick(
                                'Start Time', _startTime,
                                () => _pickTime(true))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTimePick(
                                'End Time', _endTime,
                                () => _pickTime(false))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildColorDrop(),
                    const SizedBox(height: 14),
                    _buildField('Meet URL',
                        ctrl: _meetCtrl,
                        hint: 'https://meet.google.com/...'),
                    // ── Batch dropdown — hamesha dikhao
                    const SizedBox(height: 14),
                    widget.batches.isNotEmpty
                        ? _buildDropdown(
                            'Batch',
                            widget.batches,
                            'batch_name',
                            _batchId,
                            (v) => setState(() => _batchId = v),
                          )
                        : _buildEmptyDropdownHint('Batch', 'No batches found'),
                    // ── Mentor dropdown — hamesha dikhao
                    const SizedBox(height: 14),
                    widget.mentors.isNotEmpty
                        ? _buildDropdown(
                            'Mentor',
                            widget.mentors,
                            'name',
                            _mentorId,
                            (v) => setState(() => _mentorId = v),
                          )
                        : _buildEmptyDropdownHint('Mentor', 'No mentors found'),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFF1A2E55)))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(
                            color: Color(0xFF374151)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Schedule',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label,
      {required TextEditingController ctrl, String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF30363D)),
            filled: true,
            fillColor: const Color(0xFF0D1C45),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4169E1))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lecture Date',
            style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _dateCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF4169E1), size: 18),
                filled: true,
                fillColor: const Color(0xFF0D1C45),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A2E55))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A2E55))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePick(String label, TimeOfDay? t, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1C45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1A2E55)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t != null
                        ? '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? "AM" : "PM"}'
                        : 'Choose time',
                    style: TextStyle(
                        color: t != null
                            ? Colors.white
                            : const Color(0xFF30363D),
                        fontSize: 14),
                  ),
                ),
                const Icon(Icons.access_time_rounded,
                    color: Color(0xFF4169E1), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color',
            style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _color,
          dropdownColor: const Color(0xFF0D1A3E),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D1C45),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          items: _colorOptions
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _colorSwatch(c),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(c),
                    ]),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _color = v ?? 'Green'),
        ),
      ],
    );
  }

  Widget _buildDropdown(
      String label,
      List<Map<String, dynamic>> items,
      String nameKey,
      String? value,
      ValueChanged<String?> onChanged) {
    // Safe: filter items that actually have a non-empty name
    final validItems = items
        .where((item) => (item[nameKey]?.toString() ?? '').isNotEmpty)
        .toList();

    // If selected value not in list, reset to null to avoid assertion error
    final safeValue = validItems.any((i) => i['id']?.toString() == value)
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          dropdownColor: const Color(0xFF0D1A3E),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          hint: Text('Select $label',
              style: const TextStyle(color: Color(0xFF8B949E))),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D1C45),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          items: validItems
              .map((item) => DropdownMenuItem<String>(
                    value: item['id']?.toString() ?? '',
                    child: Text(
                        item[nameKey]?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Jab list empty ho tab placeholder dikhao
  Widget _buildEmptyDropdownHint(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1C45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1A2E55)),
          ),
          child: Text(hint,
              style: const TextStyle(
                  color: Color(0xFF4B6080), fontSize: 14)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditScheduleDialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditScheduleDialog extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final bool canEdit;
  final Future<void> Function(String id, Map<String, String>) onSave;
  final Future<void> Function(String id) onDelete;
  final void Function(String url) onJoinMeet;

  const _EditScheduleDialog({
    required this.schedule,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
    required this.onJoinMeet,
  });

  @override
  State<_EditScheduleDialog> createState() => _EditScheduleDialogState();
}

class _EditScheduleDialogState extends State<_EditScheduleDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _meetCtrl;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _color = 'Green';
  bool _isSaving = false;

  static const List<String> _colorOptions = [
    'Green', 'Blue', 'Red', 'Yellow', 'Purple', 'Teal', 'Pink', 'Orange'
  ];

  Color _colorSwatch(String c) {
    switch (c.toLowerCase()) {
      case 'green':  return const Color(0xFF10B981);
      case 'blue':   return const Color(0xFF3B82F6);
      case 'red':    return const Color(0xFFEF4444);
      case 'yellow': return const Color(0xFFF59E0B);
      case 'purple': return const Color(0xFF8B5CF6);
      case 'teal':   return const Color(0xFF14B8A6);
      case 'pink':   return const Color(0xFFEC4899);
      case 'orange': return const Color(0xFFF97316);
      default:       return const Color(0xFF10B981);
    }
  }

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _titleCtrl = TextEditingController(
        text: s['lecture_title']?.toString() ??
            s['title']?.toString() ?? '');
    _dateCtrl = TextEditingController(
        text: s['start_date']?.toString() ?? '');
    _meetCtrl = TextEditingController(
        text: s['meet_url']?.toString() ?? '');
    _color = s['class_name']?.toString() ?? 'Green';

    // Parse times
    final st = s['start_time']?.toString() ?? '';
    final et = s['end_time']?.toString() ?? '';
    if (st.isNotEmpty) {
      final p = st.split(':');
      if (p.length >= 2) {
        _startTime = TimeOfDay(
            hour: int.tryParse(p[0]) ?? 0,
            minute: int.tryParse(p[1]) ?? 0);
      }
    }
    if (et.isNotEmpty) {
      final p = et.split(':');
      if (p.length >= 2) {
        _endTime = TimeOfDay(
            hour: int.tryParse(p[0]) ?? 0,
            minute: int.tryParse(p[1]) ?? 0);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _meetCtrl.dispose();
    super.dispose();
  }

  String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtTod(TimeOfDay? t) {
    if (t == null) return '';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Future<void> _pickDate() async {
    DateTime? init;
    try {
      final parts = _dateCtrl.text.split('-');
      if (parts.length == 3) {
        init = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
      }
    } catch (_) {}
    final d = await showDatePicker(
      context: context,
      initialDate: init ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4169E1),
              surface: Color(0xFF0D1A3E)),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      _dateCtrl.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4169E1),
              surface: Color(0xFF0D1A3E)),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() {
        if (isStart) _startTime = t;
        else _endTime = t;
      });
    }
  }

  Future<void> _submit() async {
    final id = widget.schedule['id']?.toString() ?? '';
    setState(() => _isSaving = true);
    await widget.onSave(id, {
      'lecture_title': _titleCtrl.text.trim(),
      'start_date':    _dateCtrl.text,
      'start_time':    _startTime != null ? _fmtTimeOfDay(_startTime!) : '',
      'end_time':      _endTime   != null ? _fmtTimeOfDay(_endTime!)   : '',
      'class_name':    _color,
      'meet_url':      _meetCtrl.text.trim(),
    });
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final meetUrl = widget.schedule['meet_url']?.toString() ?? '';
    final title = widget.schedule['lecture_title']?.toString() ??
        widget.schedule['title']?.toString() ?? 'Schedule';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1A2E55)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2E55),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (widget.canEdit) ...[
                      _buildField('Lecture Title', ctrl: _titleCtrl),
                      const SizedBox(height: 14),
                      _buildDateField(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTimePick('Start Time',
                                  _startTime, () => _pickTime(true))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildTimePick('End Time',
                                  _endTime, () => _pickTime(false))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildColorDrop(),
                      const SizedBox(height: 14),
                      _buildField('Meet URL', ctrl: _meetCtrl,
                          hint: 'https://meet.google.com/...'),
                    ] else ...[
                      // Read-only view
                      _infoRow('Title',
                          widget.schedule['lecture_title']?.toString() ?? ''),
                      _infoRow('Date',
                          widget.schedule['start_date']?.toString() ?? ''),
                      _infoRow('Time',
                          '${widget.schedule['start_time'] ?? ''} – ${widget.schedule['end_time'] ?? ''}'),
                      if (meetUrl.isNotEmpty)
                        _infoRow('Meet', meetUrl),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFF1A2E55)))),
              child: Row(
                children: [
                  _actionBtn(
                    icon: Icons.close,
                    label: 'Close',
                    color: const Color(0xFF374151),
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  if (meetUrl.isNotEmpty) ...[
                    _actionBtn(
                      icon: Icons.video_call_rounded,
                      label: 'Join Meet',
                      color: const Color(0xFF14B8A6),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onJoinMeet(meetUrl);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.canEdit) ...[
                    _actionBtn(
                      icon: Icons.save_rounded,
                      label: 'Save',
                      color: const Color(0xFF4169E1),
                      onTap: _submit,
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.delete_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onTap: () {
                        final id =
                            widget.schedule['id']?.toString() ?? '';
                        widget.onDelete(id);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildField(String label,
      {required TextEditingController ctrl, String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF30363D)),
            filled: true,
            fillColor: const Color(0xFF0D1C45),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4169E1))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lecture Date',
            style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextField(
              controller: _dateCtrl,
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF4169E1), size: 18),
                filled: true,
                fillColor: const Color(0xFF0D1C45),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A2E55))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A2E55))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePick(
      String label, TimeOfDay? t, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1C45),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFF1A2E55)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t != null ? _fmtTod(t) : 'Choose time',
                    style: TextStyle(
                        color: t != null
                            ? Colors.white
                            : const Color(0xFF30363D),
                        fontSize: 14),
                  ),
                ),
                const Icon(Icons.access_time_rounded,
                    color: Color(0xFF4169E1), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color',
            style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _colorOptions.contains(_color) ? _color : 'Green',
          dropdownColor: const Color(0xFF0D1A3E),
          style:
              const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D1C45),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1A2E55))),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          items: _colorOptions
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _colorSwatch(c),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(c),
                    ]),
                  ))
              .toList(),
          onChanged: (v) =>
              setState(() => _color = v ?? 'Green'),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// _VideoConferenceWebView
// APK mein video conference WebView mein kholta hai
// Camera + microphone support ke liye AndroidWebViewController use karta hai
// ─────────────────────────────────────────────────────────────────────────────
class _VideoConferenceWebView extends StatefulWidget {
  final String url;
  const _VideoConferenceWebView({required this.url});

  @override
  State<_VideoConferenceWebView> createState() =>
      _VideoConferenceWebViewState();
}

class _VideoConferenceWebViewState extends State<_VideoConferenceWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => _isLoading = true); },
        onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
        onWebResourceError: (_) { if (mounted) setState(() => _isLoading = false); },
      ))
      ..loadRequest(Uri.parse(widget.url));

    // Android: camera + mic permission enable karo
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidCtrl = _controller.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      androidCtrl.setOnPlatformPermissionRequest(
        (request) => request.grant(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFF0D1C45),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFFA600)),
                      SizedBox(height: 16),
                      Text('Joining meeting...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            // Back button
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Back',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}