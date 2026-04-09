import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class MindmapPage extends StatefulWidget {
  const MindmapPage({Key? key}) : super(key: key);

  @override
  State<MindmapPage> createState() => _MindmapPageState();
}

class _MindmapPageState extends State<MindmapPage> {
  static const String _mindmapPageUrl = 
      'https://k12.easylearn.org.in/Easylearn/mindmap_generator';
  
  static bool _iframeRegistered = false;
  bool _isLoading = true;
  WebViewController? _controller;
  final Completer<WebViewController> _controllerCompleter = Completer();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    if (kIsWeb) {
      // Web platform ke liye iframe register
      if (!_iframeRegistered) {
        ui_web.platformViewRegistry.registerViewFactory(
          'mindmap-iframe',
          (int viewId) {
            final iframe = html.IFrameElement()
              ..src = _mindmapPageUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allowFullscreen = true
              ..setAttribute('allow', 'fullscreen; clipboard-read; clipboard-write');
            
            // Loading complete hone par hide loading indicator
            iframe.onLoad.listen((event) {
              setState(() => _isLoading = false);
            });
            
            return iframe;
          },
        );
        _iframeRegistered = true;
      }
      setState(() => _isLoading = false);
    } else {
      // Android/iOS platform ke liye WebView
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF1A0800))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
              _injectCustomStyles();
            },
            onWebResourceError: (WebResourceError error) {
              setState(() => _isLoading = false);
              _showErrorDialog('Failed to load Mindmap Generator: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(_mindmapPageUrl));
      
      _controllerCompleter.complete(_controller);
    }
  }

  // WebView mein custom CSS inject karein for better UI
  Future<void> _injectCustomStyles() async {
    if (_controller != null) {
      await _controller!.runJavaScript('''
        // Add custom styles for better mobile experience
        const style = document.createElement('style');
        style.textContent = `
          .main-content {
            padding: 15px !important;
          }
          .card {
            margin-bottom: 15px !important;
            padding: 15px !important;
          }
          .card-header {
            font-size: 1.3em !important;
          }
          .btn {
            padding: 8px 20px !important;
            font-size: 14px !important;
          }
          textarea.form-control {
            min-height: 100px !important;
          }
          .response-area {
            min-height: 400px !important;
          }
          .mermaid svg {
            max-width: 100% !important;
            height: auto !important;
          }
        `;
        document.head.appendChild(style);
        
        console.log('Custom styles injected successfully');
      ''');
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Reload button handler
  void _reloadMindmap() {
  setState(() => _isLoading = true);
  if (kIsWeb) {
    // Cast to IFrameElement to access the src setter
    final iframe = html.document.querySelector('iframe') as html.IFrameElement?;
    if (iframe != null) {
      iframe.src = _mindmapPageUrl;
    } else {
      setState(() => _isLoading = false);
    }
  } else {
    _controller?.reload();
  }
}

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(
          child: Column(
            children: [
              // Header with better UI
              Container(
                height: 70,
                color: const Color(0xFF1A0800),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A0C00),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF3A1200), width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Back', 
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Title
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('AI Mindmap Generator',
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 20, 
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          )),
                        Text('Generate intelligent mindmaps',
                          style: TextStyle(color: Color(0xFFBF360C), fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Reload Button
                    GestureDetector(
                      onTap: _reloadMindmap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A0C00),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF3A1200), width: 1),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // WebView / iFrame Content
              Expanded(
                child: Stack(
                  children: [
                    // Main Content
                    kIsWeb
                        ? const HtmlElementView(viewType: 'mindmap-iframe')
                        : WebViewWidget(controller: _controller!),
                    
                    // Loading Overlay
                    if (_isLoading)
                      Container(
                        color: const Color(0xFF1A0800).withOpacity(0.95),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFFBF360C),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Loading AI Mindmap Generator...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please wait while we set up your workspace',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Tips section
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.symmetric(horizontal: 40),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A0C00),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.lightbulb_outline, color: Color(0xFFBF360C), size: 24),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Pro Tips',
                                      style: TextStyle(
                                        color: Color(0xFFBF360C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• Enter a topic to generate mindmap\n• Adjust depth for detailed maps\n• Save as image to download',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}