// screens/profile_selection_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/profile_storage.dart';
import 'create_profile_page.dart';
import 'grades_page.dart';
import 'filter_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSelectionPage extends StatefulWidget {
  @override
  _ProfileSelectionPageState createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> profiles = [];
  bool isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _loadProfiles();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final cachedProfiles = await ProfileStorage.getCachedProfiles();

      if (cachedProfiles.isNotEmpty) {
        setState(() {
          profiles = cachedProfiles;
          isLoading = false;
        });
        _fadeController.forward();
      }

      final apiProfiles = await ApiService.getAllProfiles();

      if (apiProfiles.isNotEmpty) {
        final profilesList = apiProfiles.cast<Map<String, dynamic>>();
        await ProfileStorage.cacheProfiles(profilesList);

        setState(() {
          profiles = profilesList;
          isLoading = false;
        });
      } else if (cachedProfiles.isEmpty) {
        setState(() {
          isLoading = false;
        });
      }

      _fadeController.forward();
    } catch (e) {
      print('Error loading profiles: $e');
      setState(() {
        isLoading = false;
      });
      _fadeController.forward();
    }
  }

  void _onProfileSelect(Map<String, dynamic> profile) async {
    try {
      await ProfileStorage.setActiveProfile(profile['id'].toString());
      await ApiService.setActiveProfile(profile['id'].toString());

      final hasCompletedSetup =
          profile['has_completed_setup'] == 1 ||
          profile['has_completed_setup'] == '1' ||
          profile['has_completed_setup'] == true;

      if (hasCompletedSetup) {
        final savedFilters = await ProfileStorage.getFilters(
          profile['id'].toString(),
        );

        final filteredGrades =
            savedFilters?['selectedGrades']?.cast<String>() ?? [];
        final selectedMediums =
            savedFilters?['selectedMediums']?.cast<String>() ?? [];
        final selectedPartner = savedFilters?['selectedPartner'];

        List<String> finalGrades = filteredGrades;
        List<String> finalMediums = selectedMediums;

        if (finalGrades.isEmpty && profile['grade'] != null) {
          finalGrades = [profile['grade'].toString()];
        }

        if (finalMediums.isEmpty && profile['medium'] != null) {
          finalMediums = [profile['medium'].toString()];
        }

        if (finalGrades.isEmpty) {
          finalGrades = ['6', '7', '8', '9', '10', '11', '12'];
        }

        if (finalMediums.isEmpty) {
          finalMediums = ['English'];
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GradesPage(
              selectedProfile: profile,
              filteredGrades: finalGrades,
              selectedMediums: finalMediums,
              selectedCategory: null,
              selectedPartner: selectedPartner,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FilterPage(profile: profile)),
        );
      }
    } catch (e) {
      print('Error selecting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onCreateProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateProfilePage(
              onProfileCreated: (newProfile) {
                setState(() {
                  profiles.add(newProfile);
                });
                _onProfileSelect(newProfile);
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://isfinformatica.com');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getTimeAgo(String? lastAccessedStr) {
    if (lastAccessedStr == null) return 'Never';

    try {
      final lastAccessed = DateTime.parse(lastAccessedStr);
      final now = DateTime.now();
      final difference = now.difference(lastAccessed);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${difference.inDays ~/ 7}w ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Color _getGradeColor(int grade) {
    if (grade <= 5) return const Color(0xFF10B981);
    if (grade <= 8) return const Color(0xFF3B82F6);
    if (grade <= 10) return const Color(0xFF8B5CF6);
    return const Color(0xFFEF4444);
  }

  // ✅ Responsive grid calculation
  int _getCrossAxisCount(double width) {
    if (width >= 1200) return 4; // Desktop
    if (width >= 900) return 3; // Tablet landscape
    if (width >= 600) return 2; // Tablet portrait
    return 2; // Mobile
  }

  double _getChildAspectRatio(double width) {
    if (width >= 1200) return 0.90; // Desktop
    if (width >= 900) return 0.88; // Tablet landscape
    if (width >= 600) return 0.85; // Tablet portrait
    if (width >= 400) return 0.82; // Large phone
    return 0.78; // Small phone
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading profiles...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header with Custom Logo
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 20 : (isTablet ? 32 : 24),
                          vertical: isTablet ? 32 : 24,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: isTablet ? 48 : 40),

                            // ✅ Custom Logo (Replace with your logo.png)
                            Container(
                              width: isTablet ? 100 : 80,
                              height: isTablet ? 100 : 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withOpacity(0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/logo.png', // ✅ Your logo path
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
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(
                                        Icons.school_rounded,
                                        size: isTablet ? 50 : 40,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            SizedBox(height: isTablet ? 40 : 32),
                            Text(
                              'Choose Your Profile',
                              style: TextStyle(
                                fontSize: isTablet
                                    ? 36
                                    : (isSmallScreen ? 28 : 32),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: isTablet ? 16 : 12),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 40 : 0,
                              ),
                              child: Text(
                                'Continue your learning journey from where you left off',
                                style: TextStyle(
                                  fontSize: isTablet
                                      ? 18
                                      : (isSmallScreen ? 14 : 16),
                                  color: const Color(0xFF8B949E),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Responsive Profiles Grid
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : (isTablet ? 32 : 24),
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _getCrossAxisCount(screenWidth),
                          crossAxisSpacing: isTablet ? 20 : 16,
                          mainAxisSpacing: isTablet ? 20 : 16,
                          childAspectRatio: _getChildAspectRatio(screenWidth),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index < profiles.length) {
                            return _ProfileCard(
                              profile: profiles[index],
                              onTap: () => _onProfileSelect(profiles[index]),
                              timeAgo: _getTimeAgo(
                                profiles[index]['last_accessed'],
                              ),
                              gradeColor: _getGradeColor(
                                int.tryParse(
                                      profiles[index]['grade'].toString(),
                                    ) ??
                                    1,
                              ),
                              isTablet: isTablet,
                            );
                          } else {
                            return _AddProfileCard(
                              onTap: _onCreateProfile,
                              isTablet: isTablet,
                            );
                          }
                        }, childCount: profiles.length + 1),
                      ),
                    ),

                    // Footer
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 32 : 24),
                        child: Column(
                          children: [
                            SizedBox(height: isTablet ? 48 : 40),
                            GestureDetector(
                              onTap: _launchURL,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 32 : 24,
                                  vertical: isTablet ? 20 : 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF1A1D23),
                                      Color(0xFF0B0E13),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF30363D),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Powered by',
                                      style: TextStyle(
                                        fontSize: isTablet ? 14 : 12,
                                        color: Color(0xFF8B949E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // ✅ Your Logo
                                    Image.asset(
                                      'assets/images/logo_horizontal.png',
                                      height: isTablet ? 24 : 20,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            // Fallback text if logo not found
                                            return Text(
                                              'EasyLearn',
                                              style: TextStyle(
                                                fontSize: isTablet ? 14 : 12,
                                                color: Color(0xFF8B949E),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 24 : 16),
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

// ✅ Responsive Profile Card Widget
class _ProfileCard extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onTap;
  final String timeAgo;
  final Color gradeColor;
  final bool isTablet;

  const _ProfileCard({
    Key? key,
    required this.profile,
    required this.onTap,
    required this.timeAgo,
    required this.gradeColor,
    this.isTablet = false,
  }) : super(key: key);

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getCleanAvatar() {
    final avatar = widget.profile['avatar']?.toString() ?? '👤';
    if (avatar.contains('?') || avatar.isEmpty || avatar.length > 4) {
      return '👤';
    }
    return avatar;
  }

  @override
  Widget build(BuildContext context) {
    final isActive =
        widget.profile['is_active'] == 1 ||
        widget.profile['is_active'] == true ||
        widget.profile['is_active'] == '1';
    final totalProgress =
        double.tryParse(widget.profile['total_progress']?.toString() ?? '0') ??
        0.0;
    final completedChapters =
        int.tryParse(widget.profile['completed_chapters']?.toString() ?? '0') ??
        0;

    // Responsive sizing
    final double avatarSize = widget.isTablet ? 52 : 45;
    final double titleSize = widget.isTablet ? 18 : 16;
    final double subtitleSize = widget.isTablet ? 13 : 11;
    final double cardPadding = widget.isTablet ? 20 : 16;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              _animationController.forward();
              HapticFeedback.lightImpact();
            },
            onTapUp: (_) {
              _animationController.reverse();
            },
            onTapCancel: () {
              _animationController.reverse();
            },
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1D23), Color(0xFF21262D)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? widget.gradeColor : const Color(0xFF30363D),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  if (isActive)
                    BoxShadow(
                      color: widget.gradeColor.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Row(
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                widget.gradeColor,
                                widget.gradeColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: widget.gradeColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _getCleanAvatar(),
                              style: TextStyle(
                                fontSize: widget.isTablet ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isActive)
                          Container(
                            width: widget.isTablet ? 12 : 10,
                            height: widget.isTablet ? 12 : 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: widget.isTablet ? 16 : 12),

                    // Name
                    Text(
                      widget.profile['name']?.toString() ?? 'Student',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: widget.isTablet ? 6 : 4),

                    // Grade & Medium
                    Text(
                      'Class ${widget.profile['grade'] ?? '-'} • ${widget.profile['medium'] ?? '-'}',
                      style: TextStyle(
                        fontSize: subtitleSize,
                        color: const Color(0xFF8B949E),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: widget.isTablet ? 14 : 10),

                    // Progress Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: widget.isTablet ? 12 : 10,
                                color: const Color(0xFF8B949E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${totalProgress.toInt()}%',
                              style: TextStyle(
                                fontSize: widget.isTablet ? 12 : 10,
                                color: widget.gradeColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isTablet ? 6 : 4),
                        Container(
                          height: widget.isTablet ? 4 : 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF30363D),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: totalProgress / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.gradeColor,
                                    widget.gradeColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: widget.isTablet ? 12 : 8),

                    // Bottom Section
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$completedChapters Chapters',
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: widget.isTablet ? 16 : 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ✅ Responsive Add Profile Card Widget
class _AddProfileCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool isTablet;

  const _AddProfileCard({Key? key, required this.onTap, this.isTablet = false})
    : super(key: key);

  @override
  State<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends State<_AddProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    HapticFeedback.mediumImpact();
    await _animationController.forward();
    await _animationController.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.isTablet ? 64 : 56;
    final double iconInner = widget.isTablet ? 32 : 28;
    final double titleSize = widget.isTablet ? 18 : 16;
    final double subtitleSize = widget.isTablet ? 14 : 12;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1D23), Color(0xFF21262D)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF30363D), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isTablet ? 24 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF30363D),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFF8B949E), width: 2),
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: iconInner,
                      color: const Color(0xFF8B949E),
                    ),
                  ),
                ),
                SizedBox(height: widget.isTablet ? 18 : 14),
                Text(
                  'Add Profile',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: widget.isTablet ? 6 : 4),
                Text(
                  'Create new learner',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: const Color(0xFF8B949E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
