import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../screens/subjects_page.dart';

class GradeCard extends StatefulWidget {
  final int grade;
  final String medium;
  final String? selectedPartner;
  // All mediums for the same grade — enables sidebar in SubjectsPage
  final List<String>? allMediums;

  const GradeCard({
    Key? key,
    required this.grade,
    required this.medium,
    this.selectedPartner,
    this.allMediums,
  }) : super(key: key);

  @override
  State<GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<GradeCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _elevationAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getMediumAccentColor(String medium) {
    if (medium.contains('Odia')) return const Color(0xFF059669);
    if (medium.contains('Hindi')) return const Color(0xFFDC2626);
    if (medium.contains('English')) return const Color(0xFF3B82F6);
    return const Color(0xFF6366F1);
  }

  Color _getMediumLightColor(String medium) {
    if (medium.contains('Odia'))
      return const Color(0xFF059669).withOpacity(0.15);
    if (medium.contains('Hindi'))
      return const Color(0xFFDC2626).withOpacity(0.15);
    if (medium.contains('English'))
      return const Color(0xFF3B82F6).withOpacity(0.15);
    return const Color(0xFF6366F1).withOpacity(0.15);
  }

  IconData _getMediumIcon(String medium) {
    if (medium.contains('Odia')) return Icons.translate_rounded;
    if (medium.contains('Hindi')) return Icons.language_rounded;
    if (medium.contains('English')) return Icons.public_rounded;
    return Icons.language_rounded;
  }

  String _getMediumDescription(String medium) {
    if (medium.contains('Odia')) return 'Regional Excellence';
    if (medium.contains('Hindi')) return 'National Standard';
    if (medium.contains('English')) return 'Global Opportunities';
    return 'Quality Education';
  }

  String _getMediumShortName(String medium) {
    if (medium.contains('Odia')) return 'OD';
    if (medium.contains('Hindi')) return 'HI';
    if (medium.contains('English')) return 'EN';
    return 'LG';
  }

