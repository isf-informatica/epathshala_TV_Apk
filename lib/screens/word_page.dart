import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Conditional import: web-only shim vs mobile stub
import 'web_shim_stub.dart'
  if (dart.library.html) 'web_shim_web.dart'
  as webShim;

import 'package:webview_flutter/webview_flutter.dart';

class WordPage extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const WordPage({Key? key, required this.loginData}) : super(key: key);

  @override
  _WordPageState createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  WebViewController? _controller;
  final String _viewId =
      'word-editor-${DateTime.now().millisecondsSinceEpoch}';
  bool _webReady  = false;
  bool _isLoading = true;
  bool _hasError  = false;

  String get _userName =>
      widget.loginData['name']?.toString() ?? 'User';

  // ── Full HTML editor using Quill.js (loads from CDN) ─────────
  String get _editorHtml => '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Word Editor</title>
<link href="https://cdn.quilljs.com/1.3.7/quill.snow.css" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; background: #f0f0f0; font-family: Arial, sans-serif; }

  #toolbar-container {
    background: #fff;
    border-bottom: 1px solid #ddd;
    padding: 6px 10px;
    position: sticky;
    top: 0;
    z-index: 100;
    box-shadow: 0 2px 4px rgba(0,0,0,0.08);
  }

  #editor-wrapper {
    height: calc(100vh - 110px);
    overflow-y: auto;
    padding: 20px;
    background: #f0f0f0;
  }

  #editor {
    background: #fff;
    min-height: calc(100vh - 160px);
    max-width: 860px;
    margin: 0 auto;
    padding: 60px 72px;
    box-shadow: 0 2px 16px rgba(0,0,0,0.15);
    border-radius: 2px;
  }

  .ql-toolbar.ql-snow {
    border: none !important;
    padding: 0 !important;
    flex-wrap: wrap;
  }
  .ql-container.ql-snow { border: none !important; }
  .ql-editor { padding: 0 !important; min-height: 400px; font-size: 14px; line-height: 1.6; }
  .ql-editor p { margin-bottom: 8px; }

  #statusbar {
    position: fixed;
    bottom: 0; left: 0; right: 0;
    background: #fff;
    border-top: 1px solid #ddd;
    padding: 5px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    color: #666;
    z-index: 100;
  }

  #btn-save, #btn-download {
    background: #1D4ED8;
    color: #fff;
    border: none;
    padding: 5px 14px;
    border-radius: 5px;
    cursor: pointer;
    font-size: 12px;
    margin-left: 8px;
  }
  #btn-download { background: #059669; }
  #btn-save:hover { background: #1e40af; }
  #btn-download:hover { background: #047857; }
  #save-status { color: #059669; font-size: 11px; margin-left: 8px; }
</style>
</head>
<body>

<div id="toolbar-container">
  <div id="toolbar">
    <span class="ql-formats">
      <select class="ql-font"></select>
      <select class="ql-size">
        <option value="small"></option>
        <option selected></option>
        <option value="large"></option>
        <option value="huge"></option>
      </select>
    </span>
    <span class="ql-formats">
      <button class="ql-bold"></button>
      <button class="ql-italic"></button>
      <button class="ql-underline"></button>
      <button class="ql-strike"></button>
    </span>
    <span class="ql-formats">
      <select class="ql-color"></select>
      <select class="ql-background"></select>
    </span>
    <span class="ql-formats">
      <button class="ql-list" value="ordered"></button>
      <button class="ql-list" value="bullet"></button>
      <button class="ql-indent" value="-1"></button>
      <button class="ql-indent" value="+1"></button>
    </span>
    <span class="ql-formats">
      <select class="ql-align"></select>
    </span>
    <span class="ql-formats">
      <button class="ql-blockquote"></button>
      <button class="ql-code-block"></button>
    </span>
    <span class="ql-formats">
      <button class="ql-link"></button>
      <button class="ql-image"></button>
    </span>
    <span class="ql-formats">
      <button class="ql-clean"></button>
    </span>
  </div>
</div>

<div id="editor-wrapper">
  <div id="editor"></div>
</div>

