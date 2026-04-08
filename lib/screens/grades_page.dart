import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // ← SystemNavigator ke liye
import '../widgets/grade_card.dart';
import '../screens/subjects_page.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_selection_page.dart';

class GradesPage extends StatefulWidget {
  final Map<String, dynamic> selectedProfile;
  final List<String>? filteredGrades;
  final List<String>? selectedMediums;
  final String? selectedCategory;
  final String? selectedPartner;

  const GradesPage({
    Key? key,
    required this.selectedProfile,
    this.filteredGrades,
    this.selectedMediums,
    this.selectedCategory,
    this.selectedPartner,
    String? selectedBoard,
  }) : super(key: key);

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  // TV remote focus state
  int _focusedGradeIndex = 0;
  bool _profileButtonFocused = false;
  // Callbacks for each grade's explore button
  final List<VoidCallback> _exploreCallbacks = [];

  // Getters from old widget fields
  Map<String, dynamic> get selectedProfile => widget.selectedProfile;
  List<String>? get filteredGrades => widget.filteredGrades;
  List<String>? get selectedMediums => widget.selectedMediums;
  String? get selectedCategory => widget.selectedCategory;
  String? get selectedPartner => widget.selectedPartner;

  // Default mediums for when no filter is applied
  final List<String> defaultMediums = const [
    'Odia Medium',
    'Hindi Medium',
    'English Medium',
  ];