  String _getGradeCategory(int grade) {
    if (grade <= 8) return 'Foundation';
    if (grade <= 10) return 'Secondary';
    return 'Higher Secondary';
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;
    final bool isTinyScreen = screenSize.width < 320;

    // Fixed responsive measurements to prevent overflow
    final double cardPadding = isTinyScreen ? 8 : (isSmallScreen ? 10 : 14);
    final double headerHeight = isTinyScreen ? 50 : (isSmallScreen ? 60 : 70);
    final double gradeIconSize = isTinyScreen ? 32 : (isSmallScreen ? 36 : 40);
    final double buttonHeight = isTinyScreen ? 32 : (isSmallScreen ? 36 : 40);
    final double borderRadius = isTinyScreen ? 12 : (isSmallScreen ? 16 : 20);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _animationController.forward();
              HapticFeedback.lightImpact();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _animationController.reverse();
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _animationController.reverse();
            },
            onTap: () async {
              HapticFeedback.mediumImpact();
              await _handleCardTap();
            },
            child: MouseRegion(
              onEnter: (_) {
                setState(() => _isHovered = true);
                if (!_isPressed) _animationController.forward();
              },
              onExit: (_) {
                setState(() => _isHovered = false);
                if (!_isPressed) _animationController.reverse();
              },
              child: Container(
                constraints: BoxConstraints(
                  minHeight: isTinyScreen ? 140 : (isSmallScreen ? 160 : 180),
                  maxHeight: isTinyScreen ? 180 : (isSmallScreen ? 200 : 220),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    // Main shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: _elevationAnimation.value * 1.5,
                      offset: Offset(0, _elevationAnimation.value * 0.3),
                    ),
                    // Glow effect when hovered/pressed
                    if (_isHovered || _isPressed)
                      BoxShadow(
                        color: _getMediumAccentColor(
                          widget.medium,
                        ).withOpacity(0.2 * _glowAnimation.value),
                        blurRadius: 15 * _glowAnimation.value,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isPressed
                          ? [
                              const Color(0xFF0F1419),
                              const Color(0xFF1A1D23),
                              const Color(0xFF21262D),
                            ]
                          : [
                              const Color(0xFF1A1D23),
                              const Color(0xFF21262D),
                              const Color(0xFF30363D).withOpacity(0.3),
                            ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: (_isPressed || _isHovered)
                          ? _getMediumAccentColor(
                              widget.medium,
                            ).withOpacity(0.4)
                          : const Color(0xFF30363D),
                      width: (_isPressed || _isHovered) ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact mobile header
                      Container(
                        height: headerHeight,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: cardPadding,
                          vertical: isTinyScreen ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getMediumAccentColor(widget.medium),
                              _getMediumAccentColor(
                                widget.medium,
                              ).withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(borderRadius - 1),
                            topRight: Radius.circular(borderRadius - 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Compact language icon
                            Container(
                              width: isTinyScreen
                                  ? 24
                                  : (isSmallScreen ? 28 : 32),
                              height: isTinyScreen
                                  ? 24
                                  : (isSmallScreen ? 28 : 32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getMediumIcon(widget.medium),
                                size: isTinyScreen
                                    ? 12
                                    : (isSmallScreen ? 14 : 16),
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: isTinyScreen ? 6 : 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.medium.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: isTinyScreen
                                          ? 11
                                          : (isSmallScreen ? 13 : 14),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!isTinyScreen)
                                    Text(
                                      'Medium',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 9 : 10,
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Compact language badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTinyScreen ? 4 : 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getMediumShortName(widget.medium),
                                style: TextStyle(
                                  fontSize: isTinyScreen ? 8 : 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flexible content area that prevents overflow
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Compact grade display
                              Expanded(
                                flex: 2,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Responsive grade icon
                                    Container(
                                      width: gradeIconSize,
                                      height: gradeIconSize,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            _getMediumAccentColor(
                                              widget.medium,
                                            ),
                                            _getMediumAccentColor(
                                              widget.medium,
                                            ).withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getMediumAccentColor(
                                              widget.medium,
                                            ).withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${widget.grade}',
                                          style: TextStyle(
                                            fontSize: isTinyScreen
                                                ? 14
                                                : (isSmallScreen ? 16 : 18),
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isTinyScreen ? 6 : 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Class',
                                            style: TextStyle(
                                              fontSize: isTinyScreen
                                                  ? 12
                                                  : (isSmallScreen ? 13 : 14),
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (!isTinyScreen) ...[
                                            SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getMediumLightColor(
                                                  widget.medium,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getGradeCategory(widget.grade),
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getMediumAccentColor(
                                                    widget.medium,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Compact action button that prevents overflow
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: _isPressed
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFE5E7EB),
                                              Color(0xFFD1D5DB),
                                            ],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Color(0xFFF8F9FA),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: !_isPressed
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.08,
                                              ),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_stories_rounded,
                                          size: isTinyScreen
                                              ? 12
                                              : (isSmallScreen ? 14 : 16),
                                          color: _getMediumAccentColor(
                                            widget.medium,
                                          ),
                                        ),
                                        SizedBox(width: isTinyScreen ? 3 : 4),
                                        Flexible(
                                          child: Text(
                                            isTinyScreen
                                                ? 'Explore'
                                                : 'Explore',
                                            style: TextStyle(
                                              fontSize: isTinyScreen
                                                  ? 10
                                                  : (isSmallScreen ? 11 : 12),
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0B0E13),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: isTinyScreen ? 2 : 3),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: isTinyScreen
                                              ? 10
                                              : (isSmallScreen ? 12 : 14),
                                          color: const Color(0xFF0B0E13),
                                        ),
                                      ],
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCardTap() async {
    // Enhanced loading dialog with educational theming
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(36),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1D23), Color(0xFF21262D)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _getMediumAccentColor(widget.medium).withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: _getMediumAccentColor(widget.medium).withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated loading indicator
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _getMediumAccentColor(widget.medium),
                      _getMediumAccentColor(widget.medium).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: _getMediumAccentColor(
                        widget.medium,
                      ).withOpacity(0.4),
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
                    Icon(Icons.school_rounded, size: 28, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Class ${widget.grade}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing your ${widget.medium.split(' ')[0]} curriculum...',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B949E),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getMediumLightColor(widget.medium),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getMediumAccentColor(
                      widget.medium,
                    ).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: _getMediumAccentColor(widget.medium),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getMediumAccentColor(widget.medium),
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

    try {
      // print('Selected Partner: ${widget.selectedPartner}');
      // Step 1: Login based on class
      final loginResponse = await ApiService.loginUser(widget.grade);

      if (loginResponse != null) {
        // Step 2: Get enrolled courses
        final coursesResponse = await ApiService.getEnrolledCoursesByPartner(
          loginResponse['reg_id'],
          loginResponse['classroom_id'],
          loginResponse['id'],
          widget.selectedPartner,
        );

        // DEBUG - check console output
        print('=== GRADE_CARD DEBUG ===');
        print('partner: ${widget.selectedPartner}');
        print('grade: ${widget.grade}, medium: ${widget.medium}');
        print('loginResponse: $loginResponse');
        print('courses count: ${coursesResponse.length}');
        if (coursesResponse.isNotEmpty) {
          print('first course: ${coursesResponse.first}');
        } else {
          print('NO COURSES RETURNED - check api_service getEnrolledCoursesByPartner');
        }
        print('=======================');

        Navigator.pop(context); // Remove loading dialog

        // Build allMediumCourses for TV sidebar
        // Start with the currently tapped medium
        final List<Map<String, dynamic>> allMediumCourses = [
          {'medium': widget.medium, 'courses': coursesResponse},
        ];

        // Fetch courses for other mediums if provided
        if (widget.allMediums != null) {
          for (final otherMedium in widget.allMediums!) {
            if (otherMedium == widget.medium) continue;
            try {
              final otherCourses = await ApiService.getEnrolledCoursesByPartner(
                loginResponse['reg_id'],
                loginResponse['classroom_id'],
                loginResponse['id'],
                widget.selectedPartner,
              );
              allMediumCourses.add({
                'medium': otherMedium,
                'courses': otherCourses,
              });
            } catch (_) {
              allMediumCourses.add({'medium': otherMedium, 'courses': []});
            }
          }
        }

        // Navigate to subjects page with enhanced transition
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SubjectsPage(
                  grade: widget.grade,
                  medium: widget.medium,
                  courses: coursesResponse,
                  loginData: loginResponse,
                  allMediumCourses: allMediumCourses,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        Navigator.pop(context);
        _showEnhancedErrorSnackBar(
          context,
          'Unable to connect to your learning dashboard. Please try again.',
          'Connection Failed',
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showEnhancedErrorSnackBar(
        context,
        'Something went wrong while loading your subjects. Please check your connection and try again.',
        'Error Occurred',
      );
    }
  }

  void _showEnhancedErrorSnackBar(
    BuildContext context,
    String message,
    String title,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1A1D23),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF30363D), width: 1),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 12,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}