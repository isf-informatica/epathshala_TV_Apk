import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'webview_io_stub.dart'
if (dart.library.html) 'dart:ui_web' as ui_web;
import 'webview_io_stub.dart'
if (dart.library.html) 'dart:html' as html;

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── YouTube ke liye naya player import ────────────────────────────────────
import 'youtube_player_page.dart';

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
  String? _viewId;
  bool _disposed = false;
  bool _videoStarted = false;
  final FocusNode _playBtnFocus = FocusNode();

  // ─── Helpers ────────────────────────────────────────────────────────────
  String? _extractYouTubeId(String url) {
    for (final p in [
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)'),
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)'),
    ]) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  bool _isYouTubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  bool _isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return (lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('.webm') ||
        lower.contains('.ogg')) &&
        !lower.contains('youtube') &&
        !lower.contains('youtu.be') &&
        !lower.contains('drive.google') &&
        !lower.contains('docs.google');
  }

  // ─── HTML for direct video files (.mp4, .m3u8, etc.) ───────────────────
  String _buildVideoHtml(String url) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { width:100vw; height:100vh; background:#000; overflow:hidden; }
  video { width:100%; height:100%; object-fit:contain; display:block; }
  #loader {
    position:fixed; top:0; left:0; width:100%; height:100%;
    background:#1A0800;
    display:flex; flex-direction:column;
    align-items:center; justify-content:center;
    z-index:999; transition:opacity 0.4s ease;
  }
  #loader.hidden { opacity:0; pointer-events:none; }
  .spinner {
    width:72px; height:72px;
    border:6px solid rgba(255,120,40,0.25);
    border-top-color:#FB8C00; border-radius:50%;
    animation:spin 0.9s linear infinite; margin-bottom:20px;
  }
  @keyframes spin { to { transform:rotate(360deg); } }
  .loader-text { color:#FFA040; font-size:20px; font-family:sans-serif; font-weight:600; }
  .loader-sub  { color:rgba(255,255,255,0.45); font-size:14px; font-family:sans-serif; margin-top:8px; }
</style>
</head>
<body>
<div id="loader">
  <div class="spinner"></div>
  <div class="loader-text">Loading Video…</div>
  <div class="loader-sub">Please wait</div>
</div>
<video id="v" autoplay playsinline preload="auto" src="$url"></video>
<script>
  var v = document.getElementById('v');
  var loader = document.getElementById('loader');
  function hideLoader() {
    loader.classList.add('hidden');
    setTimeout(function(){ loader.style.display='none'; }, 450);
    v.setAttribute('controls','');
  }
  v.addEventListener('playing', hideLoader);
  v.addEventListener('canplay', function(){ v.play().catch(function(){}); });
  setTimeout(hideLoader, 25000);
</script>
</body>
</html>''';
  }

  // ─── initState ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // ── YouTube URL → YouTubePlayerPage pe redirect karo ──────────────────
    // (initState me direct navigate nahi kar sakte, postFrameCallback use karo)
    if (!kIsWeb && _isYouTubeUrl(widget.url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => YouTubePlayerPage(
              url: widget.url,
              title: widget.title,
            ),
          ),
        );
      });
      return; // WebView setup skip karo YouTube ke liye
    }

    if (kIsWeb) {
      _viewId = 'wvp_${widget.url.hashCode.abs()}';
      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewId!,
              (_) => html.IFrameElement()
            ..src = widget.url
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true
            ..setAttribute('allow', 'fullscreen'),
        );
      } catch (_) {}
      return;
    }

    // ── Native Android (non-YouTube) WebView setup ────────────────────────
    if (defaultTargetPlatform == TargetPlatform.android) {
      WebViewPlatform.instance ??= AndroidWebViewPlatform();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      WebViewPlatform.instance ??= WebKitWebViewPlatform();
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; Android TV) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {},
        onProgress: (v) {},
        onPageFinished: (url) {
          if (_disposed || !mounted) return;
          _controller?.runJavaScript('''
            (function() {
              var videos = document.querySelectorAll('video');
              videos.forEach(function(v) {
                v.preload = 'auto';
                v.setAttribute('playsinline','');
                if (v.paused) { v.play().catch(function(){}); }
              });
            })();
          ''');
        },
        onWebResourceError: (WebResourceError e) {
          debugPrint('[WebView Error] ${e.description}');
        },
        onHttpError: (HttpResponseError e) {},
      ))
      ..loadRequest(Uri.parse('about:blank'));

    if (_controller!.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      final androidCtrl = _controller!.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      androidCtrl.setOnPlatformPermissionRequest((req) => req.grant());
    }

    // ── Load URL ──────────────────────────────────────────────────────────
    if (_isDirectVideoUrl(widget.url)) {
      _controller!.loadHtmlString(
        _buildVideoHtml(widget.url),
        baseUrl: widget.url,
      );
    } else {
      // Any other URL (PDF, PPT viewer, etc.)
      _controller!.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _videoStarted = false;
    _playBtnFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // YouTube redirect pending — loading spinner dikhao
    if (!kIsWeb && _isYouTubeUrl(widget.url)) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0000)),
        ),
      );
    }

    if (kIsWeb && _viewId != null) {
      return HtmlElementView(viewType: _viewId!);
    }

    if (!kIsWeb && _controller != null) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller!),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFFFA600)),
    );
  }
}