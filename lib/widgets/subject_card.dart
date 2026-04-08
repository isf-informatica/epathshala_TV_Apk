import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubjectCard extends StatefulWidget {
  final String subjectName;
  final List<dynamic> chapters;
  final IconData icon;
  final VoidCallback onTap;

  const SubjectCard({
    Key? key,
    required this.subjectName,
    required this.chapters,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard>
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

  Color _getSubjectColor(String subjectName) {
    final subject = subjectName.toLowerCase();
    if (subject.contains('math') || subject.contains('गणित')) {
      return const Color(0xFF3B82F6);
    } else if (subject.contains('science') || subject.contains('विज्ञान')) {
      return const Color(0xFF059669);
    } else if (subject.contains('english') || subject.contains('अंग्रेजी')) {
      return const Color(0xFF8B5CF6);
    } else if (subject.contains('hindi') || subject.contains('हिंदी')) {
      return const Color(0xFFDC2626);
    } else if (subject.contains('social') || subject.contains('सामाजिक')) {
      return const Color(0xFFEF4444);
    } else if (subject.contains('odia') || subject.contains('ଓଡ଼ିଆ')) {
      return const Color(0xFF059669);
    } else if (subject.contains('geography') || subject.contains('भूगोल')) {
      return const Color(0xFF10B981);
    } else if (subject.contains('history') || subject.contains('इतिहास')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF6366F1);
  }

  Color _getSubjectLightColor(String subjectName) {
    return _getSubjectColor(subjectName).withOpacity(0.15);
  }

  String _getSubjectCategory(String subjectName) {
    final subject = subjectName.toLowerCase();
    if (subject.contains('math') || subject.contains('गणित')) {
      return 'Mathematics';
    } else if (subject.contains('science') || subject.contains('विज्ञान')) {
      return 'Science';
    } else if (subject.contains('english') || subject.contains('अंग्रेजी')) {
      return 'Language';
    } else if (subject.contains('hindi') || subject.contains('हिंदी')) {
      return 'Language';
    } else if (subject.contains('social') || subject.contains('सामाजिक')) {
      return 'Social Studies';
    } else if (subject.contains('odia') || subject.contains('ଓଡ଼ିଆ')) {
      return 'Language';
    } else if (subject.contains('geography') || subject.contains('भूगोल')) {
      return 'Geography';
    } else if (subject.contains('history') || subject.contains('इतिहास')) {
      return 'History';
    }
    return 'Subject';
  }

  // Comprehensive responsive configuration
  Map<String, dynamic> _getResponsiveConfig(double width) {
    if (width >= 1200) {
      // Large Desktop
      return {
        'cardPadding': 20.0,
        'headerHeight': 72.0,
        'iconSize': 40.0,
        'borderRadius': 24.0,
        'contentSpacing': 18.0,
        'headerIconSize': 38.0,
        'badgeIconSize': 22.0,
        'titleFontSize': 18.0,
        'categoryFontSize': 14.0,
        'buttonHeight': 44.0,
        'buttonFontSize': 13.0,
        'buttonIconSize': 16.0,
        'minHeight': 200.0,
        'maxHeight': 240.0,
      };
    } else if (width >= 900) {
      // Tablet Landscape
      return {
        'cardPadding': 18.0,
        'headerHeight': 68.0,
        'iconSize': 36.0,
        'borderRadius': 22.0,
        'contentSpacing': 16.0,
        'headerIconSize': 36.0,
        'badgeIconSize': 20.0,
        'titleFontSize': 17.0,
        'categoryFontSize': 13.0,
        'buttonHeight': 42.0,
        'buttonFontSize': 12.5,
        'buttonIconSize': 15.0,
        'minHeight': 190.0,
        'maxHeight': 230.0,
      };
    } else if (width >= 600) {
      // Tablet Portrait
      return {
        'cardPadding': 16.0,
        'headerHeight': 65.0,
        'iconSize': 32.0,
        'borderRadius': 20.0,
        'contentSpacing': 14.0,
        'headerIconSize': 34.0,
        'badgeIconSize': 18.0,
        'titleFontSize': 16.0,
        'categoryFontSize': 12.0,
        'buttonHeight': 40.0,
        'buttonFontSize': 12.0,
        'buttonIconSize': 14.0,
        'minHeight': 180.0,
        'maxHeight': 220.0,
      };
    } else if (width >= 380) {
      // Regular Phone
      return {
        'cardPadding': 14.0,
        'headerHeight': 60.0,
        'iconSize': 30.0,
        'borderRadius': 20.0,
        'contentSpacing': 12.0,
        'headerIconSize': 32.0,
        'badgeIconSize': 18.0,
        'titleFontSize': 15.0,
        'categoryFontSize': 11.0,
        'buttonHeight': 38.0,
        'buttonFontSize': 11.0,
        'buttonIconSize': 13.0,
        'minHeight': 170.0,
        'maxHeight': 210.0,
      };
    } else if (width >= 320) {
      // Small Phone
      return {
        'cardPadding': 12.0,
        'headerHeight': 55.0,
        'iconSize': 28.0,
        'borderRadius': 18.0,
        'contentSpacing': 10.0,
        'headerIconSize': 30.0,
        'badgeIconSize': 16.0,
        'titleFontSize': 14.0,
        'categoryFontSize': 10.5,
        'buttonHeight': 36.0,
        'buttonFontSize': 10.5,
        'buttonIconSize': 12.0,
        'minHeight': 160.0,
        'maxHeight': 200.0,
      };
    } else {
      // Very Small Phone
      return {
        'cardPadding': 10.0,
        'headerHeight': 50.0,
        'iconSize': 26.0,
        'borderRadius': 16.0,
        'contentSpacing': 8.0,
        'headerIconSize': 28.0,
        'badgeIconSize': 15.0,
        'titleFontSize': 13.0,
        'categoryFontSize': 10.0,
        'buttonHeight': 32.0,
        'buttonFontSize': 10.0,
        'buttonIconSize': 11.0,
        'minHeight': 150.0,
        'maxHeight': 190.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final config = _getResponsiveConfig(screenWidth);

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
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
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
                  minHeight: config['minHeight'],
                  maxHeight: config['maxHeight'],
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(config['borderRadius']),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: _elevationAnimation.value * 1.5,
                      offset: Offset(0, _elevationAnimation.value * 0.3),
                    ),
                    if (_isHovered || _isPressed)
                      BoxShadow(
                        color: _getSubjectColor(
                          widget.subjectName,
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
                    borderRadius: BorderRadius.circular(config['borderRadius']),
                    border: Border.all(
                      color: (_isPressed || _isHovered)
                          ? _getSubjectColor(
                              widget.subjectName,
                            ).withOpacity(0.4)
                          : const Color(0xFF30363D),
                      width: (_isPressed || _isHovered) ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with category
                      Container(
                        height: config['headerHeight'],
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: config['cardPadding'],
                          vertical: config['cardPadding'] * 0.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getSubjectColor(widget.subjectName),
                              _getSubjectColor(
                                widget.subjectName,
                              ).withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              config['borderRadius'] - 1,
                            ),
                            topRight: Radius.circular(
                              config['borderRadius'] - 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: config['headerIconSize'],
                              height: config['headerIconSize'],
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                size: config['badgeIconSize'],
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: config['cardPadding'] * 0.6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getSubjectCategory(widget.subjectName),
                                    style: TextStyle(
                                      fontSize: config['categoryFontSize'],
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (screenWidth >= 320)
                                    Text(
                                      'Subject',
                                      style: TextStyle(
                                        fontSize:
                                            config['categoryFontSize'] * 0.85,
                                        color: Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: config['cardPadding'] * 0.6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.chapters.length}',
                                style: TextStyle(
                                  fontSize: config['categoryFontSize'] * 0.9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main content area
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(config['cardPadding']),
                          child: Column(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: config['iconSize'],
                                      height: config['iconSize'],
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            _getSubjectColor(
                                              widget.subjectName,
                                            ),
                                            _getSubjectColor(
                                              widget.subjectName,
                                            ).withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getSubjectColor(
                                              widget.subjectName,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        size: config['badgeIconSize'],
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(
                                      height: config['contentSpacing'] * 0.7,
                                    ),
                                    Flexible(
                                      child: Text(
                                        widget.subjectName,
                                        style: TextStyle(
                                          fontSize: config['titleFontSize'],
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (screenWidth >= 320) ...[
                                      SizedBox(
                                        height: config['contentSpacing'] * 0.4,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              config['cardPadding'] * 0.7,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getSubjectLightColor(
                                            widget.subjectName,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _getSubjectColor(
                                              widget.subjectName,
                                            ).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '${widget.chapters.length} Chapter${widget.chapters.length != 1 ? 's' : ''}',
                                          style: TextStyle(
                                            fontSize:
                                                config['categoryFontSize'] *
                                                0.9,
                                            fontWeight: FontWeight.w600,
                                            color: _getSubjectColor(
                                              widget.subjectName,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              SizedBox(height: config['contentSpacing']),

                              // Action button
                              SizedBox(
                                width: double.infinity,
                                height: config['buttonHeight'],
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
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !_isPressed
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.08,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
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
                                          size: config['buttonIconSize'],
                                          color: _getSubjectColor(
                                            widget.subjectName,
                                          ),
                                        ),
                                        SizedBox(
                                          width: config['cardPadding'] * 0.4,
                                        ),
                                        Flexible(
                                          child: Text(
                                            screenWidth < 320
                                                ? 'Start'
                                                : 'Start Learning',
                                            style: TextStyle(
                                              fontSize:
                                                  config['buttonFontSize'],
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0B0E13),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: config['cardPadding'] * 0.3,
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: config['buttonIconSize'] * 0.9,
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
}
