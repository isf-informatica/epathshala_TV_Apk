import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'text_speech_page.dart';
import 'word_page.dart';
import 'sticky_notes_page.dart';
import 'exam_list_page.dart';
import 'lecture_schedule_page.dart';
import 'library_page.dart';
import '../screens/boards_page.dart';

class ToolsPage extends StatefulWidget {
  final Map<String, dynamic> loginData;
  const ToolsPage({Key? key, required this.loginData}) : super(key: key);
  @override
  _ToolsPageState createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  int _focusedIndex    = 0;
  int _sidebarNavIndex = 0;
  bool _sidebarFocused = false;
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  static const List<String> _navItems = [
    'Courses', 'Exams', 'Video Conference', 'Library', 'Boards', 'Tools',
  ];

  late final List<_ToolItem> _tools;

  @override
  void initState() {
    super.initState();
    _tools = [
      _ToolItem(title: 'Text & Speech', description: 'Convert text to speech with AI technology.', icon: Icons.record_voice_over_rounded, color: const Color(0xFF3B82F6), buttonLabel: 'Open Tool', buttonIcon: Icons.open_in_new_rounded, onTap: () => _navigate(TextSpeechPage(loginData: widget.loginData))),
      _ToolItem(title: 'Word', description: 'Create, edit, and manage Word documents.', icon: Icons.description_rounded, color: const Color(0xFF1D4ED8), buttonLabel: 'Open Editor', buttonIcon: Icons.edit_rounded, onTap: () => _navigate(WordPage(loginData: widget.loginData))),
      _ToolItem(title: 'Sticky Notes', description: 'Create quick notes and reminders.', icon: Icons.sticky_note_2_rounded, color: const Color(0xFFF59E0B), buttonLabel: 'Create Notes', buttonIcon: Icons.note_add_rounded, onTap: () => _navigate(StickyNotesPage(loginData: widget.loginData))),
    ];
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _fadeAnimation  = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() { _fadeController.dispose(); super.dispose(); }

  void _navigate(Widget page) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ));
  }

  void _executeSidebarNavItem(String label) {
    if (label == 'Tools') { setState(() => _sidebarFocused = false); return; }
    if (label == 'Courses') { Navigator.pop(context); return; }
    Widget? page;
    if (label == 'Exams') page = ExamListPage(loginData: widget.loginData);
    if (label == 'Video Conference') page = LectureSchedulePage(loginData: widget.loginData);
    if (label == 'Library') page = LibraryPage(
      regId: widget.loginData['reg_id']?.toString() ?? '',
      permissions: widget.loginData['permissions']?.toString() ?? 'Student',
      loginData: widget.loginData,
    );
    if (label == 'Boards') page = BoardsPage(loginData: widget.loginData);
    if (page != null) {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => page!,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
      if (!_sidebarFocused) { setState(() => _sidebarFocused = true); } else { Navigator.maybePop(context); }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.gameButtonA) {
      if (_sidebarFocused) { _executeSidebarNavItem(_navItems[_sidebarNavIndex]); } else { _tools[_focusedIndex].onTap?.call(); }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_sidebarFocused) { if (_focusedIndex % 3 == 0) { setState(() => _sidebarFocused = true); } else { setState(() => _focusedIndex--); } }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_sidebarFocused) { setState(() => _sidebarFocused = false); } else { setState(() => _focusedIndex = (_focusedIndex + 1).clamp(0, _tools.length - 1)); }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarFocused) { if (_sidebarNavIndex > 0) setState(() => _sidebarNavIndex--); } else { setState(() => _focusedIndex = (_focusedIndex - 3).clamp(0, _tools.length - 1)); }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarFocused) { if (_sidebarNavIndex < _navItems.length - 1) setState(() => _sidebarNavIndex++); } else { setState(() => _focusedIndex = (_focusedIndex + 3).clamp(0, _tools.length - 1)); }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(sw),
              Expanded(
                child: Column(children: [
                  _buildHeader(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: 1.1),
                        itemCount: _tools.length,
                        itemBuilder: (_, i) => _buildCard(i),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(double sw) {
    final w = sw < 600 ? 180.0 : 240.0;
    return SizedBox(
      width: w,
      child: Stack(children: [
        Container(
          width: w,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A0800), Color(0xFF3A1200)]),
            borderRadius: BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(4, 0))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: EdgeInsets.fromLTRB(sw < 600 ? 8 : 14, sw < 600 ? 8 : 14, sw < 600 ? 8 : 14, 10),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: sw < 600 ? 6 : 10, horizontal: sw < 600 ? 6 : 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8F5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBF360C).withOpacity(0.3), width: 1.5)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/logo_easylearn.png', height: sw < 600 ? 36 : 50, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.school, color: const Color(0xFFBF360C), size: sw < 600 ? 30 : 42)),
                    const SizedBox(height: 4),
                    Text('EASY LEARN', style: TextStyle(color: const Color(0xFFBF360C), fontSize: sw < 600 ? 9 : 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    Text('EDUCATION FOR ALL', style: TextStyle(color: const Color(0xFFBF7060), fontSize: sw < 600 ? 6 : 7.5, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _navItems.asMap().entries.map((entry) {
                    final navIdx  = entry.key;
                    final label   = entry.value;
                    final isActive  = label == 'Tools';
                    final isFocus   = _sidebarFocused && navIdx == _sidebarNavIndex;
                    return GestureDetector(
                      onTap: () => _executeSidebarNavItem(label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: sw < 600 ? 10 : 20, vertical: isFocus ? 6 : 4),
                        decoration: BoxDecoration(
                          color: isFocus ? Colors.white.withOpacity(0.10) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isFocus ? Colors.white38 : Colors.transparent, width: 1.5),
                        ),
                        child: Row(children: [
                          Container(width: isFocus ? 12 : 10, height: isFocus ? 12 : 10,
                              decoration: BoxDecoration(color: isActive ? const Color(0xFFBF360C) : isFocus ? Colors.white : Colors.white60, borderRadius: BorderRadius.circular(2))),
                          SizedBox(width: sw < 600 ? 6 : 12),
                          Expanded(child: Text(label, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isActive ? const Color(0xFFBF360C) : isFocus ? Colors.white : Colors.white70,
                                  fontSize: sw < 600 ? (isFocus ? 14 : 13) : (isFocus ? 20 : 19),
                                  fontWeight: (isActive || isFocus) ? FontWeight.w700 : FontWeight.w400))),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]),
        ),
        Positioned(right: 0, top: 0, bottom: 0,
            child: Container(width: 5,
                decoration: const BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFBF360C), Colors.transparent],
                  stops: [0.0, 0.15, 0.5, 0.85, 1.0],
                )))),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF6D00)]),
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.build_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 14),
        const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tools', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Select a tool to get started', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _buildCard(int index) {
    final tool      = _tools[index];
    final isFocused = !_sidebarFocused && _focusedIndex == index;
    return GestureDetector(
      onTap: () { setState(() { _focusedIndex = index; _sidebarFocused = false; }); tool.onTap?.call(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isFocused ? const Color(0xFFBF360C) : const Color(0xFFE8D5CC), width: isFocused ? 5.0 : 1.5),
          boxShadow: isFocused ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.6), blurRadius: 28, spreadRadius: 4)] : [const BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFFFF3EE),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: tool.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: tool.color.withOpacity(0.3))),
                  child: Icon(tool.icon, color: tool.color, size: 24)),
              const SizedBox(height: 12),
              Text(tool.title, style: TextStyle(color: isFocused ? const Color(0xFFBF360C) : const Color(0xFF3E1000), fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(child: Text(tool.description, style: const TextStyle(color: Color(0xFF7A4030), fontSize: 12, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis)),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isFocused ? const Color(0xFFBF360C) : const Color(0xFFBF360C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBF360C).withOpacity(isFocused ? 1.0 : 0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(tool.buttonIcon, color: isFocused ? Colors.white : const Color(0xFFBF360C), size: 14),
                  const SizedBox(width: 6),
                  Text(tool.buttonLabel, style: TextStyle(color: isFocused ? Colors.white : const Color(0xFFBF360C), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final String title, description, buttonLabel;
  final IconData icon, buttonIcon;
  final Color color;
  final VoidCallback? onTap;
  const _ToolItem({required this.title, required this.description, required this.icon, required this.color, required this.buttonLabel, required this.buttonIcon, required this.onTap});
}