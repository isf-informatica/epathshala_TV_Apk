// screens/tv_login_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import 'filter_page.dart';

class TvLoginPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onProfileCreated;
  const TvLoginPage({Key? key, required this.onProfileCreated}) : super(key: key);

  @override
  State<TvLoginPage> createState() => _TvLoginPageState();
}

class _TvLoginPageState extends State<TvLoginPage> {
  String sessionToken = '';
  String qrUrl        = '';
  Timer? _pollingTimer;

  // ── OTP step toggle ──
  bool _otpStep   = false;
  String _otpValue = '';

  // ── Email input ──
  final TextEditingController _emailCtrl = TextEditingController();

  // ── Loading / error ──
  bool    isLoading = false;
  String? errorMsg;

  // ── TV focus: which element is highlighted ──
  // Possible values: 'email' | 'getOtp' | 'otp' | 'verify' | 'back'
  String _focus = 'email';

  // ── On-screen keyboard ──
  bool _kbOpen    = false;
  bool _kbForOtp  = false;   // false = email keyboard, true = numpad
  bool _capsLock  = false;
  bool _numMode   = false;

  // Keyboard rows
  final _alpha = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['⇧','z','x','c','v','b','n','m','⌫'],
    ['123','@','.','_','-','SPACE','✓'],
  ];
  final _nums = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['!','@','#','\$','%','&','*','-','_','.'],
    ['⌫'],
    ['ABC','SPACE','✓'],
  ];
  int _kbRow = 0, _kbCol = 0;

  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _generateSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────
  Future<void> _generateSession() async {
    final token = await ApiService.generateTvSession();
    if (token != null && mounted) {
      setState(() {
        sessionToken = token;
        qrUrl = 'https://k12.easylearn.org.in/Easylearn/Course_Controller/tv_login_web/$token';
      });
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final result = await ApiService.checkTvLoginStatus(sessionToken);
      if (result != null && result['status'] == 'logged_in' && mounted) {
        timer.cancel();
        _goToFilter(result['email'] ?? '');
      }
    });
  }

  void _goToFilter(String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FilterPage(profile: {'email': email}),
      ),
    );
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => errorMsg = 'Please enter a valid email address');
      return;
    }
    setState(() { isLoading = true; errorMsg = null; });
    final success = await ApiService.sendOtp(email, sessionToken);
    setState(() => isLoading = false);

    if (success) {
      setState(() { _otpStep = true; _focus = 'otp'; });
    } else {
      setState(() => errorMsg = 'Failed to send OTP. Please try again.');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpValue.length != 6) {
      setState(() => errorMsg = 'Please enter the 6-digit OTP');
      return;
    }
    setState(() { isLoading = true; errorMsg = null; });
    final success = await ApiService.verifyOtp(_emailCtrl.text.trim(), _otpValue, sessionToken);
    setState(() => isLoading = false);

    if (success) {
      _pollingTimer?.cancel();
      _goToFilter(_emailCtrl.text.trim());
    } else {
      setState(() { errorMsg = 'Invalid OTP. Please try again.'; _otpValue = ''; });
    }
  }

  // ── D-pad handler ────────────────────────
  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    // ── If keyboard is open, keyboard handles navigation ──
    if (_kbOpen) {
      final layout = _kbForOtp ? null : (_numMode ? _nums : _alpha);

      if (_kbForOtp) {
        // Numpad: just accept number keys / OK
        if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
          // OK on numpad = close if 6 digits entered
          if (_otpValue.length == 6) setState(() => _kbOpen = false);
        }
        if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
          setState(() => _kbOpen = false);
        }
        return KeyEventResult.handled;
      }

      // Full keyboard navigation
      if (k == LogicalKeyboardKey.arrowUp)    { setState(() => _kbRow = (_kbRow - 1).clamp(0, layout!.length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowDown)  { setState(() => _kbRow = (_kbRow + 1).clamp(0, layout!.length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowLeft)  { setState(() => _kbCol = (_kbCol - 1).clamp(0, layout![_kbRow].length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowRight) { setState(() => _kbCol = (_kbCol + 1).clamp(0, layout![_kbRow].length - 1)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
        _tapKey(layout![_kbRow][_kbCol]);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        setState(() => _kbOpen = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // ── Main screen navigation ──
    final focusOrder = _otpStep
        ? ['otp', 'verify', 'back']
        : ['email', 'getOtp'];

    final idx = focusOrder.indexOf(_focus);

    if (k == LogicalKeyboardKey.arrowDown && idx < focusOrder.length - 1) {
      setState(() => _focus = focusOrder[idx + 1]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && idx > 0) {
      setState(() => _focus = focusOrder[idx - 1]);
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      if (_focus == 'email')   { setState(() { _kbOpen = true; _kbForOtp = false; _kbRow = 0; _kbCol = 0; }); return KeyEventResult.handled; }
      if (_focus == 'getOtp')  { _sendOtp(); return KeyEventResult.handled; }
      if (_focus == 'otp')     { setState(() { _kbOpen = true; _kbForOtp = true; }); return KeyEventResult.handled; }
      if (_focus == 'verify')  { _verifyOtp(); return KeyEventResult.handled; }
      if (_focus == 'back')    { setState(() { _otpStep = false; _otpValue = ''; _focus = 'email'; errorMsg = null; }); return KeyEventResult.handled; }
    }

    return KeyEventResult.ignored;
  }

  // ── Keyboard key press ───────────────────
  void _tapKey(String key) {
    final ctrl = _emailCtrl;
    final text = ctrl.text;
    final pos  = ctrl.selection.baseOffset < 0 ? text.length : ctrl.selection.baseOffset;

    setState(() {
      if (key == '⌫') {
        if (pos > 0) {
          ctrl.value = TextEditingValue(
            text: text.substring(0, pos - 1) + text.substring(pos),
            selection: TextSelection.collapsed(offset: pos - 1),
          );
        }
      } else if (key == 'SPACE') {
        final t = text.substring(0, pos) + ' ' + text.substring(pos);
        ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
      } else if (key == '⇧') {
        _capsLock = !_capsLock;
      } else if (key == '123') {
        _numMode = true;
      } else if (key == 'ABC') {
        _numMode = false;
      } else if (key == '✓') {
        _kbOpen = false;
      } else {
        final char = _capsLock ? key.toUpperCase() : key;
        final t = text.substring(0, pos) + char + text.substring(pos);
        ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: pos + 1));
      }
    });
  }

  void _tapNumpad(String key) {
    setState(() {
      if (key == '⌫' && _otpValue.isNotEmpty) {
        _otpValue = _otpValue.substring(0, _otpValue.length - 1);
      } else if (key == '✓') {
        _kbOpen = false;
      } else if (_otpValue.length < 6 && RegExp(r'\d').hasMatch(key)) {
        _otpValue += key;
        if (_otpValue.length == 6) _kbOpen = false;
      }
    });
  }

  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _onKey(event),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        body: Stack(
          children: [
            // ── Main layout ──
            Row(children: [
              _buildQrPanel(),
              Container(width: 1, color: Colors.white10),
              _buildLoginPanel(),
            ]),

            // ── On-screen keyboard overlay ──
            if (_kbOpen)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _kbForOtp ? _buildNumpad() : _buildKeyboard(),
              ),
          ],
        ),
      ),
    );
  }

  // ── LEFT: QR panel ───────────────────────
  Widget _buildQrPanel() {
    return Expanded(
      flex: 4,
      child: Container(
        color: const Color(0xFF0F1420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 34, color: Color(0xFF4F46E5))),
              ),
            ),
            const SizedBox(height: 16),
            const Text('EasyLearn', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Scan QR to sign in instantly', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 28),

            // QR
            if (qrUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 28)],
                ),
                child: QrImageView(data: qrUrl, size: 170, backgroundColor: Colors.white),
              )
            else
              const SizedBox(width: 170, height: 170,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))),

            const SizedBox(height: 16),
            const Text('Open phone camera and scan', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined, size: 12, color: Colors.white24),
              SizedBox(width: 4),
              Text('Refreshes every 5 minutes', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── RIGHT: Login panel ───────────────────
  Widget _buildLoginPanel() {
    return Expanded(
      flex: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otpStep ? 'Enter OTP' : 'Sign In with Email',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _otpStep
                  ? 'OTP sent to: ${_emailCtrl.text}'
                  : 'Enter your email address to receive an OTP',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 30),

            if (!_otpStep) ...[
              // Email field
              _buildFocusable(
                id: 'email',
                child: _buildEmailField(),
              ),
              const SizedBox(height: 16),
              // Send OTP button
              _buildFocusable(
                id: 'getOtp',
                child: _buildButton(
                  label: 'Send OTP',
                  isFocused: _focus == 'getOtp',
                  isLoading: isLoading,
                  onTap: _sendOtp,
                ),
              ),
            ] else ...[
              // OTP boxes
              _buildFocusable(
                id: 'otp',
                child: _buildOtpBoxes(),
              ),
              const SizedBox(height: 16),
              // Verify button
              _buildFocusable(
                id: 'verify',
                child: _buildButton(
                  label: 'Verify OTP',
                  isFocused: _focus == 'verify',
                  isLoading: isLoading,
                  onTap: _verifyOtp,
                ),
              ),
              const SizedBox(height: 10),
              // Go back button
              _buildFocusable(
                id: 'back',
                child: _buildButton(
                  label: '← Go Back',
                  isFocused: _focus == 'back',
                  isSecondary: true,
                  onTap: () => setState(() { _otpStep = false; _otpValue = ''; _focus = 'email'; errorMsg = null; }),
                ),
              ),
            ],

            // Error message
            if (errorMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 28),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.gamepad_outlined, size: 13, color: Colors.white24),
              SizedBox(width: 6),
              Text(
                'Use D-pad to navigate  ·  OK / Select to confirm',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Focusable wrapper ────────────────────
  Widget _buildFocusable({required String id, required Widget child}) {
    return GestureDetector(
      onTap: () {
        setState(() => _focus = id);
        if (id == 'email')  { setState(() { _kbOpen = true; _kbForOtp = false; _kbRow = 0; _kbCol = 0; }); }
        if (id == 'otp')    { setState(() { _kbOpen = true; _kbForOtp = true; }); }
        if (id == 'getOtp') _sendOtp();
        if (id == 'verify') _verifyOtp();
        if (id == 'back')   setState(() { _otpStep = false; _otpValue = ''; _focus = 'email'; errorMsg = null; });
      },
      child: child,
    );
  }

  // ── Email field ──────────────────────────
  Widget _buildEmailField() {
    final isFocused = _focus == 'email';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? const Color(0xFF4F46E5) : Colors.white12,
          width: isFocused ? 2.5 : 1,
        ),
        boxShadow: isFocused ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 12)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(Icons.email_outlined,
            color: isFocused ? const Color(0xFF4F46E5) : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _emailCtrl,
              builder: (_, val, __) => Text(
                val.text.isEmpty ? 'you@gmail.com' : val.text,
                style: TextStyle(
                  color: val.text.isEmpty ? Colors.white30 : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isFocused)
            const Text('Press OK to type',
              style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12)),
        ]),
      ),
    );
  }

  // ── OTP boxes ────────────────────────────
  Widget _buildOtpBoxes() {
    final isFocused = _focus == 'otp';
    return Row(
      children: List.generate(6, (i) {
        final filled = i < _otpValue.length;
        final isCurrent = i == _otpValue.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 54, height: 64,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled
                  ? const Color(0xFF4F46E5)
                  : isCurrent && isFocused
                      ? const Color(0xFF4F9EF8)
                      : Colors.white12,
              width: filled || (isCurrent && isFocused) ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            filled ? '•' : '',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        );
      }),
    );
  }

  // ── Generic button ───────────────────────
  Widget _buildButton({
    required String label,
    required bool isFocused,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isFocused
              ? (isSecondary ? const Color(0xFF1C2333) : const Color(0xFF4F46E5))
              : (isSecondary ? Colors.transparent : const Color(0xFF4F46E5).withOpacity(0.6)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused
                ? (isSecondary ? const Color(0xFF4F9EF8) : const Color(0xFF818CF8))
                : (isSecondary ? Colors.white24 : Colors.transparent),
            width: isFocused ? 2.5 : 1,
          ),
          boxShadow: isFocused && !isSecondary
              ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.5), blurRadius: 20)]
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label,
                style: TextStyle(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
      ),
    );
  }

  // ── Full QWERTY keyboard ─────────────────
  Widget _buildKeyboard() {
    final layout = _numMode ? _nums : _alpha;
    return Container(
      color: const Color(0xFF0B0E13),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _emailCtrl,
              builder: (_, val, __) => Text(
                val.text.isEmpty ? 'Type your email address' : val.text,
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _kbOpen = false),
              child: const Text('Done', style: TextStyle(color: Color(0xFF4F9EF8))),
            ),
          ]),
          const SizedBox(height: 6),

          // Key rows
          ...List.generate(layout.length, (rowIdx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: layout[rowIdx].map((key) {
                  final isFocused = rowIdx == _kbRow && layout[rowIdx].indexOf(key) == _kbCol;
                  final isWide  = key == 'SPACE';
                  final isMed   = ['⌫','⇧','123','ABC','✓'].contains(key);
                  return GestureDetector(
                    onTap: () {
                      setState(() { _kbRow = rowIdx; _kbCol = layout[rowIdx].indexOf(key); });
                      _tapKey(key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width:  isWide ? 110 : isMed ? 54 : 40,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? const Color(0xFF4F46E5)
                            : (key == '⇧' && _capsLock)
                                ? const Color(0xFF4F46E5).withOpacity(0.4)
                                : const Color(0xFF1C2333),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isFocused ? const Color(0xFF818CF8) : Colors.white12,
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (_capsLock && key.length == 1) ? key.toUpperCase() : key,
                        style: TextStyle(
                          color: isFocused ? Colors.white : Colors.white70,
                          fontSize: key == 'SPACE' ? 11 : 13,
                          fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Numpad for OTP ───────────────────────
  Widget _buildNumpad() {
    return Container(
      color: const Color(0xFF0B0E13),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Enter 6-digit OTP',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => setState(() => _kbOpen = false),
              child: const Text('Close', style: TextStyle(color: Color(0xFF4F9EF8))),
            ),
          ]),
          const SizedBox(height: 8),
          for (var row in [['1','2','3'],['4','5','6'],['7','8','9'],['⌫','0','✓']])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) => GestureDetector(
                  onTap: () => _tapNumpad(k),
                  child: Container(
                    width: 80, height: 62,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2333),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(k,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}