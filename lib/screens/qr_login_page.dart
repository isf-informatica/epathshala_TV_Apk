// screens/qr_login_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'filter_page.dart';

class QrLoginPage extends StatefulWidget {
  final Function(String email, String password) onLoginComplete;
  const QrLoginPage({Key? key, required this.onLoginComplete}) : super(key: key);

  @override
  State<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends State<QrLoginPage> with SingleTickerProviderStateMixin {
  static const String _base = 'https://k12.easylearn.org.in/Easylearn/Course_Controller';

  String? _token;
  String? _qrUrl;
  bool _loading = true;
  bool _expired = false;
  bool _showSuccess = false;
  String _successEmail = '';
  Timer? _pollTimer;
  Timer? _expireTimer;
  Timer? _dotTimer;
  int _dots = 1;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _generateSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    _dotTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateSession() async {
    setState(() { _loading = true; _expired = false; _showSuccess = false; });
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    try {
      final res = await http.post(Uri.parse('$_base/generate_tv_session'));
      final data = jsonDecode(res.body);
      if (data['Response'] == 'OK') {
        final token = data['token'];
        setState(() {
          _token = token;
          _qrUrl = '$_base/tv_login_web/$token';
          _loading = false;
        });
        _startPolling();
        _startExpireTimer();
        _startDotAnimation();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_token == null) return;
      try {
        final res = await http.post(
          Uri.parse('$_base/check_tv_login'),
          body: {'token': _token!},
        );
        final data = jsonDecode(res.body);
        if (data['Response'] == 'OK' && data['data']['status'] == 'logged_in') {
          _pollTimer?.cancel();
          _expireTimer?.cancel();
          _dotTimer?.cancel();
          final email = data['data']['email'] ?? '';
          _showSuccessScreen(email);
        }
      } catch (_) {}
    });
  }

  void _showSuccessScreen(String email) {
    setState(() {
      _showSuccess = true;
      _successEmail = email;
    });
    _animController.forward();

    // ✅ Navigate to CreateProfilePage after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FilterPage(
            profile: {'email': email},
          ),
        ),
      );
    });
  }

  void _startExpireTimer() {
    _expireTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !_showSuccess) {
        setState(() => _expired = true);
        _pollTimer?.cancel();
        _dotTimer?.cancel();
      }
    });
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dots = (_dots % 3) + 1);
    });
  }

  @override
  Widget build(BuildContext context) {

    // ── SUCCESS SCREEN ──
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        body: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Green tick
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4ADE80), width: 3),
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF4ADE80), size: 64),
                  ),
                  const SizedBox(height: 28),

                  // ✅ Login Success screen
                  const Text(
                    '🎉 Login Successful!',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Logged in via QR Code!\nOpening your profile page...',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Email badge
                  if (_successEmail.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2333),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        _successEmail,
                        style: const TextStyle(
                          color: Color(0xFF4F9EF8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Progress bar — 2 seconds
                  Column(
                    children: [
                      const Text(
                        'Redirecting to profile...',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 220,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 2),
                          builder: (_, val, __) => LinearProgressIndicator(
                            value: val,
                            backgroundColor: Colors.white12,
                            color: const Color(0xFF4ADE80),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── NORMAL QR SCREEN ──
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign in to EasyLearn',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan the QR code with your phone',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                if (_loading)
                  const SizedBox(
                    width: 240, height: 240,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                  )
                else if (_expired)
                  _buildExpiredState()
                else if (_qrUrl != null)
                  _buildQrState(),

                const SizedBox(height: 32),
                if (!_loading && !_expired && _qrUrl != null) _buildWaitingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredState() {
    return Column(
      children: [
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.qr_code, size: 80, color: Colors.white24),
              SizedBox(height: 12),
              Text('QR Code Expired', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _generateSession,
          icon: const Icon(Icons.refresh),
          label: const Text('Generate New QR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildQrState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.4),
              blurRadius: 30, spreadRadius: 2,
            )],
          ),
          child: QrImageView(
            data: _qrUrl!,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: [
            _step('1', 'Scan the QR code with your phone'),
            const SizedBox(height: 10),
            _step('2', 'Enter your email and password'),
            const SizedBox(height: 10),
            _step('3', 'Your profile page will open here automatically'),
          ]),
        ),
        const SizedBox(height: 16),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.timer_outlined, size: 14, color: Colors.white38),
          SizedBox(width: 5),
          Text('QR code expires in 5 minutes', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _buildWaitingIndicator() {
    final dots = '.' * _dots;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F9EF8)),
          ),
          const SizedBox(width: 10),
          Text(
            'Waiting for login from your phone$dots',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ]),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _generateSession,
          child: const Text('🔄 Generate New QR', style: TextStyle(color: Color(0xFF4F9EF8), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _step(String num, String text) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(50),
        ),
        alignment: Alignment.center,
        child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
    ]);
  }
}