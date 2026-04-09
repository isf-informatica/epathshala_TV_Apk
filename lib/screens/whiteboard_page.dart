// lib/screens/whiteboard_page.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// iframe_helper: web pe "New Tab" button ke liye sirf openInNewTab() use hota hai
import 'whiteboard_iframe_web.dart'
    if (dart.library.io) 'whiteboard_iframe_stub.dart' as iframe_helper;

/// WhiteboardPage — Kotlin WhiteBoardActivity jaisi offline support
///
/// • Android / TV  → whiteboard.html LOCAL asset se load hoti hai
///                   Bilkul Kotlin ke loadUrl("file:///android_asset/whiteboard.html") jaisa
/// • Web (Chrome)  → webview_flutter_web se LOCAL asset load hoti hai
///                   'assets/html/whiteboard.html' — internet nahi chahiye
///                   ✅ Fix: Pehle HtmlElementView + iframe tha → 404 de raha tha
///
/// pubspec.yaml mein add karo:
///   flutter:
///     assets:
///       - assets/html/whiteboard.html
///
/// File rakhna:  your_project/assets/html/whiteboard.html

class WhiteboardPage extends StatefulWidget {
  final String? overrideUrl;
  const WhiteboardPage({Key? key, this.overrideUrl}) : super(key: key);

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {

  // Android: flutter_assets folder mein hoti hain — Kotlin jaisa
  static const String _androidAssetUrl =
      'file:///android_asset/flutter_assets/assets/html/whiteboard.html';

  // ✅ FIX: Web pe bhi local asset use karo
  // Flutter web dev server mein assets directly "assets/html/..." pe milti hain
  // Pehle yahan 'https://k12.easylearn.org.in/whiteboard_1' tha — jo 404 de raha tha
  static const String _webAssetUrl =
      'assets/html/whiteboard.html';

  late final String _whiteboardUrl;

  WebViewController? _ctrl;
  bool _loading = true;
  bool _hasError = false;
  String _errMsg = '';
  int _progress = 0;

  bool _showToolbar = true;
  Timer? _toolbarTimer;
  late final String _iframeId;

  @override
  void initState() {
    super.initState();
    _iframeId = 'wb-${DateTime.now().millisecondsSinceEpoch}';

    if (widget.overrideUrl != null) {
      _whiteboardUrl = widget.overrideUrl!;
    } else if (kIsWeb) {
      _whiteboardUrl = _webAssetUrl;
    } else if (Platform.isAndroid) {
      _whiteboardUrl = _androidAssetUrl;
    } else {
      _whiteboardUrl = _webAssetUrl;
    }

    if (kIsWeb) {
      // ✅ Web pe iframe — webview_flutter_web setJavaScriptMode support nahi karta
      iframe_helper.registerIframe(_iframeId, _whiteboardUrl);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      // ✅ Android / TV pe full WebViewController
      _initWebView();
    }
  }

  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A0800))
      ..enableZoom(true)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _hasError = false; });
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          _resetTimer();
          _injectTvKeys();
        },
        onWebResourceError: (e) {
          if (mounted) setState(() {
            _loading = false; _hasError = true; _errMsg = e.description;
          });
        },
        onNavigationRequest: (_) => NavigationDecision.navigate,
      ))
      ..setOnJavaScriptAlertDialog((JavaScriptAlertDialogRequest r) async {
        await _showAlertDialog(r.message);
      })
      ..setOnJavaScriptConfirmDialog((JavaScriptConfirmDialogRequest r) async {
        return await _showConfirmDialog(r.message);
      })
      ..setOnJavaScriptTextInputDialog(
          (JavaScriptTextInputDialogRequest r) async {
        // ✅ whiteboard Text tool — prompt() yahan aata hai
        // ✅ FIX: null safety — ?? '' added to handle Cancel press
        return await _showPromptDialog(
            message: r.message, defaultText: r.defaultText ?? '') ?? '';
      });

    if (_ctrl!.platform is AndroidWebViewController) {
      final android = _ctrl!.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
    }

    // ✅ Android pe local file load — Kotlin jaisa
    _ctrl!.loadRequest(Uri.parse(_whiteboardUrl));
  }

  Future<void> _showAlertDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alert'),
        content: Text(message),
        actions: [TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String message) async {
    if (!mounted) return false;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK')),
        ],
      ),
    );
    return r ?? false;
  }

  // Kotlin: onJsPrompt() → AlertDialog with EditText
  Future<String?> _showPromptDialog(
      {required String message, String defaultText = ''}) async {
    if (!mounted) return null;
    final ctrl = TextEditingController(text: defaultText);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Text',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message,
                  style: const TextStyle(color: Colors.white70)),
            ),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type here...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  void _injectTvKeys() {
    _ctrl?.runJavaScript(r'''
      (function(){
        if(window.__tv) return; window.__tv=true;
        document.addEventListener('keydown',function(e){
          var s=80;
          if(e.key==='ArrowDown')  window.scrollBy(0,s);
          if(e.key==='ArrowUp')    window.scrollBy(0,-s);
          if(e.key==='ArrowRight') window.scrollBy(s,0);
          if(e.key==='ArrowLeft')  window.scrollBy(-s,0);
        },{passive:true});
      })();
    ''');
  }

  void _resetTimer() {
    _toolbarTimer?.cancel();
    _toolbarTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showToolbar = false);
    });
  }

  void _toggleToolbar() {
    setState(() => _showToolbar = !_showToolbar);
    if (_showToolbar) _resetTimer();
  }

  KeyEventResult _handleKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.browserBack) {
      _goBack(); return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.f1) {
      _toggleToolbar(); return KeyEventResult.handled;
    }
    if (!_showToolbar) { setState(() => _showToolbar = true); _resetTimer(); }
    return KeyEventResult.ignored;
  }

  Future<void> _goBack() async {
    if (!kIsWeb && _ctrl != null && await _ctrl!.canGoBack()) {
      await _ctrl!.goBack(); return;
    }
    if (mounted) Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _toolbarTimer?.cancel();
    _ctrl?.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _showToolbar ? 56 : 0,
              child: _showToolbar ? _toolbar() : const SizedBox.shrink(),
            ),
            if (_loading && !kIsWeb)
              LinearProgressIndicator(value: _progress / 100,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFBF360C), minHeight: 3),
            Expanded(child: _hasError ? _errorState()
                : kIsWeb ? _webIframe() : _mobileView()),
          ]),
        ),
      ),
    );
  }

  // ✅ Web pe iframe — setJavaScriptMode web pe kaam nahi karta
  Widget _webIframe() => Stack(children: [
        HtmlElementView(viewType: _iframeId),
        if (_loading) _loadingOverlay(),
      ]);

  Widget _mobileView() {
    if (_ctrl == null) return const SizedBox.shrink();
    return Stack(children: [
      WebViewWidget(controller: _ctrl!),
      if (_loading && _progress < 90) _loadingOverlay(),
    ]);
  }

  Widget _toolbar() {
    return Container(
      height: 56,
      color: const Color(0xFF1A0800),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        _btn(Icons.arrow_back_ios_new_rounded, 'Back', _goBack),
        const SizedBox(width: 10),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded,
                    color: Color(0xFFBF360C), size: 20)),
          ),
        ),
        const SizedBox(width: 10),
        const Text('EasyLearn Whiteboard',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        if (kIsWeb)
          _btn(Icons.open_in_new_rounded, 'New Tab',
              () => iframe_helper.openInNewTab(_whiteboardUrl)),
        if (!kIsWeb) ...[
          _btn(Icons.refresh_rounded, 'Reload', () => _ctrl?.reload()),
          const SizedBox(width: 8),
          _btn(Icons.fullscreen_rounded, 'Fullscreen', () =>
              _ctrl?.runJavaScript(
                  'document.documentElement.requestFullscreen?.();')),
        ],
      ]),
    );
  }

  Widget _btn(IconData icon, String tip, VoidCallback fn) =>
      GestureDetector(
        onTap: fn,
        child: Tooltip(
          message: tip,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );

  Widget _loadingOverlay() => Container(
        color: const Color(0xFF1A0800),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.draw_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Loading Whiteboard...',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (!kIsWeb) Text('$_progress%',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: kIsWeb ? null : _progress / 100,
              backgroundColor: Colors.white12,
              color: const Color(0xFFBF360C), minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ])),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12), shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Whiteboard Load Nahi Hua',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_errMsg.isNotEmpty ? _errMsg : 'assets/html/whiteboard.html check karo',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () {
                  setState(() { _hasError = false; _loading = true; });
                  _ctrl?.reload();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Retry', style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Back', style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      );
}