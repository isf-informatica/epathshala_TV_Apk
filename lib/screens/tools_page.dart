import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'text_speech_page.dart';
import 'word_page.dart';
import 'sticky_notes_page.dart';

class ToolsPage extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const ToolsPage({Key? key, required this.loginData}) : super(key: key);

  @override
  _ToolsPageState createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  int _focusedIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Tools list ───────────────────────────────────────────────
  late final List<_ToolItem> _tools;

  @override
  void initState() {
    super.initState();

    _tools = [
      _ToolItem(
        title: 'Text & Speech',
        description: 'Convert text to speech with AI technology.',
        icon: Icons.record_voice_over_rounded,
        color: const Color(0xFF3B82F6),
        buttonLabel: 'Open Tool',
        buttonIcon: Icons.open_in_new_rounded,
        onTap: () => _navigate(TextSpeechPage(loginData: widget.loginData)),
      ),
      _ToolItem(
        title: 'Word',
        description: 'Create, edit, and manage Word documents.',
        icon: Icons.description_rounded,
        color: const Color(0xFF1D4ED8),
        buttonLabel: 'Open Editor',
        buttonIcon: Icons.edit_rounded,
        onTap: () => _navigate(WordPage(loginData: widget.loginData)),
      ),
      _ToolItem(
        title: 'Sticky Notes',
        description: 'Create quick notes and reminders.',
        icon: Icons.sticky_note_2_rounded,
        color: const Color(0xFFF59E0B),
        buttonLabel: 'Create Notes',
        buttonIcon: Icons.note_add_rounded,
        onTap: () => _navigate(StickyNotesPage(loginData: widget.loginData)),
      )
    ];

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _navigate(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }


  // ── TV Key Handler ───────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    const cols = 5;
    final total = _tools.length;

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _focusedIndex = (_focusedIndex - 1).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = _focusedIndex + cols;
      setState(() => _focusedIndex = next.clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final prev = _focusedIndex - cols;
      setState(() => _focusedIndex = prev.clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      final tool = _tools[_focusedIndex];
      if (tool.onTap != null) {
        tool.onTap!();
      } else {
        _showComingSoon(tool.title);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — Coming Soon'),
        backgroundColor: const Color(0xFF1A2E55),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(28),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _tools.length,
                    itemBuilder: (context, index) => _buildCard(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF6D00)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x22000000))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Back', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFBF360C), Color(0xFFE64A19)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.build_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tools',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text('Select a tool to get started',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card ─────────────────────────────────────────────────────
  Widget _buildCard(int index) {
    final tool = _tools[index];
    final isFocused = _focusedIndex == index;
    final isAvailable = tool.onTap != null;

    return GestureDetector(
      onTap: () {
        setState(() => _focusedIndex = index);
        if (isAvailable) {
          tool.onTap!();
        } else {
          _showComingSoon(tool.title);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused ? const Color(0xFFBF360C) : const Color(0xFFE8D5CC),
            width: isFocused ? 2.5 : 1.5,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.35), blurRadius: 20, spreadRadius: 2)]
              : [const BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
          color: const Color(0xFFFFF8F5),
          child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: tool.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tool.color.withOpacity(0.3)),
                ),
                child: Icon(tool.icon, color: tool.color, size: 26),
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                tool.title,
                style: TextStyle(
                  color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              // Description
              Expanded(
                child: Text(
                  tool.description,
                  style: const TextStyle(
                    color: Color(0xFF7A4030),
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12),

              // Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isFocused && isAvailable
                      ? const Color(0xFFBF360C)
                      : isAvailable
                          ? const Color(0xFFBF360C).withOpacity(0.1)
                          : const Color(0xFFE8D5CC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAvailable
                        ? const Color(0xFFBF360C).withOpacity(isFocused ? 1.0 : 0.4)
                        : const Color(0xFFE8D5CC),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAvailable ? tool.buttonIcon : Icons.lock_outline_rounded,
                      color: isFocused && isAvailable
                          ? Colors.white
                          : isAvailable
                              ? const Color(0xFFBF360C)
                              : const Color(0xFF7A4030),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAvailable ? tool.buttonLabel : 'Coming Soon',
                      style: TextStyle(
                        color: isFocused && isAvailable
                            ? Colors.white
                            : isAvailable
                                ? const Color(0xFFBF360C)
                                : const Color(0xFF7A4030),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

// ── Tool data model ───────────────────────────────────────────
class _ToolItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onTap;

  const _ToolItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onTap,
  });
}