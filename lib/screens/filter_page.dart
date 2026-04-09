import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'grades_page.dart';
import 'subjects_page.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/profile_storage.dart';

class FilterPage extends StatefulWidget {
  final String? defaultCountry;
  final Map<String, dynamic> profile;

  const FilterPage({
    Key? key,
    required this.profile,
    this.defaultCountry = 'India',
  }) : super(key: key);

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> with TickerProviderStateMixin {
  // ── Step tracking ──────────────────────────────────────────────
  int _currentStep = 0;

  // ── Selections ─────────────────────────────────────────────────
  String? selectedCountry;
  String? selectedBoard;
  String? selectedBoardOption;
  String? selectedPartner;
  String? selectedState;
  List<String> selectedGrades  = [];
  List<String> selectedMediums = [];

  bool showBoardFilter   = true;
  bool showStateFilter   = true;
  bool showGradeFilter   = true;
  bool showMediumFilter  = true;
  bool isLoadingPartners = false;

  List<String> contentPartners = [];
  Map<String, Map<String, String>> boardPartnerMapping = {};
  List<String> boardPartnerOptions = [];
  final List<String> baseBoards = ['CBSE'];

  final List<String> states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal',
  ];

  late AnimationController _stepAnim;
  late Animation<Offset>   _slideIn;
  late Animation<double>   _fadeIn;

  // ── TV Remote Focus State ──────────────────────────────────────
  int  _tvFocusedItemIndex = 0;
  bool _nextButtonFocused  = false;
  bool _backButtonFocused  = false;

  // ── Scroll controllers for TV remote auto-scroll ──────────────
  final List<String> allGrades = [
    'Nursery','1','2','3','4','5','6','7','8','9','10','11','12',
  ];
  // ── Steps config ───────────────────────────────────────────────
  List<Map<String, dynamic>> get _steps {
    final s = <Map<String, dynamic>>[];
    if (showBoardFilter)  s.add({'key': 'board',    'label': 'Board',    'icon': Icons.account_balance_rounded});
    if (showStateFilter)  s.add({'key': 'state',    'label': 'State',    'icon': Icons.location_on_rounded});
    if (showGradeFilter)  s.add({'key': 'classes',  'label': 'Classes',  'icon': Icons.grade_rounded});
    if (showMediumFilter) s.add({'key': 'language', 'label': 'Language', 'icon': Icons.language_rounded});
    return s;
  }

  bool get _currentStepDone {
    final key = _steps[_currentStep]['key'];
    if (key == 'board')    return selectedBoard != null && selectedPartner != null;
    if (key == 'state')    return selectedState != null;
    if (key == 'classes')  return selectedGrades.isNotEmpty;
    if (key == 'language') return selectedMediums.isNotEmpty;
    return false;
  }

  bool get _isLastStep => _currentStep == _steps.length - 1;

