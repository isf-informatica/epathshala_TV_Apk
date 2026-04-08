import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'webview_io_stub.dart'
    if (dart.library.html) 'dart:ui_web' as ui_web;
import 'webview_io_stub.dart'
    if (dart.library.html) 'dart:html' as html;

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({Key? key, required this.url, required this.title})
      : super(key: key);

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _controller;
  bool    _isLoading      = true;
  double  _progress       = 0;
  String? _viewId;

  bool    _hasError       = false;
  bool    _errorShownOnce = false;
  bool    _disposed       = false;

  Timer?  _timeoutTimer;
  static const _timeoutSeconds = 15; // 15 sec no response = network issue

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _viewId = 'wvp_${widget.url.hashCode.abs()}';
      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewId!,
          (_) => html.IFrameElement()
            ..src = widget.url
            ..style.border = 'none'
            ..style.width  = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true
            ..setAttribute('allow', 'fullscreen'),
        );
      } catch (_) {}
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        WebViewPlatform.instance ??= AndroidWebViewPlatform();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        WebViewPlatform.instance ??= WebKitWebViewPlatform();
      }

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) {
            if (_disposed || !mounted) return;
            _startTimeout(); // ✅ Timer shuru
            setState(() {
              _isLoading      = true;
              _hasError       = false;
              _errorShownOnce = false;
              _progress       = 0;
            });
          },
          onProgress: (v) {
            if (_disposed || !mounted) return;
            setState(() => _progress = v / 100);
            // Kuch progress aa rahi hai — timeout reset karo
            if (v > 10) _cancelTimeout();
          },
          onPageFinished: (_) {
            if (_disposed || !mounted) return;
            _cancelTimeout(); // ✅ Load ho gaya — timer cancel
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError e) {
            if (_disposed || !mounted) return;
            if (e.isForMainFrame != true) return;
            if (_errorShownOnce) return;
            _cancelTimeout();
            _showNetworkError();
          },
          onHttpError: (HttpResponseError e) {
            if (_disposed || !mounted) return;
            if (_errorShownOnce) return;
            _cancelTimeout();
            _showNetworkError();
          },
        ))
        ..loadRequest(Uri.parse(widget.url));

      // Start timeout for the first load
      _startTimeout();

      if (_controller!.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(false);
        final androidCtrl = _controller!.platform as AndroidWebViewController;
        androidCtrl.setMediaPlaybackRequiresUserGesture(false);
        androidCtrl.setOnPlatformPermissionRequest((req) => req.grant());
      }
    }
  }

  void _startTimeout() {
    _cancelTimeout();
    _timeoutTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      if (_disposed || !mounted) return;
      if (!_hasError && _isLoading) {
        _showNetworkError();
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _showNetworkError() {
    if (_disposed || !mounted || _errorShownOnce) return;
    setState(() {
      _isLoading      = false;
      _hasError       = true;
      _errorShownOnce = true;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimeout();
    super.dispose();
  }

  void _retry() {
    if (_disposed || !mounted) return;
    setState(() {
      _isLoading      = true;
      _hasError       = false;
      _errorShownOnce = false;
      _progress       = 0;
    });
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && _viewId != null) {
      return HtmlElementView(viewType: _viewId!);
    }

    if (!kIsWeb && _controller != null) {
      return Stack(
        children: [
          SizedBox.expand(child: WebViewWidget(controller: _controller!)),

          // ✅ Loading — English only
          if (_isLoading && !_hasError)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFA600)),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Color(0xFFFFA600)),
                        SizedBox(height: 16),
                        Text(
                          'Loading video...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // ✅ Network Issue — 1st fail pe hi, English only, shows once
          if (_hasError && !_isLoading)
            Container(
              color: const Color(0xFF0D1C45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 72,
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Network Issue\nVideo could not be loaded.\nPlease check your internet connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _retry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA600),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFA600).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
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
        ],
      );
    }

    return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFA600)));
  }
}