  // ── TV Remote Key Handler ──────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Back button → wapas FilterPage pe jao
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    final gradesToShow = filteredGrades ?? ['6', '7', '8', '9', '10', '11', '12'];

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedGradeIndex = (_focusedGradeIndex - 1).clamp(0, gradesToShow.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedGradeIndex = (_focusedGradeIndex + 1).clamp(0, gradesToShow.length - 1);
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _profileButtonFocused = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _profileButtonFocused = false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_profileButtonFocused) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfileSelectionPage()),
        );
      } else if (_focusedGradeIndex < _exploreCallbacks.length) {
        _exploreCallbacks[_focusedGradeIndex]();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://isfinformatica.com');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getCleanAvatar(String avatar) {
    // Handle broken avatar data
    if (avatar.contains('?') || avatar.isEmpty || avatar.length > 4) {
      return '\ud83d\udc64'; // Default avatar if broken
    }
    return avatar;
  }

  Color _getGradeColor(int grade) {
    if (grade <= 5) return const Color(0xFF10B981);
    if (grade <= 8) return const Color(0xFF3B82F6);
    if (grade <= 10) return const Color(0xFF8B5CF6);
    return const Color(0xFFEF4444);
  }

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
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (showDebugInfo) {
              // print('Circular logo loading error: $error');
              // print('Stack trace: $stackTrace');
            }

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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;
    final bool isTablet = screenSize.width > 600;

    // Use filtered data or default data
    final List<String> gradesToShow =
        filteredGrades ?? ['6', '7', '8', '9', '10', '11', '12'];
    final List<String> mediumsToShow = selectedMediums != null
        ? selectedMediums!.map((medium) => '$medium Medium').toList()
        : defaultMediums;

    // Improved responsive grid configuration to prevent overflow
    int crossAxisCount;
    double crossAxisSpacing;
    double mainAxisSpacing;
    double aspectRatio;

    if (screenSize.width < 320) {
      // Very small phones - single column to prevent overflow
      crossAxisCount = 1;
      crossAxisSpacing = 8;
      mainAxisSpacing = 8;
      aspectRatio = 1.8; // Wider for single column
    } else if (screenSize.width < 380) {
      // Small phones - 2 columns with tight spacing
      crossAxisCount = 2;
      crossAxisSpacing = 8;
      mainAxisSpacing = 8;
      aspectRatio = 0.65; // Taller cards to fit content
    } else if (screenSize.width < 600) {
      // Regular phones - 2 columns with proper spacing
      crossAxisCount = 2;
      crossAxisSpacing = 12;
      mainAxisSpacing = 12;
      aspectRatio = 0.75; // Balanced aspect ratio
    } else if (screenSize.width < 900) {
      // Tablets portrait
      crossAxisCount = 3;
      crossAxisSpacing = 14;
      mainAxisSpacing = 14;
      aspectRatio = 0.9;
    } else {
      // Tablets landscape and larger
      crossAxisCount = 4;
      crossAxisSpacing = 16;
      mainAxisSpacing = 16;
      aspectRatio = 1.0;
    }

    // Responsive padding
    EdgeInsets bodyPadding = EdgeInsets.all(isSmallScreen ? 20 : 24);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      // ── Sticky footer ──
      bottomNavigationBar: GestureDetector(
        onTap: _launchURL,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0D14),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Powered by',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D23),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/logo_horizontal.png', height: 18, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/logo.png', width: 18, height: 18,
                      errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 16)),
                    const SizedBox(width: 8),
                    const Text('EASY LEARN',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ])),
              ]),
            ),
          ]),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Enhanced App Bar with profile switch button and circular logo
          SliverAppBar(
            expandedHeight: isSmallScreen ? 140 : 160,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0B0E13),
            automaticallyImplyLeading: false,  // ← default back arrow hide karo
            leading: Container(
              margin: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context), // ← wapas FilterPage pe jao
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D23),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF21262D)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            actions: [
              // Profile Switch Button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    // Navigate to ProfileSelectionPage
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSelectionPage(),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1D23), Color(0xFF21262D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _profileButtonFocused
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF30363D),
                        width: _profileButtonFocused ? 2.5 : 1.5,
                      ),
                      boxShadow: _profileButtonFocused
                          ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Profile Avatar Background
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  _getGradeColor(
                                    int.tryParse(
                                          selectedProfile['grade']
                                                  ?.toString() ??
                                              '1',
                                        ) ??
                                        1,
                                  ),
                                  _getGradeColor(
                                    int.tryParse(
                                          selectedProfile['grade']
                                                  ?.toString() ??
                                              '1',
                                        ) ??
                                        1,
                                  ).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _getCleanAvatar(
                                  selectedProfile['avatar']?.toString() ?? '\ud83d\udc64',
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        // Switch Indicator
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: const Color(0xFF1A1D23),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Circular logo in actions
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildCircularLogo(size: 35, showDebugInfo: true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0B0E13),
                      Color(0xFF1A1D23),
                      Color(0xFF21262D),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isSmallScreen ? 60 : 80,
                      20,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // \u2705 Replace education hat icon with your logo
                            Container(
                              width: isSmallScreen ? 50 : 60,
                              height: isSmallScreen ? 50 : 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback if logo not found
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFF4F46E5),
                                            Color(0xFF3B82F6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        Icons.school_rounded,
                                        color: Colors.white,
                                        size: isSmallScreen ? 24 : 28,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 16 : 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Responsive text that wraps properly
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Choose Your Learning Path',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 18 : 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main Content with enhanced educational design
          SliverToBoxAdapter(
            child: Padding(
              padding: bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced grades sections with educational theming
                  ...gradesToShow.asMap().entries.map((entry) {
                    final index = entry.key;
                    final gradeString = entry.value;
                    final grade = int.parse(gradeString);

                    // Educational milestone descriptions
                    String getMilestone(int grade) {
                      if (grade <= 8) return 'Foundation Building';
                      if (grade <= 10) return 'Core Concepts';
                      return 'Advanced Learning';
                    }

                    Color getMilestoneColor(int grade) {
                      if (grade <= 8) return const Color(0xFF059669);
                      if (grade <= 10) return const Color(0xFF3B82F6);
                      return const Color(0xFF8B5CF6);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index > 0) const SizedBox(height: 48),

                        // Enhanced Grade Section Header with educational context
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1A1D23),
                                const Color(0xFF21262D),
                                const Color(0xFF30363D).withOpacity(0.5),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: index == _focusedGradeIndex
                                  ? getMilestoneColor(grade)
                                  : getMilestoneColor(grade).withOpacity(0.3),
                              width: index == _focusedGradeIndex ? 3 : 2,
                            ),
                            boxShadow: [
                              if (index == _focusedGradeIndex)
                                BoxShadow(
                                  color: getMilestoneColor(grade).withOpacity(0.35),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 8),
                                ),
                              BoxShadow(
                                color: getMilestoneColor(
                                  grade,
                                ).withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Enhanced grade display with educational styling
                              Container(
                                width: isSmallScreen ? 70 : 80,
                                height: isSmallScreen ? 70 : 80,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      getMilestoneColor(grade),
                                      getMilestoneColor(grade).withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: getMilestoneColor(
                                        grade,
                                      ).withOpacity(0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$grade',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 28 : 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'CLASS',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 9 : 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 16 : 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Class $grade',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 22 : 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.language_rounded,
                                          size: 16,
                                          color: getMilestoneColor(
                                            grade,
                                          ).withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              '${mediumsToShow.length} Language${mediumsToShow.length > 1 ? 's' : ''}',
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 11
                                                    : 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Single Explore button — opens SubjectsPage with all mediums in sidebar
                        _GradeExploreButton(
                          grade: grade,
                          mediums: mediumsToShow,
                          selectedPartner: selectedPartner,
                          accentColor: getMilestoneColor(grade),
                          isTvFocused: index == _focusedGradeIndex && !_profileButtonFocused,
                          onRegisterCallback: (cb) {
                            if (index >= _exploreCallbacks.length) {
                              _exploreCallbacks.add(cb);
                            } else {
                              _exploreCallbacks[index] = cb;
                            }
                          },
                        ),
                      ],
                    );
                  }).toList(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ), // ← Scaffold close
    ), // ← PopScope close
    ); // ← Focus close
  }
}

