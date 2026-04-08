// screens/signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'otp_verify_signup_page.dart';
import 'login_page.dart';
import 'qr_login_page.dart';

class SignupPage extends StatefulWidget {
  final Function(String email, String password) onSignupComplete;
  const SignupPage({Key? key, required this.onSignupComplete}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final _emailCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool    isLoading = false;
  String? errorMsg;
  String  _focus = 'email';

  bool _kbOpen   = false;
  bool _capsLock = false;
  bool _numMode  = false;
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
    _emailCtrl.dispose();
    _scrollCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _openKeyboard() {
    setState(() { _kbOpen = true; _kbRow = 0; _kbCol = 0; _numMode = false; _focus = 'email'; });
    _slideCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(60, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _closeKeyboard({bool next = false}) {
    _slideCtrl.reverse().then((_) => setState(() => _kbOpen = false));
    if (next) setState(() => _focus = 'sendOtp');
  }

  bool _isValidEmail(String e) => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) { setState(() => errorMsg = 'Please enter a valid email address'); return; }
    setState(() { isLoading = true; errorMsg = null; });
    final result = await ApiService.signupSendOtp(email, '');
    setState(() => isLoading = false);
    if (result != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpVerifySignupPage(email: email, isNewUser: result['is_new'] == true, onVerified: (e, p) => widget.onSignupComplete(e, p)),
      ));
    } else {
      setState(() => errorMsg = 'Failed to send OTP. Please try again.');
    }
  }

  void _tapKey(String key) {
    final text = _emailCtrl.text;
    final pos  = _emailCtrl.selection.baseOffset < 0 ? text.length : _emailCtrl.selection.baseOffset;
    setState(() {
      errorMsg = null;
      switch (key) {
        case '⌫':
          if (pos > 0) _emailCtrl.value = TextEditingValue(
            text: text.substring(0, pos - 1) + text.substring(pos),
            selection: TextSelection.collapsed(offset: pos - 1));
          break;
        case 'SPACE':
          final t = '${text.substring(0, pos)} ${text.substring(pos)}';
          _emailCtrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
          break;
        case '⇧':   _capsLock = !_capsLock; break;
        case '123':  _numMode = true;  break;
        case 'ABC':  _numMode = false; break;
        case '✓':    _closeKeyboard(next: true); break;
        default:
          final char = _capsLock ? key.toUpperCase() : key;
          final t = text.substring(0, pos) + char + text.substring(pos);
          _emailCtrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
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

    const order = ['email', 'sendOtp', 'qr', 'login'];
    final idx = order.indexOf(_focus);
    if (k == LogicalKeyboardKey.arrowDown && idx < order.length - 1) { setState(() => _focus = order[idx + 1]); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowUp   && idx > 0)                { setState(() => _focus = order[idx - 1]); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      switch (_focus) {
        case 'email':   _openKeyboard(); break;
        case 'sendOtp': _sendOtp(); break;
        case 'qr':      Navigator.push(context, MaterialPageRoute(builder: (_) => QrLoginPage(onLoginComplete: (e, [p = '']) => widget.onSignupComplete(e, p)))); break;
        case 'login':   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage(onLoginComplete: (e, p) => widget.onSignupComplete(e, p)))); break;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _onKey(e),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        resizeToAvoidBottomInset: false,
        body: Stack(children: [

          // ── Cinema background ──
          Positioned.fill(child: _CinemaBg()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.72),
                    Colors.black.withOpacity(0.50),
                    Colors.black.withOpacity(0.72),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 20, vertical: 32),
                  child: Center(
                    child: Container(
                      width: 460,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 48, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Center(
                            child: Container(
                              width: 68, height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 34, color: Color(0xFF14B8A6))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text('Create Account',
                              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          const Text('Welcome to EasyLearn! Enter your email to get started.',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 28),

                          const Text('EMAIL ADDRESS',
                              style: TextStyle(color: Color(0x73FFFFFF), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _GlassField(
                            controller: _emailCtrl, hint: 'name@example.com',
                            isPassword: false, isFocused: _focus == 'email',
                            kbOpen: _kbOpen,
                            onTap: _openKeyboard,
                          ),

                          if (errorMsg != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Send OTP button — teal gradient
                          GestureDetector(
                            onTap: isLoading ? null : () { setState(() => _focus = 'sendOtp'); _sendOtp(); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: _focus == 'sendOtp'
                                    ? Border.all(color: Colors.white.withOpacity(0.35), width: 1.5)
                                    : null,
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Send OTP',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Login with QR Code
                          GestureDetector(
                            onTap: () {
                              setState(() => _focus = 'qr');
                              Navigator.push(context, MaterialPageRoute(builder: (_) => QrLoginPage(onLoginComplete: (e, [p = '']) => widget.onSignupComplete(e, p))));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _focus == 'qr'
                                    ? Colors.white.withOpacity(0.11)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _focus == 'qr' ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.1),
                                  width: _focus == 'qr' ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.qr_code_scanner,
                                    color: _focus == 'qr' ? const Color(0xFF14B8A6) : Colors.white60, size: 18),
                                const SizedBox(width: 8),
                                Text('Login with QR Code',
                                    style: TextStyle(
                                        color: _focus == 'qr' ? Colors.white : Colors.white70,
                                        fontSize: 15, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 22),

                          const Row(children: [
                            Expanded(child: Divider(color: Colors.white12)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Already have an account?',
                                  style: TextStyle(color: Colors.white30, fontSize: 11, letterSpacing: 0.5)),
                            ),
                            Expanded(child: Divider(color: Colors.white12)),
                          ]),
                          const SizedBox(height: 14),

                          // Login Instead
                          GestureDetector(
                            onTap: () {
                              setState(() => _focus = 'login');
                              Navigator.pushReplacement(context, MaterialPageRoute(
                                  builder: (_) => LoginPage(onLoginComplete: (e, p) => widget.onSignupComplete(e, p))));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _focus == 'login'
                                    ? Colors.white.withOpacity(0.11)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _focus == 'login' ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.1),
                                  width: _focus == 'login' ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text('Sign in Instead',
                                  style: TextStyle(
                                      color: _focus == 'login' ? const Color(0xFF14B8A6) : Colors.white60,
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Center(
                            child: Text('By continuing, you agree to our Terms & Privacy Policy',
                                style: TextStyle(color: Colors.white24, fontSize: 11),
                                textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

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
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.45)),
            ),
            child: Row(children: [
              const Icon(Icons.email_outlined, color: Color(0xFF14B8A6), size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _emailCtrl,
                  builder: (_, val, __) => Text(
                    val.text.isEmpty ? 'Enter your email...' : val.text,
                    style: TextStyle(color: val.text.isEmpty ? Colors.white30 : Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(width: 2, height: 18, color: const Color(0xFF14B8A6), margin: const EdgeInsets.only(left: 2, right: 12)),
              GestureDetector(
                onTap: () => _closeKeyboard(next: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF14B8A6), borderRadius: BorderRadius.circular(6)),
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
                final key    = layout[rowIdx][colIdx];
                final focused = rowIdx == _kbRow && colIdx == _kbCol;
                final isWide = key == 'SPACE';
                final isMed  = ['⌫','⇧','123','ABC','✓'].contains(key);
                final isDone = key == '✓';
                return GestureDetector(
                  onTap: () { setState(() { _kbRow = rowIdx; _kbCol = colIdx; }); _tapKey(key); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    width: isWide ? 120 : isMed ? 58 : 42, height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: focused
                          ? (isDone ? const Color(0xFF22C55E) : const Color(0xFF14B8A6))
                          : (key == '⇧' && _capsLock
                              ? const Color(0xFF14B8A6).withOpacity(0.3)
                              : isDone ? const Color(0xFF16A34A).withOpacity(0.5) : const Color(0xFF1E293B)),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: focused ? (isDone ? const Color(0xFF4ADE80) : const Color(0xFF14B8A6)) : Colors.white.withOpacity(0.06),
                        width: focused ? 2 : 1,
                      ),
                      boxShadow: focused
                          ? [BoxShadow(color: (isDone ? const Color(0xFF22C55E) : const Color(0xFF14B8A6)).withOpacity(0.5), blurRadius: 10)]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key == 'SPACE' ? '␣' : ((_capsLock && key.length == 1) ? key.toUpperCase() : key),
                      style: TextStyle(
                        color: focused ? Colors.white : Colors.white.withOpacity(0.55),
                        fontSize: key == 'SPACE' ? 16 : (isMed ? 12 : 14),
                        fontWeight: focused ? FontWeight.bold : FontWeight.w400,
                      ),
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

// Shared background widget
class _CinemaBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1117), Color(0xFF0F1724), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, childAspectRatio: 0.65),
        itemCount: 36,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: [
              const Color(0xFF1A1035), const Color(0xFF0F2030), const Color(0xFF1C1A10),
              const Color(0xFF101820), const Color(0xFF1A0E1A), const Color(0xFF0C1C10),
            ][i % 6].withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}

// Shared glass input field widget
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPassword, isFocused, kbOpen;
  final VoidCallback onTap;

  const _GlassField({
    required this.controller, required this.hint,
    required this.isPassword, required this.isFocused,
    required this.kbOpen, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = isFocused || kbOpen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: kbOpen
                ? const Color(0xFF14B8A6).withOpacity(0.9)
                : active ? const Color(0xFF14B8A6).withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: active ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, val, __) {
            final display = isPassword
                ? (val.text.isEmpty ? hint : '•' * val.text.length)
                : (val.text.isEmpty ? hint : val.text);
            return Row(children: [
              Expanded(
                child: Text(display,
                  style: TextStyle(color: val.text.isEmpty ? Colors.white30 : Colors.white, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
              ),
              if (kbOpen)
                Container(width: 2, height: 18, color: const Color(0xFF14B8A6), margin: const EdgeInsets.only(left: 4)),
            ]);
          },
        ),
      ),
    );
  }
}