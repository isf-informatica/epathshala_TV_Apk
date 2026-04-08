// screens/otp_verify_signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'set_password_page.dart';

class OtpVerifySignupPage extends StatefulWidget {
  final String email;
  final bool isNewUser;
  final Function(String email, String password) onVerified; // FIX: password bhi

  const OtpVerifySignupPage({
    Key? key,
    required this.email,
    required this.isNewUser,
    required this.onVerified,
  }) : super(key: key);

  @override
  State<OtpVerifySignupPage> createState() => _OtpVerifySignupPageState();
}

class _OtpVerifySignupPageState extends State<OtpVerifySignupPage> {
  String _otp        = '';
  bool   isVerifying = false;
  bool   isResending = false;
  String? error;

  int _kbRow = 0, _kbCol = 0;
  static const _rows = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['↩','0','⌫'],
  ];

  void _onNumPress(String val) {
    if (val == '⌫') {
      if (_otp.isNotEmpty) setState(() => _otp = _otp.substring(0, _otp.length - 1));
    } else if (val == '↩') {
      _resendOtp();
    } else if (_otp.length < 6) {
      setState(() { _otp += val; error = null; });
      if (_otp.length == 6) _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    setState(() { isVerifying = true; error = null; });
    final success = await ApiService.verifyOtp(widget.email, _otp, '');
    setState(() => isVerifying = false);
    if (success) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => SetPasswordPage(email: widget.email, isNewUser: widget.isNewUser, onPasswordSet: (e, p) => widget.onVerified(e, p)),
      ));
    } else {
      setState(() { error = 'Invalid OTP. Please try again.'; _otp = ''; });
    }
  }

  Future<void> _resendOtp() async {
    setState(() { isResending = true; error = null; _otp = ''; });
    final result = await ApiService.signupSendOtp(widget.email, '');
    setState(() => isResending = false);
    if (result == null) {
      setState(() => error = 'Failed to resend OTP. Please try again.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('OTP resent successfully!'), backgroundColor: Color(0xFF14B8A6),
      ));
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.arrowUp)    { setState(() => _kbRow = (_kbRow - 1).clamp(0, 3)); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowDown)  { setState(() => _kbRow = (_kbRow + 1).clamp(0, 3)); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowLeft)  { setState(() => _kbCol = (_kbCol - 1).clamp(0, 2)); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowRight) { setState(() => _kbCol = (_kbCol + 1).clamp(0, 2)); return KeyEventResult.handled; }

    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
      _onNumPress(_rows[_kbRow][_kbCol]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
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
        backgroundColor: const Color(0xFF0D2B55),
        resizeToAvoidBottomInset: false,
        body: Stack(children: [

          // Cinema background
          Positioned.fill(child: _CinemaBg()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D2B55).withOpacity(0.55),
                    const Color(0xFF0D2B55).withOpacity(0.30),
                    const Color(0xFF0D2B55).withOpacity(0.55),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: Container(
                    width: 460,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2B55).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 48, offset: const Offset(0, 20)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // Icon
                        Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.4), width: 2),
                            boxShadow: [BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.25), blurRadius: 20)],
                          ),
                          child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF14B8A6), size: 32),
                        ),
                        const SizedBox(height: 20),

                        const Text('Verify Your Email',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
                        const SizedBox(height: 8),
                        const Text('OTP sent to:',
                            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(widget.email,
                            style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 28),

                        // OTP boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) {
                            final filled    = i < _otp.length;
                            final isCurrent = i == _otp.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 48, height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: filled
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: filled
                                      ? const Color(0xFF14B8A6)
                                      : isCurrent
                                          ? const Color(0xFF14B8A6).withOpacity(0.5)
                                          : Colors.white.withOpacity(0.1),
                                  width: filled || isCurrent ? 2 : 1,
                                ),
                                boxShadow: filled
                                    ? [BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.25), blurRadius: 8)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: isVerifying && filled
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                                  : Text(
                                      filled ? '•' : '',
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                                    ),
                            );
                          }),
                        ),

                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Numpad
                        ...List.generate(_rows.length, (rowIdx) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (colIdx) {
                              final key         = _rows[rowIdx][colIdx];
                              final focused     = rowIdx == _kbRow && colIdx == _kbCol;
                              final isResendKey = key == '↩';
                              final isBackspace = key == '⌫';
                              return GestureDetector(
                                onTap: () { setState(() { _kbRow = rowIdx; _kbCol = colIdx; }); _onNumPress(key); },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 80),
                                  width: 88, height: 64,
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: focused
                                        ? (isResendKey ? const Color(0xFF0EA5E9) : const Color(0xFF14B8A6))
                                        : (isResendKey
                                            ? const Color(0xFF0EA5E9).withOpacity(0.12)
                                            : Colors.white.withOpacity(0.06)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: focused
                                          ? (isResendKey ? const Color(0xFF38BDF8) : const Color(0xFF14B8A6))
                                          : (isResendKey
                                              ? const Color(0xFF0EA5E9).withOpacity(0.35)
                                              : Colors.white.withOpacity(0.1)),
                                      width: focused ? 2 : 1,
                                    ),
                                    boxShadow: focused
                                        ? [BoxShadow(
                                            color: (isResendKey ? const Color(0xFF0EA5E9) : const Color(0xFF14B8A6)).withOpacity(0.4),
                                            blurRadius: 14)]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: isResendKey
                                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Icon(Icons.refresh_rounded,
                                              color: focused ? Colors.white : const Color(0xFF0EA5E9), size: 18),
                                          const SizedBox(height: 2),
                                          Text('Resend',
                                              style: TextStyle(
                                                  color: focused ? Colors.white : const Color(0xFF0EA5E9),
                                                  fontSize: 10, fontWeight: FontWeight.w600)),
                                        ])
                                      : Text(key,
                                          style: TextStyle(
                                            color: isBackspace
                                                ? Colors.white54
                                                : (focused ? Colors.white : Colors.white.withOpacity(0.87)),
                                            fontSize: isBackspace ? 22 : 26,
                                            fontWeight: FontWeight.w500,
                                          )),
                                ),
                              );
                            }),
                          ),
                        )),

                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          Icon(Icons.gamepad_outlined, size: 12, color: Colors.white24),
                          SizedBox(width: 6),
                          Text('Use D-pad to select · OK to confirm',
                              style: TextStyle(color: Colors.white24, fontSize: 12)),
                        ]),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('← Go Back',
                              style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// Shared background
class _CinemaBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2347), Color(0xFF0F3060), Color(0xFF0A2347)],
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
              const Color(0xFF0B2244), const Color(0xFF0C2A50), const Color(0xFF0D2B55),
              const Color(0xFF0A2040), const Color(0xFF0C2850), const Color(0xFF0B2448),
            ][i % 6].withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}