  // ── Lifecycle ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    selectedCountry = widget.defaultCountry ?? 'India';
    _stepAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideIn = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _stepAnim, curve: Curves.easeOutCubic));
    _fadeIn = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut));
    _stepAnim.forward();
    _loadContentPartners();
  }

  @override
  void dispose() {
    _stepAnim.dispose();
    super.dispose();
  }

  // ── Step helpers ───────────────────────────────────────────────
  void _animateStep() {
    _stepAnim.reset();
    _stepAnim.forward();
  }

  void _goNext() {
    if (_isLastStep) {
      _applyFilter();
    } else {
      setState(() {
        _currentStep++;
        _tvFocusedItemIndex = 0;
        _nextButtonFocused  = false;
        _backButtonFocused  = false;
      });
      _animateStep();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _tvFocusedItemIndex = 0;
        _nextButtonFocused  = false;
        _backButtonFocused  = false;
      });
      _animateStep();
    }
  }

  List<String> getAvailableMediums() {
    if (selectedState == 'Odisha') {
      return ['Hindi', 'Odia', 'English'];
    }
    return ['Hindi', 'English'];
  }

  Future<void> _loadContentPartners() async {
    setState(() => isLoadingPartners = true);
    try {
      final partners = await ApiService.getContentPartners();
      setState(() {
        contentPartners = partners;
        _createBoardPartnerOptions();
        isLoadingPartners = false;
      });
    } catch (e) {
      setState(() => isLoadingPartners = false);
    }
  }

  void _createBoardPartnerOptions() {
    boardPartnerMapping.clear();
    boardPartnerOptions.clear();
    for (String board in baseBoards) {
      for (int i = 0; i < contentPartners.length; i++) {
        final option = '$board - Option ${i + 1}';
        boardPartnerOptions.add(option);
        boardPartnerMapping[option] = {'board': board, 'partner': contentPartners[i]};
      }
    }
  }

  void _onBoardOptionChanged(String? boardOption) {
    setState(() {
      selectedBoardOption = boardOption;
      if (boardOption != null && boardPartnerMapping.containsKey(boardOption)) {
        selectedBoard   = boardPartnerMapping[boardOption]!['board'];
        selectedPartner = boardPartnerMapping[boardOption]!['partner'];
      } else {
        selectedBoard   = null;
        selectedPartner = null;
      }
    });
  }

  void _onStateChanged(String? state) {
    setState(() {
      selectedState = state;
      selectedMediums.clear();
    });
  }

  // ── Selection handlers ─────────────────────────────────────────
  void _onGradeToggled(String grade) {
    setState(() {
      selectedGrades = selectedGrades.contains(grade) ? [] : [grade];
    });
  }

  void _onMediumToggled(String medium) {
    setState(() {
      selectedMediums = selectedMediums.contains(medium) ? [] : [medium];
    });
  }

  bool _canApplyFilter() {
    final boardValid  = !showBoardFilter  || (selectedBoard != null && selectedPartner != null);
    final stateValid  = !showStateFilter  || selectedState != null;
    final gradeValid  = !showGradeFilter  || selectedGrades.isNotEmpty;
    final mediumValid = !showMediumFilter || selectedMediums.isNotEmpty;
    return boardValid && stateValid && gradeValid && mediumValid;
  }

  Future<void> _applyFilter() async {
    if (!_canApplyFilter()) return;
    try {
      // ── Filter data locally save karo ───────────────────────────
      final filterData = {
        'selectedBoard':       selectedBoard,
        'selectedPartner':     selectedPartner,
        'selectedState':       selectedState,
        'selectedBoardOption': selectedBoardOption,
        'selectedGrades':      selectedGrades,
        'selectedMediums':     selectedMediums,
      };
      await ProfileStorage.saveFilters(
        (widget.profile['id'] ?? widget.profile['email'] ?? '').toString(),
        filterData,
      );

      final email    = (widget.profile['email']    ?? '').toString();
      final password = (widget.profile['password'] ?? '').toString();
      final name     = (widget.profile['name']     ?? '').toString();
      final avatar   = (widget.profile['avatar']   ?? '????').toString();
      final grade    = selectedGrades.isNotEmpty  ? selectedGrades.first  : '6';
      final medium   = selectedMediums.isNotEmpty ? selectedMediums.first : 'English';

      // DEBUG: profile map mein kya aa raha hai
      print('[FilterPage] profile keys: \${widget.profile.keys.toList()}');
      print('[FilterPage] email=$email password_length=\${password.length} name=$name');

      bool success = false;
      Map<String, dynamic>? savedProfile;

      // ── NEW: Single-step registerAndSetup API call ───────────────
      // email + password el_app_users mein + el_user_profiles mein
      // grade, state, medium, partner sab ek saath save hoga
      if (email.isNotEmpty) { // password optional — email kaafi hai
        savedProfile = await ApiService.registerAndSetup(
          email:   email,
          password: password,
          name:    name,
          avatar:  avatar,
          grades:  selectedGrades.isNotEmpty ? selectedGrades : [grade],
          medium:  medium,
          partner: selectedPartner ?? '',
          state:   selectedState   ?? '',
        );
        success = savedProfile != null;
        print('[FilterPage] registerAndSetup → success=$success profile=${savedProfile?['id']}');
      } else {
        // Fallback: email/password nahi hai (old flow) — complete_profile_setup use karo
        final profileId = (widget.profile['id'] ?? '').toString();
        final deviceId  = await ApiService.getDeviceId();
        final gradeForApi = grade == 'Nursery' ? '0' : grade;

        String? resolvedProfileId = profileId.isNotEmpty ? profileId : null;
        if (resolvedProfileId == null && (email.isNotEmpty || deviceId.isNotEmpty)) {
          try {
            final lookupRes = await http.post(
              Uri.parse('https://k12.easylearn.org.in/Easylearn/Course_Controller/get_profile_id_by_email_or_device'),
              body: {
                if (email.isNotEmpty)    'email'    : email,
                if (deviceId.isNotEmpty) 'device_id': deviceId,
              },
            );
            final lookupData = jsonDecode(lookupRes.body);
            if (lookupData['Response'] == 'OK' && lookupData['data'] != null) {
              resolvedProfileId = lookupData['data']['id']?.toString();
            }
          } catch (_) {}
        }

        try {
          final res = await http.post(
            Uri.parse('https://k12.easylearn.org.in/Easylearn/Course_Controller/complete_profile_setup'),
            body: {
              if (resolvedProfileId != null && resolvedProfileId.isNotEmpty)
                'profile_id': resolvedProfileId,
              if (email.isNotEmpty)    'email'    : email,
              if (deviceId.isNotEmpty) 'device_id': deviceId,
              'grade'  : gradeForApi,
              'grades' : jsonEncode(selectedGrades.map((g) => g == 'Nursery' ? '0' : g).toList()),
              'medium' : medium,
              if (selectedPartner != null && selectedPartner!.isNotEmpty) 'partner': selectedPartner!,
              if (selectedState   != null && selectedState!.isNotEmpty)   'state'  : selectedState!,
            },
          );
          print('[FilterPage] complete_profile_setup fallback → profile_id=$resolvedProfileId');
          print('[FilterPage] Response: ${res.body}');
          final data = jsonDecode(res.body);
          success = data['Response'] == 'OK';
        } catch (e) {
          print('[FilterPage] Fallback API error: $e');
          success = false;
        }
      }

      if (!mounted) return;

      if (success) {
        // savedProfile available hai (registerAndSetup se) ya widget.profile use karo
        final updatedProfile = savedProfile ?? Map<String, dynamic>.from(widget.profile);
        updatedProfile['has_completed_setup'] = 1;
        updatedProfile['is_active'] = 1;
        updatedProfile['grade']  = grade;
        updatedProfile['medium'] = medium;

        await ProfileStorage.updateProfileInCache(updatedProfile);
        await ProfileStorage.setActiveProfile(
          (widget.profile['id'] ?? widget.profile['email'] ?? '').toString(),
        );

        if (!mounted) return;

        // GradesPage skip — directly SubjectsPage pe jao
        // Loading dikhao
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );

        try {
          final gradeInt = grade == 'Nursery' ? 0 : (int.tryParse(grade) ?? 6);

          // mediumFull: "Hindi Medium" / "English Medium" / "Odia Medium"
          final mediumFull = '${medium[0].toUpperCase()}${medium.substring(1)} Medium';

          // Odia medium ke liye alag login email use karo
          // (backend pe Odia ke courses alag enrolled hain)
          final loginGrade = (medium.toLowerCase() == 'odia') ? gradeInt : gradeInt;

          // API login
          final loginResponse = await ApiService.loginUser(loginGrade);
          if (!mounted) return;

          if (loginResponse == null) {
            Navigator.pop(context); // close loader
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to connect. Please try again.')),
            );
            return;
          }

          // Fetch courses — partner pass karo taaki sahi courses aayein
          // Odia ke liye mediumFull "Odia Medium" hoga — SubjectsPage filter karega
          final courses = await ApiService.getEnrolledCoursesByPartner(
            loginResponse['reg_id'],
            loginResponse['classroom_id'],
            loginResponse['id'],
            selectedPartner, // partner-based filter
          );

          // Agar Odia medium select hua hai toh medium-specific courses filter karo
          final filteredCourses = (medium.toLowerCase() == 'odia')
              ? courses.where((c) {
                  final cMedium = (c['medium']?.toString() ?? '').toLowerCase();
                  return cMedium.contains('odia') || cMedium.isEmpty;
                }).toList()
              : courses;

          if (!mounted) return;
          Navigator.pop(context); // close loader

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SubjectsPage(
                grade: gradeInt,
                medium: mediumFull,
                courses: filteredCourses,
                loginData: loginResponse,
                allMediumCourses: [{'medium': mediumFull, 'courses': filteredCourses}],
              ),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // close loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading courses. Please try again.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save preferences. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error saving preferences. Please try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://isfinformatica.com');
    if (!await launchUrl(url)) throw Exception('Could not launch $url');
  }

  // ── TV Remote Navigation ───────────────────────────────────────
  int get _currentStepItemCount {
    final key = _steps[_currentStep]['key'];
    if (key == 'board')    return boardPartnerOptions.length;
    if (key == 'state')    return states.length;
    if (key == 'classes')  return allGrades.length;
    if (key == 'language') return getAvailableMediums().length;
    return 0;
  }

  void _tvSelectCurrentItem() {
    if (_nextButtonFocused) { if (_currentStepDone) _goNext(); return; }
    if (_backButtonFocused) { _goBack(); return; }

    final key = _steps[_currentStep]['key'];
    if (key == 'board' && _tvFocusedItemIndex < boardPartnerOptions.length) {
      _onBoardOptionChanged(boardPartnerOptions[_tvFocusedItemIndex]);
    } else if (key == 'state' && _tvFocusedItemIndex < states.length) {
      _onStateChanged(states[_tvFocusedItemIndex]);
    } else if (key == 'classes' && _tvFocusedItemIndex < allGrades.length) {
      _onGradeToggled(allGrades[_tvFocusedItemIndex]);
    } else if (key == 'language') {
      final mediums = getAvailableMediums();
      if (_tvFocusedItemIndex < mediums.length) {
        _onMediumToggled(mediums[_tvFocusedItemIndex]);
      }
    }
  }

  // ── TV Remote column layout info ─────────────────────────────
  // board/language: 1 column list
  // state: 3 columns
  // classes: 2 columns (left 7, right 6+OK)
  int get _stepColumns {
    final key = _steps[_currentStep]['key'];
    if (key == 'state')   return 3;
    if (key == 'classes') return 2;
    return 1;
  }

  int get _stepRowsPerCol {
    final key   = _steps[_currentStep]['key'];
    final count = _currentStepItemCount;
    if (key == 'state')   return (count / 3).ceil();
    if (key == 'classes') return (count / 2).ceil();
    return count;
  }

  // item index → column
  int _itemCol(int idx) {
    final rpc = _stepRowsPerCol;
    if (rpc == 0) return 0;
    return idx ~/ rpc;
  }

  // item index → row within its column
  int _itemRow(int idx) {
    final rpc = _stepRowsPerCol;
    if (rpc == 0) return 0;
    return idx % rpc;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ── Back / Escape ────────────────────────────────────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_nextButtonFocused || _backButtonFocused) {
        setState(() { _nextButtonFocused = false; _backButtonFocused = false; });
      } else if (_currentStep > 0) {
        _goBack();
      } else {
        Navigator.maybePop(context);
      }
      return KeyEventResult.handled;
    }

    // ── OK / Enter / Select ───────────────────────────────────
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      _tvSelectCurrentItem();
      return KeyEventResult.handled;
    }

    final itemCount = _currentStepItemCount;
    if (itemCount == 0) return KeyEventResult.ignored;

    final cols = _stepColumns;
    final rpc  = _stepRowsPerCol;

    // ── Arrow UP ─────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_nextButtonFocused || _backButtonFocused) {
        // Buttons se upar → items mein wapas jao (last item)
        setState(() {
          _nextButtonFocused = false;
          _backButtonFocused = false;
          _tvFocusedItemIndex = itemCount - 1;
        });
      } else {
        final row = _itemRow(_tvFocusedItemIndex);
        if (row > 0) {
          setState(() => _tvFocusedItemIndex--);
        }
        // row == 0 → top of column, kuch nahi
      }
      return KeyEventResult.handled;
    }

    // ── Arrow DOWN ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_nextButtonFocused || _backButtonFocused) return KeyEventResult.handled;
      final row  = _itemRow(_tvFocusedItemIndex);
      final col  = _itemCol(_tvFocusedItemIndex);
      final colStart = col * rpc;
      final colEnd   = (colStart + rpc - 1).clamp(0, itemCount - 1);
      if (_tvFocusedItemIndex < colEnd) {
        setState(() { _tvFocusedItemIndex++; _nextButtonFocused = false; });
      } else {
        // Bottom of column → OK button
        setState(() { _nextButtonFocused = true; _backButtonFocused = false; });
      }
      return KeyEventResult.handled;
    }

    // ── Arrow LEFT ────────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_nextButtonFocused && _currentStep > 0) {
        setState(() { _nextButtonFocused = false; _backButtonFocused = true; });
        return KeyEventResult.handled;
      }
      if (_backButtonFocused) return KeyEventResult.handled;
      if (cols > 1) {
        final col = _itemCol(_tvFocusedItemIndex);
        if (col > 0) {
          final row = _itemRow(_tvFocusedItemIndex);
          final newCol = col - 1;
          final newColStart = newCol * rpc;
          final newColEnd   = (newColStart + rpc - 1).clamp(0, itemCount - 1);
          final newIdx = (newColStart + row).clamp(newColStart, newColEnd);
          setState(() => _tvFocusedItemIndex = newIdx);
        }
      }
      return KeyEventResult.handled;
    }

    // ── Arrow RIGHT ───────────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_backButtonFocused) {
        setState(() { _backButtonFocused = false; _nextButtonFocused = true; });
        return KeyEventResult.handled;
      }
      if (_nextButtonFocused) return KeyEventResult.handled;
      if (cols > 1) {
        final col = _itemCol(_tvFocusedItemIndex);
        if (col < cols - 1) {
          final row = _itemRow(_tvFocusedItemIndex);
          final newCol = col + 1;
          final newColStart = newCol * rpc;
          final newColEnd   = (newColStart + rpc - 1).clamp(0, itemCount - 1);
          final newIdx = (newColStart + row).clamp(newColStart, newColEnd);
          setState(() => _tvFocusedItemIndex = newIdx);
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Auto-scroll grid to keep focused item visible ─────────────
  void _scrollToFocusedItem(int idx) {
    // State step removed — no auto-scroll needed
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SlideTransition(
                position: _slideIn,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(bottom: BorderSide(color: Color(0xFF21262D), width: 1)),
      ),
      child: Row(children: [
        _buildCircularLogo(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Learning Preferences',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            const Text('Personalize your educational experience',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF8B949E),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
        GestureDetector(
          onTap: _showSettingsModal,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D), width: 1.5),
            ),
            child: const Icon(Icons.settings_rounded, size: 18, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  // ── Progress header ────────────────────────────────────────────
  Widget _buildProgressHeader() {
    final steps = _steps;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(bottom: BorderSide(color: Color(0xFF21262D), width: 1)),
      ),
      child: Column(children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final passed = (i ~/ 2) < _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 2,
                  decoration: BoxDecoration(
                    color: passed ? const Color(0xFF4F46E5) : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }
            final idx       = i ~/ 2;
            final isDone    = idx < _currentStep;
            final isCurrent = idx == _currentStep;
            return _buildStepDot(steps[idx], isDone, isCurrent);
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) return const Expanded(child: SizedBox());
            final idx       = i ~/ 2;
            final isCurrent = idx == _currentStep;
            final isDone    = idx < _currentStep;
            return SizedBox(
              width: 56,
              child: Text(
                steps[idx]['label'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? Colors.white
                      : isDone
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF4B5568),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / steps.length,
            minHeight: 4,
            backgroundColor: const Color(0xFF21262D),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Step ${_currentStep + 1} of ${steps.length}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF4B5568), fontWeight: FontWeight.w500)),
          Text(
            _currentStepDone ? '✓ Completed' : 'Select an option',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _currentStepDone
                  ? const Color(0xFF059669)
                  : const Color(0xFF8B949E),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStepDot(Map<String, dynamic> step, bool isDone, bool isCurrent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrent
            ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)])
            : isDone
                ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)])
                : null,
        color: (!isCurrent && !isDone) ? const Color(0xFF1A1D23) : null,
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF4F46E5)
              : isDone
                  ? const Color(0xFF059669)
                  : const Color(0xFF30363D),
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.4),
                blurRadius: 12, spreadRadius: 2)]
            : isDone
                ? [BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.3),
                    blurRadius: 8)]
                : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
            : Icon(step['icon'] as IconData,
                size: 18,
                color: isCurrent ? Colors.white : const Color(0xFF4B5568)),
      ),
    );
  }

  // ── Current step router ────────────────────────────────────────
  Widget _buildCurrentStep() {
    final key = _steps[_currentStep]['key'];
    switch (key) {
      case 'board':    return _buildBoardStep();
      case 'state':    return _buildStateStep();
      case 'classes':  return _buildClassesStep();
      case 'language': return _buildLanguageStep();
      default:         return const SizedBox();
    }
  }

  // ── STEP: Board ──────────────────────────────────────────────────
  Widget _buildBoardStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final scale   = screenW / 1920;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF3A1200),
                Color(0xFF1A0800),
              ],
            ),
          ),
          child: Column(
            children: [
              // Title
              Padding(
                padding: EdgeInsets.only(top: screenH * 0.08, bottom: screenH * 0.06),
                child: Column(
                  children: [
                    Text(
                      'SELECT YOUR BOARD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 55.0 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
              Center(
                child: Container(
                  width: 120 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF360C), Color(0xFFFFB74D)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
                  ],
                ),
              ),

              // Board options
              if (isLoadingPartners)
                SizedBox(
                  height: 80 * scale,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: boardPartnerOptions.asMap().entries.map((e) {
                          final idx       = e.key;
                          final option    = e.value;
                          final isSelected = selectedBoardOption == option;
                          final isTvFocused = idx == _tvFocusedItemIndex &&
                              !_nextButtonFocused && !_backButtonFocused;
                          return GestureDetector(
                            onTap: () => _onBoardOptionChanged(option),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0 * scale),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 61.0 * scale,
                                    height: 61.0 * scale,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE8A020)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                          61.0 * scale * 0.20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFE8A020)
                                            : isTvFocused
                                                ? Colors.white
                                                : Colors.white54,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check_rounded,
                                            size: 61.0 * scale * 0.60,
                                            color: Colors.white)
                                        : null,
                                  ),
                                  SizedBox(width: 20.0 * scale),
                                  Text(
                                    option,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      color: Colors.white,
                                      fontSize: 45.0 * scale,
                                      fontWeight: FontWeight.w500,
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
                ),

              // OK Button
              Padding(
                padding: EdgeInsets.only(bottom: screenH * 0.06),
                child: GestureDetector(
                  onTap: _currentStepDone ? _goNext : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 355.0 * scale,
                    height: 62.0 * scale,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4A4F5C), Color(0xFF2A2D36)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _nextButtonFocused ? Colors.white : Colors.transparent,
                        width: _nextButtonFocused ? 2 : 0,
                      ),
                      boxShadow: _nextButtonFocused
                          ? [BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 14, spreadRadius: 2)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 45.0 * scale,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── STEP: State ──────────────────────────────────────────────────
  Widget _buildStateStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW  = constraints.maxWidth;
        final screenH  = constraints.maxHeight;
        final scale    = screenW / 1920;

        // 3 columns mein split
        final colLen   = (states.length / 3).ceil();
        final col1     = states.sublist(0, colLen);
        final col2     = states.sublist(colLen, (colLen * 2).clamp(0, states.length));
        final col3     = states.sublist((colLen * 2).clamp(0, states.length));

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF3A1200),
                Color(0xFF1A0800),
              ],
            ),
          ),
          child: Column(
            children: [
              // Title
              Padding(
                padding: EdgeInsets.only(top: screenH * 0.04, bottom: screenH * 0.02),
                child: Column(
                  children: [
                    Text(
                      'SELECT YOUR STATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 55.0 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
              Center(
                child: Container(
                  width: 120 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF360C), Color(0xFFFFB74D)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
                  ],
                ),
              ),

              // 3-column state list
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenW * 0.04, vertical: screenH * 0.01),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1
                      Expanded(
                        child: ListView(
                          children: col1.asMap().entries.map((e) {
                            final idx        = e.key;
                            final state      = e.value;
                            final isSelected = selectedState == state;
                            final isTvFocused = idx == _tvFocusedItemIndex &&
                                !_nextButtonFocused && !_backButtonFocused;
                            return _buildStateRow(
                                state, isSelected, isTvFocused, scale);
                          }).toList(),
                        ),
                      ),

                      SizedBox(width: screenW * 0.02),

                      // Column 2
                      Expanded(
                        child: ListView(
                          children: col2.asMap().entries.map((e) {
                            final idx        = e.key;
                            final state      = e.value;
                            final isSelected = selectedState == state;
                            final globalIdx  = idx + col1.length;
                            final isTvFocused = globalIdx == _tvFocusedItemIndex &&
                                !_nextButtonFocused && !_backButtonFocused;
                            return _buildStateRow(
                                state, isSelected, isTvFocused, scale);
                          }).toList(),
                        ),
                      ),

                      SizedBox(width: screenW * 0.02),

                      // Column 3
                      Expanded(
                        child: ListView(
                          children: col3.asMap().entries.map((e) {
                            final idx        = e.key;
                            final state      = e.value;
                            final isSelected = selectedState == state;
                            final globalIdx  = idx + col1.length + col2.length;
                            final isTvFocused = globalIdx == _tvFocusedItemIndex &&
                                !_nextButtonFocused && !_backButtonFocused;
                            return _buildStateRow(
                                state, isSelected, isTvFocused, scale);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // OK Button
              Padding(
                padding: EdgeInsets.only(bottom: screenH * 0.04),
                child: GestureDetector(
                  onTap: _currentStepDone ? _goNext : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 355.0 * scale,
                    height: 62.0 * scale,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4A4F5C), Color(0xFF2A2D36)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _nextButtonFocused ? Colors.white : Colors.transparent,
                        width: _nextButtonFocused ? 2 : 0,
                      ),
                      boxShadow: _nextButtonFocused
                          ? [BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 14, spreadRadius: 2)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 45.0 * scale,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateRow(
      String state, bool isSelected, bool isTvFocused, double scale) {
    final checkSize = 36.0 * scale;   // chhota — 44 → 36
    final fontSize  = 26.0 * scale;   // chhota — 32 → 26
    final vPad      =  7.0 * scale;   // chhota — 10 → 7

    return GestureDetector(
      onTap: () => _onStateChanged(state),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
              horizontal: 8 * scale, vertical: 4 * scale),
          decoration: BoxDecoration(
            color: isTvFocused
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isTvFocused ? Colors.white38 : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: checkSize,
                height: checkSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE8A020)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(checkSize * 0.20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFE8A020)
                        : Colors.white54,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: checkSize * 0.60, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 12.0 * scale),
              Text(
                state,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 1: Classes ─ same style as board/state/medium ──────────
  Widget _buildClassesStep() {
    final gradeLabels = {
      'Nursery': 'Nursery',
      '1': '1st Standard',  '2': '2nd Standard',  '3': '3rd Standard',
      '4': '4th Standard',  '5': '5th Standard',  '6': '6th Standard',
      '7': '7th Standard',  '8': '8th Standard',  '9': '9th Standard',
      '10': '10th Standard','11': '11th Standard', '12': '12th Standard',
    };
    final leftGrades  = allGrades.sublist(0, 7);
    final rightGrades = allGrades.sublist(7);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final scale   = screenW / 1920;

        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF3A1200), // warm dark brown center
                Color(0xFF1A0800), // very dark edges
              ],
            ),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Title — same font/padding as board/state/medium ──
            Padding(
              padding: EdgeInsets.only(top: screenH * 0.08, bottom: screenH * 0.04),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text('SELECT YOUR CLASS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 55.0 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  // ── Orange accent underline (same as board/state/medium pages) ──
                  Center(
                    child: Container(
                      width: 120 * scale,
                      height: 4 * scale,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBF360C), Color(0xFFFFB74D)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Two columns + OR divider (commented) + OK ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenW * 0.06),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left column ──
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: leftGrades.asMap().entries.map((e) {
                            final idx        = e.key;
                            final grade      = e.value;
                            final isSelected = selectedGrades.contains(grade);
                            final isTvFocused = idx == _tvFocusedItemIndex &&
                                !_nextButtonFocused && !_backButtonFocused;
                            return _buildGradeRow(grade, gradeLabels[grade] ?? grade,
                                isSelected, isTvFocused, scale);
                          }).toList(),
                        ),
                      ),
                    ),

                    // ── OR + vertical line (commented out per user request) ──
                    // SizedBox(width: screenW * 0.05, ...),
                    SizedBox(width: screenW * 0.04),

                    // ── Right column + OK button ──
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...rightGrades.asMap().entries.map((e) {
                              final idx        = e.key;
                              final grade      = e.value;
                              final isSelected = selectedGrades.contains(grade);
                              final globalIdx  = idx + leftGrades.length;
                              final isTvFocused = globalIdx == _tvFocusedItemIndex &&
                                  !_nextButtonFocused && !_backButtonFocused;
                              return _buildGradeRow(grade, gradeLabels[grade] ?? grade,
                                  isSelected, isTvFocused, scale);
                            }),

                            // ── OK button: Figma W:355 H:62 R:14 ──
                            SizedBox(height: 16.0 * scale),
                            GestureDetector(
                              onTap: _currentStepDone ? _goNext : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 355.0 * scale,
                                height: 62.0 * scale,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF4A4F5C), Color(0xFF2A2D36)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _nextButtonFocused ? Colors.white : Colors.transparent,
                                    width: _nextButtonFocused ? 2 : 0,
                                  ),
                                  boxShadow: _nextButtonFocused
                                      ? [BoxShadow(color: Colors.white.withOpacity(0.2),
                                          blurRadius: 14, spreadRadius: 2)]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text('OK',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    color: Colors.white,
                                    fontSize: 45.0 * scale,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
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
          ],
        ), // Column
        ); // Container
      },
    );
  }

  // Manrope 45px, checkbox 61×61px — same as board/state/medium pages
  Widget _buildGradeRow(String grade, String label, bool isSelected, bool isTvFocused, double scale) {
    final checkSize = 61.0 * scale;
    final fontSize  = 45.0 * scale;
    final vPad      = 14.0 * scale;

    return GestureDetector(
      onTap: () => _onGradeToggled(grade),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
          decoration: BoxDecoration(
            color: isTvFocused ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isTvFocused ? Colors.white38 : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: checkSize, height: checkSize,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8A020) : Colors.transparent,
                  borderRadius: BorderRadius.circular(checkSize * 0.20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFE8A020)
                        : isTvFocused ? Colors.white : Colors.white54,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: checkSize * 0.60, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 20.0 * scale),
              Text(label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: isTvFocused ? Colors.white : Colors.white,
                  fontSize: fontSize,
                  fontWeight: isTvFocused ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 2: Language ── Board style mein ────────────────────────
  Widget _buildLanguageStep() {
    final mediums = getAvailableMediums();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final scale   = screenW / 1920;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF3A1200),
                Color(0xFF1A0800),
              ],
            ),
          ),
          child: Column(
            children: [
              // Title — same as board page
              Padding(
                padding: EdgeInsets.only(top: screenH * 0.08, bottom: screenH * 0.06),
                child: Column(
                  children: [
                    Text(
                      'SELECT MEDIUM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 55.0 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
              Center(
                child: Container(
                  width: 120 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF360C), Color(0xFFFFB74D)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
                  ],
                ),
              ),

              // Medium options — exact board style (center column)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: mediums.asMap().entries.map((e) {
                        final idx        = e.key;
                        final medium     = e.value;
                        final isSelected = selectedMediums.contains(medium);
                        final isTvFocused = idx == _tvFocusedItemIndex &&
                            !_nextButtonFocused && !_backButtonFocused;
                        return GestureDetector(
                          onTap: () => _onMediumToggled(medium),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0 * scale),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 61.0 * scale,
                                  height: 61.0 * scale,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE8A020)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                        61.0 * scale * 0.20),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFE8A020)
                                          : isTvFocused
                                              ? Colors.white
                                              : Colors.white54,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check_rounded,
                                          size: 61.0 * scale * 0.60,
                                          color: Colors.white)
                                      : null,
                                ),
                                SizedBox(width: 20.0 * scale),
                                Text(
                                  medium,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    color: Colors.white,
                                    fontSize: 45.0 * scale,
                                    fontWeight: FontWeight.w500,
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
              ),

              // OK Button — same as board page
              Padding(
                padding: EdgeInsets.only(bottom: screenH * 0.06),
                child: GestureDetector(
                  onTap: _currentStepDone ? _goNext : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 355.0 * scale,
                    height: 62.0 * scale,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4A4F5C), Color(0xFF2A2D36)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _nextButtonFocused ? Colors.white : Colors.transparent,
                        width: _nextButtonFocused ? 2 : 0,
                      ),
                      boxShadow: _nextButtonFocused
                          ? [BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 14, spreadRadius: 2)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 45.0 * scale,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step title ─────────────────────────────────────────────────
  Widget _buildStepTitle({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
  }) {
    return Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [color, color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF8B949E),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  // ── Bottom bar ─────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(top: BorderSide(
            color: const Color(0xFF21262D).withOpacity(0.8), width: 1)),
      ),
      child: Row(children: [
        // Back button
        if (_currentStep > 0)
          GestureDetector(
            onTap: _goBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 52,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D23),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _backButtonFocused ? Colors.white : const Color(0xFF30363D),
                  width: _backButtonFocused ? 2.5 : 1.5,
                ),
                boxShadow: _backButtonFocused
                    ? [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 12)]
                    : null,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),

        // Next / Complete button
        Expanded(
          child: GestureDetector(
            onTap: _currentStepDone ? _goNext : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 52,
              decoration: BoxDecoration(
                gradient: _currentStepDone
                    ? const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)])
                    : null,
                color: _currentStepDone ? null : const Color(0xFF1A1D23),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _nextButtonFocused
                      ? Colors.white
                      : _currentStepDone
                          ? Colors.transparent
                          : const Color(0xFF30363D),
                  width: _nextButtonFocused ? 2.5 : 1.5,
                ),
                boxShadow: _nextButtonFocused
                    ? [BoxShadow(color: Colors.white.withOpacity(0.4),
                        blurRadius: 14, offset: const Offset(0, 4))]
                    : _currentStepDone
                        ? [BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  _isLastStep ? 'Complete Setup' : 'Next',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: _currentStepDone ? Colors.white : const Color(0xFF4B5568),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 18,
                  color: _currentStepDone ? Colors.white : const Color(0xFF4B5568),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Powered by ─────────────────────────────────────────────────
  Widget _buildPoweredBy() {
    return GestureDetector(
      onTap: _launchURL,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF080B0F),
          border: Border(top: BorderSide(color: Color(0xFF1A1D23), width: 1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Powered by',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF4B5568),
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          _buildLogo(width: 80, height: 16),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _buildLogo({double? width, double? height}) {
    return SizedBox(
      width: width ?? 100, height: height ?? 40,
      child: Image.asset('assets/images/powered_by_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('EASY LEARN',
              style: TextStyle(
                  fontSize: 10, color: Color(0xFF6B7A99),
                  fontWeight: FontWeight.w700, letterSpacing: 0.8))),
    );
  }

  Widget _buildCircularLogo({double? size}) {
    return Container(
      width: size ?? 40, height: size ?? 40,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF30363D), width: 2)),
      child: ClipOval(
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 22),
            )),
      ),
    );
  }

  Color _getMediumColor(String medium) {
    switch (medium) {
      case 'Odia':    return const Color(0xFF059669);
      case 'Hindi':   return const Color(0xFFDC2626);
      case 'English': return const Color(0xFF3B82F6);
      default:        return const Color(0xFF6366F1);
    }
  }

  IconData _getMediumIcon(String medium) {
    switch (medium) {
      case 'Odia':    return Icons.translate_rounded;
      case 'Hindi':   return Icons.language_rounded;
      case 'English': return Icons.public_rounded;
      default:        return Icons.language_rounded;
    }
  }

  String _getMediumDescription(String medium) {
    switch (medium) {
      case 'Odia':    return 'Regional language instruction with cultural context';
      case 'Hindi':   return 'National language medium for comprehensive learning';
      case 'English': return 'International language medium for global opportunities';
      default:        return 'Language instruction medium';
    }
  }

  // ── Settings modal ─────────────────────────────────────────────
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A1D23), Color(0xFF21262D)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            border: Border(
              top:   BorderSide(color: Color(0xFF30363D), width: 2),
              left:  BorderSide(color: Color(0xFF30363D), width: 1),
              right: BorderSide(color: Color(0xFF30363D), width: 1),
            ),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF8B949E),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Filter Settings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text('Enable or disable filter options',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: const Color(0xFF30363D),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _buildFilterToggle('Board Filter',
                      'Show curriculum board selection',
                      Icons.account_balance_rounded, showBoardFilter, (v) {
                    setModalState(() => showBoardFilter = v);
                    setState(() {
                      showBoardFilter = v;
                      if (_currentStep >= _steps.length) _currentStep = 0;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildFilterToggle('State Filter',
                      'Show state/region selection',
                      Icons.location_on_rounded, showStateFilter, (v) {
                    setModalState(() => showStateFilter = v);
                    setState(() {
                      showStateFilter = v;
                      if (_currentStep >= _steps.length) _currentStep = 0;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildFilterToggle('Grade Filter',
                      'Show class/grade selection',
                      Icons.grade_rounded, showGradeFilter, (v) {
                    setModalState(() => showGradeFilter = v);
                    setState(() {
                      showGradeFilter = v;
                      if (_currentStep >= _steps.length) _currentStep = 0;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildFilterToggle('Medium Filter',
                      'Show language medium selection',
                      Icons.language_rounded, showMediumFilter, (v) {
                    setModalState(() => showMediumFilter = v);
                    setState(() {
                      showMediumFilter = v;
                      if (_currentStep >= _steps.length) _currentStep = 0;
                    });
                  }),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilterToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    void Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF30363D).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? const Color(0xFF4F46E5).withOpacity(0.3)
              : const Color(0xFF30363D),
        ),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF4F46E5).withOpacity(0.2)
                : const Color(0xFF8B949E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18,
              color: value ? const Color(0xFF4F46E5) : const Color(0xFF8B949E)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: value ? Colors.white : const Color(0xFF8B949E))),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8B949E))),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4F46E5),
          inactiveThumbColor: const Color(0xFF8B949E),
          inactiveTrackColor: const Color(0xFF30363D),
        ),
      ]),
    );
  }
}