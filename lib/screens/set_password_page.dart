// screens/set_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class SetPasswordPage extends StatefulWidget {
  final String email;
  final bool isNewUser;
  final Function(String email, String password) onPasswordSet; // FIX: password bhi pass karo

  const SetPasswordPage({
    Key? key,
    required this.email,
    required this.isNewUser,
    required this.onPasswordSet,
  }) : super(key: key);

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> with TickerProviderStateMixin {
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();

  bool    isLoading  = false;
  String? error;

  // TV focus: pass | confirm | submit
  String _focus = 'pass';

  // Keyboard
  bool _kbOpen    = false;
  bool _kbForConf = false; // false = new pass, true = confirm pass
  bool _capsLock  = false;
  bool _numMode   = false;
  int  _kbRow = 0, _kbCol = 0;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  static const _alpha = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['⇧','z','x','c','v','b','n','m','⌫'],
    ['123','@','.','_','-','SPACE','✓'],
  ];
  static const _nums = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['!','@','#',r'$','%','&','*','-','_','.'],
    ['⌫'],
    ['ABC','SPACE','✓'],
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _scrollCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _openKeyboard({required bool forConf}) {
    setState(() {
      _kbOpen = true; _kbForConf = forConf;
      _kbRow  = 0;   _kbCol    = 0;
      _numMode = false;
      _focus   = forConf ? 'confirm' : 'pass';
    });
    _slideCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(forConf ? 260.0 : 100.0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _closeKeyboard({bool next = false}) {
    _slideCtrl.reverse().then((_) => setState(() => _kbOpen = false));
    if (next && !_kbForConf) setState(() => _focus = 'confirm');
  }

  Future<void> _setPassword() async {
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.length < 6) { setState(() => error = 'Password must be at least 6 characters'); return; }
    if (pass != confirm)  { setState(() => error = 'Passwords do not match'); return; }
    setState(() { isLoading = true; error = null; });
    final success = await ApiService.setPassword(widget.email, pass);
    setState(() => isLoading = false);
    if (success) {
      widget.onPasswordSet(widget.email, pass); // FIX: pass bhi bhejo
    } else {
      setState(() => error = 'Failed to set password. Please try again.');
    }
  }

  void _tapKey(String key) {
    final ctrl = _kbForConf ? _confirmCtrl : _passCtrl;
    final text = ctrl.text;
    final pos  = ctrl.selection.baseOffset < 0 ? text.length : ctrl.selection.baseOffset;
    setState(() {
      error = null;
      switch (key) {
        case '⌫':
          if (pos > 0) ctrl.value = TextEditingValue(
            text: text.substring(0, pos - 1) + text.substring(pos),
            selection: TextSelection.collapsed(offset: pos - 1));
          break;
        case 'SPACE':
          final t = '${text.substring(0, pos)} ${text.substring(pos)}';
          ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
          break;
        case '⇧':   _capsLock = !_capsLock; break;
        case '123':  _numMode = true;  break;
        case 'ABC':  _numMode = false; break;
        case '✓':    _closeKeyboard(next: true); break;
        default:
          final char = _capsLock ? key.toUpperCase() : key;
          final t = text.substring(0, pos) + char + text.substring(pos);
          ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
      }
    });
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (_kbOpen) {
      final layout = _numMode ? _nums : _alpha;
      if (k == LogicalKeyboardKey.arrowUp)    { setState(() => _kbRow = (_kbRow - 1).clamp(0, layout.length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowDown)  { setState(() => _kbRow = (_kbRow + 1).clamp(0, layout.length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowLeft)  { setState(() => _kbCol = (_kbCol - 1).clamp(0, layout[_kbRow].length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowRight) { setState(() => _kbCol = (_kbCol + 1).clamp(0, layout[_kbRow].length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) { _tapKey(layout[_kbRow][_kbCol]); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) { _closeKeyboard(); return KeyEventResult.handled; }
      return KeyEventResult.handled;
    }

    const order = ['pass', 'confirm', 'submit'];
    final idx = order.indexOf(_focus);
    if (k == LogicalKeyboardKey.arrowDown && idx < order.length - 1) { setState(() => _focus = order[idx + 1]); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowUp   && idx > 0)                { setState(() => _focus = order[idx - 1]); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      switch (_focus) {
        case 'pass':    _openKeyboard(forConf: false); break;
        case 'confirm': _openKeyboard(forConf: true);  break;
        case 'submit':  _setPassword(); break;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _onKey(e),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36),

                    // Icon + title
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2333),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3), width: 2),
                          boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.2), blurRadius: 20)],
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF4F46E5), size: 34),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text(
                      widget.isNewUser ? 'Set Your Password' : 'Reset Password',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    )),
                    const SizedBox(height: 6),
                    Center(child: Text(widget.email, style: const TextStyle(color: Color(0xFF4F9EF8), fontSize: 13))),
                    const SizedBox(height: 24),

                    // Hint box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2333),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, color: Colors.white38, size: 16),
                        SizedBox(width: 10),
                        Expanded(child: Text('Minimum 6 characters. Use a mix of letters and numbers.', style: TextStyle(color: Colors.white38, fontSize: 12))),
                      ]),
                    ),
                    const SizedBox(height: 22),

                    // New Password field
                    const Text('New Password', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _TvPassField(
                      controller: _passCtrl, hint: 'Enter password',
                      isFocused: _focus == 'pass', kbOpen: _kbOpen && !_kbForConf,
                      onTap: () => _openKeyboard(forConf: false),
                    ),
                    const SizedBox(height: 18),

                    // Confirm Password field
                    const Text('Confirm Password', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _TvPassField(
                      controller: _confirmCtrl, hint: 'Re-enter your password',
                      isFocused: _focus == 'confirm', kbOpen: _kbOpen && _kbForConf,
                      onTap: () => _openKeyboard(forConf: true),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Submit button
                    GestureDetector(
                      onTap: () { setState(() => _focus = 'submit'); _setPassword(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _focus == 'submit' ? const Color(0xFF4F46E5) : const Color(0xFF4F46E5).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _focus == 'submit' ? const Color(0xFF818CF8) : Colors.transparent, width: 2),
                          boxShadow: _focus == 'submit' ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.5), blurRadius: 18)] : null,
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                widget.isNewUser ? 'Create Account' : 'Update Password',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.gamepad_outlined, size: 13, color: Colors.white24),
                      SizedBox(width: 6),
                      Text('D-pad to navigate · OK to type', style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ]),
                    const SizedBox(height: 280),
                  ],
                ),
              ),
            ),
          ),

          // Slide-up keyboard
          if (_kbOpen)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(position: _slideAnim, child: _buildKeyboard()),
            ),
        ]),
      ),
    );
  }

  Widget _buildKeyboard() {
    final layout = _numMode ? _nums : _alpha;
    final ctrl   = _kbForConf ? _confirmCtrl : _passCtrl;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.45))),
            child: Row(children: [
              const Icon(Icons.lock_outline, color: Color(0xFF4F46E5), size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: ctrl,
                  builder: (_, val, __) => Text(
                    val.text.isEmpty ? (_kbForConf ? 'Confirm password...' : 'New password...') : '•' * val.text.length,
                    style: TextStyle(color: val.text.isEmpty ? Colors.white30 : Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(width: 2, height: 18, color: const Color(0xFF4F46E5), margin: const EdgeInsets.only(left: 2, right: 12)),
              GestureDetector(
                onTap: () => _closeKeyboard(next: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          ...List.generate(layout.length, (rowIdx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(layout[rowIdx].length, (colIdx) {
                final key     = layout[rowIdx][colIdx];
                final focused = rowIdx == _kbRow && colIdx == _kbCol;
                final isWide  = key == 'SPACE';
                final isMed   = ['⌫','⇧','123','ABC','✓'].contains(key);
                final isDone  = key == '✓';
                return GestureDetector(
                  onTap: () { setState(() { _kbRow = rowIdx; _kbCol = colIdx; }); _tapKey(key); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    width: isWide ? 120 : isMed ? 58 : 42, height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: focused ? (isDone ? const Color(0xFF22C55E) : const Color(0xFF4F46E5))
                          : (key == '⇧' && _capsLock ? const Color(0xFF4F46E5).withOpacity(0.3) : isDone ? const Color(0xFF16A34A).withOpacity(0.5) : const Color(0xFF1E293B)),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: focused ? (isDone ? const Color(0xFF4ADE80) : const Color(0xFF818CF8)) : Colors.white.withOpacity(0.06), width: focused ? 2 : 1),
                      boxShadow: focused ? [BoxShadow(color: (isDone ? const Color(0xFF22C55E) : const Color(0xFF4F46E5)).withOpacity(0.5), blurRadius: 10)] : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key == 'SPACE' ? '␣' : ((_capsLock && key.length == 1) ? key.toUpperCase() : key),
                      style: TextStyle(color: focused ? Colors.white : Colors.white54, fontSize: key == 'SPACE' ? 16 : (isMed ? 12 : 14), fontWeight: focused ? FontWeight.bold : FontWeight.w400),
                    ),
                  ),
                );
              }),
            ),
          )),
        ],
      ),
    );
  }
}

// TV Password field (shows dots, no show/hide on TV)
class _TvPassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isFocused, kbOpen;
  final VoidCallback onTap;
  const _TvPassField({required this.controller, required this.hint, required this.isFocused, required this.kbOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = isFocused || kbOpen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E2640) : const Color(0xFF1C2333),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kbOpen ? const Color(0xFF4F46E5) : active ? const Color(0xFF4F46E5).withOpacity(0.7) : Colors.white.withOpacity(0.08), width: active ? 2 : 1),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.2), blurRadius: 12)] : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(Icons.lock_outline, color: active ? const Color(0xFF4F46E5) : Colors.white30, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, val, __) => Row(children: [
                Expanded(child: Text(
                  val.text.isEmpty ? hint : '•' * val.text.length,
                  style: TextStyle(color: val.text.isEmpty ? Colors.white30 : Colors.white, fontSize: 15, letterSpacing: val.text.isEmpty ? 0 : 2),
                  overflow: TextOverflow.ellipsis,
                )),
                if (kbOpen) Container(width: 2, height: 20, color: const Color(0xFF4F46E5), margin: const EdgeInsets.only(left: 2)),
              ]),
            ),
          ),
          if (active && !kbOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.15), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3))),
              child: const Text('OK', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}