// ─────────────────────────────────────────────────────────────────────────────
// mathstool_page.dart
//
// Yeh file boards_page.dart mein paste karo — UmlBoardPage ke neeche.
// Aur boards_page.dart mein boards list mein Mathematics card ko update karo.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ─────────────────────────────────────────────────────────────────────────────
// MathsToolPage — GeoGebra Math Tools (Basic, Geometry, Graphing, 3D, etc.)
// Mathstool.php ko WebView / iFrame mein load karta hai
// ─────────────────────────────────────────────────────────────────────────────

class MathsToolPage extends StatefulWidget {
  const MathsToolPage({Key? key}) : super(key: key);

  @override
  State<MathsToolPage> createState() => _MathsToolPageState();
}

class _MathsToolPageState extends State<MathsToolPage> {
  // ✅ Sahi URL — browser mein directly open hota hai
  static const String _mathsUrl = 'https://k12.easylearn.org.in/Mathstool';

  // ✅ Guard — ek baar se zyada register hone se crash rokta hai
  static bool _iframeRegistered = false;

  WebViewController? _controller;
  bool _isLoading = true;

  // Tab names matching the PHP page
  static const List<_MathTab> _tabs = [
    _MathTab(label: 'Basic',      icon: Icons.calculate_rounded),
    _MathTab(label: 'Geometry',   icon: Icons.hexagon_rounded),
    _MathTab(label: 'Graphing',   icon: Icons.show_chart_rounded),
    _MathTab(label: '3D',         icon: Icons.view_in_ar_rounded),
    _MathTab(label: 'Evaluator',  icon: Icons.functions_rounded),
    _MathTab(label: 'Scientific', icon: Icons.science_rounded),
    _MathTab(label: 'Notes',      icon: Icons.sticky_note_2_rounded),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web: register iframe once
      if (!_iframeRegistered) {
        ui_web.platformViewRegistry.registerViewFactory(
          'mathstool-iframe',
          (int viewId) {
            final iframe = html.IFrameElement()
              ..src = _mathsUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allowFullscreen = true
              ..setAttribute(
                  'allow', 'fullscreen; clipboard-read; clipboard-write');
            iframe.onLoad.listen((_) {
              if (mounted) setState(() => _isLoading = false);
            });
            return iframe;
          },
        );
        _iframeRegistered = true;
      }
      setState(() => _isLoading = false);
    } else {
      // Mobile / TV: WebView
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ))
        ..loadRequest(Uri.parse(_mathsUrl));
    }
  }

  // ── TV Remote / Keyboard back handler ──────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final isTV = MediaQuery.of(context).size.width >= 1000;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              _buildHeader(isTV),

              // ── Tab info bar (just decorative — tabs are inside the iframe)
              _buildTabBar(),

              // ── WebView / iFrame ──────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    kIsWeb
                        ? const HtmlElementView(viewType: 'mathstool-iframe')
                        : WebViewWidget(controller: _controller!),

                    // Loading overlay
                    if (_isLoading)
                      Container(
                        color: const Color(0xFF0D1C45),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated icon
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.1),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeInOut,
                                builder: (_, v, child) =>
                                    Transform.scale(scale: v, child: child),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A2E55),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFFFFA600),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.calculate_rounded,
                                      color: Color(0xFFFFA600), size: 40),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(
                                  color: Color(0xFFFFA600), strokeWidth: 3),
                              const SizedBox(height: 20),
                              const Text(
                                'Loading Mathematics Tools...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'GeoGebra • Basic • Geometry • Graphing • 3D',
                                style: TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 13),
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

  // ── Header widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(bool isTV) {
    return Container(
      height: 70,
      color: const Color(0xFF0D1C45),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E55),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF2A4070), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Back',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Title
          const Text(
            'Mathematics Tools',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800),
          ),

          const Spacer(),

          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.calculate_rounded,
                    color: Color(0xFFFFA600), size: 16),
                SizedBox(width: 6),
                Text(
                  'Powered by GeoGebra',
                  style: TextStyle(
                      color: Color(0xFFFFA600),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Decorative tab bar (shows available tools) ─────────────────────────────
  Widget _buildTabBar() {
    return Container(
      height: 48,
      color: const Color(0xFF0D1B3E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E55).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2A4070).withOpacity(0.5),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Icon(tab.icon,
                        color: Colors.white70,
                        size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper model
// ─────────────────────────────────────────────────────────────────────────────
class _MathTab {
  final String label;
  final IconData icon;
  const _MathTab({required this.label, required this.icon});
}


// ═════════════════════════════════════════════════════════════════════════════
// boards_page.dart MEIN YEH CHANGES KARO:
// ═════════════════════════════════════════════════════════════════════════════
//
// 1) BoardType enum mein 'mathematics' add karo:
//    enum BoardType { miro, advanced, mindmap, uml, mathematics, comingSoon }
//
// 2) _boards list mein Mathematics card update karo (comingSoon → mathematics):
//    _BoardItem(
//      title: 'Mathematics',
//      icon: Icons.calculate_rounded,
//      gradient: [Color(0xFF5DD4EE), Color(0xFF2A8BBE), Color(0xFF0D4080)],
//      type: BoardType.mathematics,        // <-- yeh change karo
//    ),
//
// 3) _openBoard() method mein yeh case add karo (uml ke baad):
//    } else if (board.type == BoardType.mathematics) {
//      page = const MathsToolPage();
//    }
//
// ═════════════════════════════════════════════════════════════════════════════