<div id="statusbar">
  <span id="word-count">0 words</span>
  <span>
    <span id="save-status"></span>
    <button id="btn-save" onclick="saveContent()">💾 Save</button>
    <button id="btn-download" onclick="downloadDoc()">⬇ Download</button>
  </span>
</div>

<script src="https://cdn.quilljs.com/1.3.7/quill.min.js"></script>
<script>
var quill = new Quill("#editor", {
  theme: "snow",
  modules: { toolbar: "#toolbar" },
  placeholder: "Start typing your document here..."
});

// Word count
quill.on("text-change", function() {
  var text = quill.getText().trim();
  var words = text.length === 0 ? 0 : text.split(/\\s+/).length;
  document.getElementById("word-count").textContent = words + " word" + (words !== 1 ? "s" : "");
  
  // Auto-save to localStorage
  localStorage.setItem("word_doc_content", quill.root.innerHTML);
  var s = document.getElementById("save-status");
  s.textContent = "Saved";
  setTimeout(function(){ s.textContent = ""; }, 2000);
});

// Restore saved content
var saved = localStorage.getItem("word_doc_content");
if (saved && saved.length > 0) {
  quill.root.innerHTML = saved;
}

function saveContent() {
  localStorage.setItem("word_doc_content", quill.root.innerHTML);
  var s = document.getElementById("save-status");
  s.textContent = "✓ Saved!";
  setTimeout(function(){ s.textContent = ""; }, 2000);
}

function downloadDoc() {
  var content = quill.root.innerHTML;
  var html = "<!DOCTYPE html><html><head><meta charset=UTF-8><title>Document</title><style>body{font-family:Arial;max-width:800px;margin:40px auto;padding:0 40px;}</style></head><body>" + content + "</body></html>";
  var blob = new Blob([html], {type: "text/html"});
  var a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "document.html";
  a.click();
}
</script>
</body>
</html>''';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWeb();
    } else {
      _initAndroid();
    }
  }

  // ── Web: HtmlElementView iframe with srcdoc ───────────────────
  void _initWeb() {
    try {
      webShim.registerIframeFactory(
        _viewId,
        '',
        useSrcdoc: true,
        srcdocContent: _editorHtml,
      );
      setState(() { _webReady = true; });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── Android: WebView with loadHtmlString ──────────────────────
  void _initAndroid() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _isLoading = true; _hasError = false; }),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() { _isLoading = false; _hasError = true; }),
        onNavigationRequest: (_) => NavigationDecision.navigate,
      ))
      ..loadHtmlString(_editorHtml);
  }

  void _reload() {
    setState(() { _isLoading = true; _hasError = false; });
    if (kIsWeb) {
      setState(() { _webReady = false; });
      Future.microtask(_initWeb);
    } else {
      _controller?.loadHtmlString(_editorHtml);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape   ||
        event.logicalKey == LogicalKeyboardKey.goBack   ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(child: Stack(children: [

              if (!_hasError) ...[
                if (kIsWeb && _webReady)
                  HtmlElementView(viewType: _viewId)
                else if (!kIsWeb && _controller != null)
                  WebViewWidget(controller: _controller!),
              ],

              if (_isLoading)
                Container(
                  color: const Color(0xFF0D1C45),
                  child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5,
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                          const Icon(Icons.description_rounded,
                              color: Colors.white, size: 26),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Text('Loading Word Editor...',
                        style: TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Powered by Quill.js',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  )),
                ),

              if (_hasError && !_isLoading)
                Container(
                  color: const Color(0xFF0D1C45),
                  child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFDC2626).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.wifi_off_rounded,
                            color: Color(0xFFDC2626), size: 30),
                      ),
                      const SizedBox(height: 20),
                      const Text('Could not load Word Editor',
                        style: TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _reload,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Retry', style: TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ],
                  )),
                ),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1A3E),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        const SizedBox(width: 18),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Word Editor', style: TextStyle(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w800)),
            Text('Rich Text Editor',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: _reload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Row(children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('Reload', style: TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA600).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFFFA600).withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.build_rounded, color: Color(0xFFFFA600), size: 13),
            SizedBox(width: 5),
            Text('Tools', style: TextStyle(
                color: Color(0xFFFFA600), fontSize: 12,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}