// ── Single Explore button per grade ──────────────────────────────────────────
class _GradeExploreButton extends StatefulWidget {
  final int grade;
  final List<String> mediums;
  final String? selectedPartner;
  final Color accentColor;
  final bool isTvFocused;
  final void Function(VoidCallback cb)? onRegisterCallback;

  const _GradeExploreButton({
    required this.grade,
    required this.mediums,
    required this.accentColor,
    this.selectedPartner,
    this.isTvFocused = false,
    this.onRegisterCallback,
  });

  @override
  State<_GradeExploreButton> createState() => _GradeExploreButtonState();
}

class _GradeExploreButtonState extends State<_GradeExploreButton> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Register this button's _onExplore with parent for TV remote OK key
    widget.onRegisterCallback?.call(_onExplore);
  }

  Color _mediumColor(String medium) {
    if (medium.contains('Odia')) return const Color(0xFF059669);
    if (medium.contains('Hindi')) return const Color(0xFFDC2626);
    if (medium.contains('English')) return const Color(0xFF3B82F6);
    return const Color(0xFF6366F1);
  }

  Future<void> _onExplore() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // Login once
      final loginResponse = await ApiService.loginUser(widget.grade);
      if (loginResponse == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to connect. Please try again.')),
        );
        return;
      }

      // Fetch courses for ALL mediums in parallel
      final List<Map<String, dynamic>> allMediumCourses = [];
      await Future.wait(widget.mediums.map((medium) async {
        try {
          final courses = await ApiService.getEnrolledCoursesByPartner(
            loginResponse['reg_id'],
            loginResponse['classroom_id'],
            loginResponse['id'],
            widget.selectedPartner,
          );
          allMediumCourses.add({'medium': medium, 'courses': courses});
        } catch (_) {
          allMediumCourses.add({'medium': medium, 'courses': []});
        }
      }));

      // Sort to match original mediums order
      allMediumCourses.sort((a, b) =>
          widget.mediums.indexOf(a['medium'].toString())
              .compareTo(widget.mediums.indexOf(b['medium'].toString())));

      setState(() => _loading = false);

      // Use first medium as default selected
      final firstMedium = widget.mediums.first;
      final firstCourses = (allMediumCourses.first['courses'] as List).cast<dynamic>();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SubjectsPage(
            grade: widget.grade,
            medium: firstMedium,
            courses: firstCourses,
            loginData: loginResponse,
            allMediumCourses: allMediumCourses,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medium square cards row — same style as grade_card
        Row(
          children: widget.mediums.asMap().entries.map((e) {
            final i = e.key;
            final medium = e.value;
            final color = _mediumColor(medium);
            final name = medium.split(' ')[0];
            IconData icon;
            if (medium.contains('Odia')) icon = Icons.translate_rounded;
            else if (medium.contains('Hindi')) icon = Icons.language_rounded;
            else if (medium.contains('English')) icon = Icons.public_rounded;
            else icon = Icons.language_rounded;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < widget.mediums.length - 1 ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 7),
                  Text(name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Explore button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: GestureDetector(
            onTap: _onExplore,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.accentColor, widget.accentColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: widget.isTvFocused
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: widget.isTvFocused
                        ? Colors.white.withOpacity(0.4)
                        : widget.accentColor.withOpacity(0.35),
                    blurRadius: widget.isTvFocused ? 24 : 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Explore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}