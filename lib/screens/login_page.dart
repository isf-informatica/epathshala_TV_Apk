// screens/login_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import 'signup_page.dart';
import 'otp_verify_signup_page.dart';
import 'filter_page.dart';
import 'qr_login_page.dart';
import 'subjects_page.dart';

class LoginPage extends StatefulWidget {
  final Function(String email, String password) onLoginComplete;
  const LoginPage({Key? key, required this.onLoginComplete}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool    isLoading = false;
  String? errorMsg;
  String  _focus = 'email';

  // Keyboard state
  bool _kbOpen    = false;
  bool _kbForPass = false;
  bool _capsLock  = false;
  bool _numMode   = false;
  int  _kbRow = 0, _kbCol = 0;

  // Last login (from previous logout session)
  Map<String, dynamic>? _lastLogin;

  // QR session
  String _sessionToken = '';
  String _qrUrl        = '';
  Timer? _pollingTimer;

  // Slide-up animation
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
    _generateQrSession();
    _loadLastLogin();
  }

  // ── Load last login credentials ─────────────────────────────
  Future<void> _loadLastLogin() async {
    final saved = await ApiService.getLastLogin();
    if (saved != null && mounted) {
      setState(() {
        _lastLogin = saved;
        _emailCtrl.text = saved['email'] ?? '';
        _passCtrl.text  = saved['password'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _scrollCtrl.dispose();
    _slideCtrl.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── QR session ──────────────────────────────────────────────
  Future<void> _generateQrSession() async {
    final token = await ApiService.generateTvSession();
    if (token != null && mounted) {
      setState(() {
        _sessionToken = token;
        _qrUrl = 'https://k12.easylearn.org.in/Easylearn/Course_Controller/tv_login_web/$token';
      });
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final result = await ApiService.checkTvLoginStatus(_sessionToken);
      if (result != null && result['status'] == 'logged_in' && mounted) {
        timer.cancel();
        _goToFilter(result['email'] ?? '');
      }
    });
  }

  // ── Keyboard ────────────────────────────────────────────────
  void _openKeyboard({required bool forPass}) {
    setState(() {
      _kbOpen = true; _kbForPass = forPass;
      _kbRow  = 0;    _kbCol    = 0;
      _focus  = forPass ? 'pass' : 'email';
      _numMode = false;
    });
    _slideCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(forPass ? 220.0 : 60.0,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _closeKeyboard({bool next = false}) {
    _slideCtrl.reverse().then((_) => setState(() => _kbOpen = false));
    if (next && !_kbForPass) {
      setState(() => _focus = 'pass');
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scrollCtrl.hasClients)
          _scrollCtrl.animateTo(220.0,
            duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      });
    }
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);

  void _goToFilter(String email, {dynamic id, String password = ''}) => Navigator.pushReplacement(context,
    MaterialPageRoute(builder: (_) => FilterPage(profile: {
      'email': email, 'password': password,
      if (id != null) 'id': id,
    })));

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (!_isValidEmail(email)) { setState(() => errorMsg = 'Please enter a valid email address'); return; }
    if (pass.isEmpty)          { setState(() => errorMsg = 'Please enter your password'); return; }
    setState(() { isLoading = true; errorMsg = null; });
    final result = await ApiService.loginWithPassword(email, pass);
    setState(() => isLoading = false);

    if (result == null) {
      setState(() => errorMsg = 'Incorrect email or password. Please try again.');
      return;
    }
    if (result['error'] == 'NO_PASSWORD') {
      _showNoPasswordDialog(email);
      return;
    }

    // ✅ Same email+password se login → directly SubjectsPage pe jao
    if (_lastLogin != null &&
        email.toLowerCase() == (_lastLogin!['email'] as String).toLowerCase() &&
        pass == _lastLogin!['password']) {
      final int grade       = _lastLogin!['grade'] as int;
      final List<String> mediums = (_lastLogin!['mediums'] as List).cast<String>();
      final String? partner = _lastLogin!['partner'] as String?;

      try {
        final loginResp = await ApiService.loginUser(grade);
        if (loginResp != null && mounted) {
          final courses = await ApiService.getEnrolledCoursesByPartner(
            loginResp['reg_id'],
            loginResp['classroom_id'],
            loginResp['id'],
            partner,
          );
          // loginData mein email + password bhi dalo taaki agli baar bhi save ho sake
          final Map<String, dynamic> loginDataWithCreds = {
            ...loginResp,
            'email':    email,
            'password': pass,
            'partner':  partner,
          };
          final allMediumCourses = mediums.map((m) => {'medium': m, 'courses': courses}).toList();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectsPage(
                grade:            grade,
                medium:           mediums.first,
                courses:          courses.cast<dynamic>(),
                loginData:        loginDataWithCreds,
                allMediumCourses: allMediumCourses,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        print('[login] same-user fast path error: $e — falling back to filter');
      }
    }

    // Different email ya password → normal filter flow
    _goToFilter(result['email'] ?? email, id: result['id'], password: pass);
  }

  Future<void> _forgotPassword([String? pre]) async {
    final email = pre ?? _emailCtrl.text.trim();
    if (!_isValidEmail(email)) { setState(() => errorMsg = 'Please enter your email address first'); return; }
    setState(() { isLoading = true; errorMsg = null; });
    final result = await ApiService.signupSendOtp(email, '');
    setState(() => isLoading = false);
    if (result != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpVerifySignupPage(email: email, isNewUser: false, onVerified: (e, p) => _goToFilter(e, password: p))));
    } else {
      setState(() => errorMsg = 'Failed to send OTP. Please try again.');
    }
  }

  void _onQrLoginComplete(String email, [String password = '']) async {
    setState(() { isLoading = true; errorMsg = null; });
    final result = await ApiService.signupSendOtp(email, '');
    setState(() => isLoading = false);
    if (result == null) { setState(() => errorMsg = 'QR login failed. Try again.'); return; }
    result['is_new'] == true ? _showSignupRequiredDialog(email) : _goToFilter(email);
  }

  void _showSignupRequiredDialog(String email) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C2333),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.person_add_outlined, color: Color(0xFF4F9EF8), size: 22),
        SizedBox(width: 10),
        Text('Sign Up Required', style: TextStyle(color: Colors.white, fontSize: 18)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('This email is not registered. Please sign up to continue.',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF0B0E13),
            borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
          child: Text(email, style: const TextStyle(color: Color(0xFF4F9EF8), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => OtpVerifySignupPage(email: email, isNewUser: true, onVerified: (e, p) => _goToFilter(e, password: p))));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Sign Up', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showNoPasswordDialog(String email) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C2333),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Password Not Set', style: TextStyle(color: Colors.white)),
      content: const Text('You signed up via OTP and have not set a password. Would you like to set one now?',
          style: TextStyle(color: Colors.white60, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); _forgotPassword(email); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
          child: const Text('Set Password', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── D-pad handler ────────────────────────────────────────────
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

    const order = ['email', 'pass', 'login', 'otp', 'signup'];
    final idx = order.indexOf(_focus);
    if (k == LogicalKeyboardKey.arrowDown && idx < order.length - 1) { setState(() => _focus = order[idx + 1]); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowUp   && idx > 0)                { setState(() => _focus = order[idx - 1]); return KeyEventResult.handled; }

    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      switch (_focus) {
        case 'email':  _openKeyboard(forPass: false); break;
        case 'pass':   _openKeyboard(forPass: true); break;
        case 'login':  _login(); break;
        case 'otp':
          Navigator.push(context, MaterialPageRoute(builder: (_) => QrLoginPage(onLoginComplete: _onQrLoginComplete)));
          break;
        case 'signup':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SignupPage(onSignupComplete: (e, p) => widget.onLoginComplete(e, p))));
          break;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _tapKey(String key) {
    final ctrl = _kbForPass ? _passCtrl : _emailCtrl;
    final text = ctrl.text;
    final pos  = ctrl.selection.baseOffset < 0 ? text.length : ctrl.selection.baseOffset;
    setState(() {
      errorMsg = null;
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
          final t    = text.substring(0, pos) + char + text.substring(pos);
          ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _onKey(e),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        resizeToAvoidBottomInset: false,
        body: Stack(children: [

          // ── Cinema tile background ──
          Positioned.fill(child: _CinemaBackground()),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSignInCard(),
                            const SizedBox(width: 20),
                            _buildQrCard(),
                          ],
                        )
                      : Column(children: [
                          _buildSignInCard(),
                          const SizedBox(height: 20),
                          _buildQrCard(),
                        ]),
                ),
              ),
            ),
          ),

          // ── Bottom-left EasyLearn branding ──
          Positioned(
            bottom: 24,
            left: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 22, color: Color(0xFF0D2B55))),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('EasyLearn',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                    Text('Education for All',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // ── Keyboard overlay ──
          if (_kbOpen)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(position: _slideAnim, child: _buildKeyboard()),
            ),
        ]),
      ),
    );
  }

  // ── Sign In Card ─────────────────────────────────────────────
  Widget _buildSignInCard() {
    return Container(
      width: 420,
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
          const Text('Sign in',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('Welcome back to EasyLearn',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 28),

          const Text('EMAIL ADDRESS',
              style: TextStyle(color: Color(0x73FFFFFF), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _GlassField(
            controller: _emailCtrl, hint: 'name@example.com',
            isPassword: false, isFocused: _focus == 'email',
            kbOpen: _kbOpen && !_kbForPass,
            onTap: () => _openKeyboard(forPass: false),
          ),
          const SizedBox(height: 20),

          const Text('PASSWORD',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _GlassField(
            controller: _passCtrl, hint: 'Your password',
            isPassword: true, isFocused: _focus == 'pass',
            kbOpen: _kbOpen && _kbForPass,
            onTap: () => _openKeyboard(forPass: true),
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

          // Sign in — teal gradient button
          GestureDetector(
            onTap: isLoading ? null : () { setState(() => _focus = 'login'); _login(); },
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
                border: _focus == 'login'
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
                  : const Text('Sign in',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),

          // OR CONTINUE WITH
          const Row(children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR CONTINUE WITH',
                  style: TextStyle(color: Colors.white30, fontSize: 11, letterSpacing: 0.8)),
            ),
            Expanded(child: Divider(color: Colors.white12)),
          ]),
          const SizedBox(height: 16),

          // Continue with Email OTP
          GestureDetector(
            onTap: () {
              setState(() => _focus = 'otp');
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => QrLoginPage(onLoginComplete: _onQrLoginComplete)));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _focus == 'otp'
                    ? Colors.white.withOpacity(0.11)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focus == 'otp'
                      ? Colors.white.withOpacity(0.28)
                      : Colors.white.withOpacity(0.1),
                  width: _focus == 'otp' ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Text('Continue with Email OTP',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),

          // Don't have an account
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _focus = 'signup');
                Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => SignupPage(onSignupComplete: (e, p) => widget.onLoginComplete(e, p))));
              },
              child: RichText(
                text: const TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                  children: [
                    TextSpan(
                      text: 'Create one',
                      style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── QR Card ──────────────────────────────────────────────────
  Widget _buildQrCard() {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B28).withOpacity(0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 36, offset: const Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF14B8A6), size: 22),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sign in with QR',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Text('Scan with your phone',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 20),

          // Real QR from session
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _qrUrl.isNotEmpty
                ? QrImageView(data: _qrUrl, size: 200, backgroundColor: Colors.white)
                : const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2.5),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          _qrStep('1', 'Open your phone camera'),
          const SizedBox(height: 8),
          _qrStep('2', 'Point at the QR code'),
          const SizedBox(height: 8),
          _qrStep('3', 'Complete sign-in on phone'),
          const SizedBox(height: 20),

          Row(children: [
            Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Waiting for scan',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ),
            GestureDetector(
              onTap: () {
                _pollingTimer?.cancel();
                setState(() { _sessionToken = ''; _qrUrl = ''; });
                _generateQrSession();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Text('Refresh',
                    style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _qrStep(String num, String label) {
    return Row(children: [
      Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
    ]);
  }

  // ── Keyboard ─────────────────────────────────────────────────
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
              Icon(_kbForPass ? Icons.lock_outline : Icons.email_outlined,
                color: const Color(0xFF14B8A6), size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _kbForPass ? _passCtrl : _emailCtrl,
                  builder: (_, val, __) {
                    final preview = _kbForPass ? '•' * val.text.length : val.text;
                    return Text(
                      preview.isEmpty ? (_kbForPass ? 'Enter your password...' : 'Enter your email...') : preview,
                      style: TextStyle(color: preview.isEmpty ? Colors.white30 : Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
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

// ── Cinema tile background ────────────────────────────────────
class _CinemaBackground extends StatelessWidget {
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, childAspectRatio: 0.65,
        ),
        itemCount: 36,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: [
              const Color(0xFF1A1035),
              const Color(0xFF0F2030),
              const Color(0xFF1C1A10),
              const Color(0xFF101820),
              const Color(0xFF1A0E1A),
              const Color(0xFF0C1C10),
            ][i % 6].withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}

// ── Glass Input Field ─────────────────────────────────────────
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
                : active
                    ? const Color(0xFF14B8A6).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
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