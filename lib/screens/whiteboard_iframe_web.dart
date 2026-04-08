// lib/screens/whiteboard_iframe_web.dart
// ⚠️  YEH FILE SIRF WEB PE COMPILE HOTI HAI
// Mobile/TV ke liye whiteboard_iframe_stub.dart use hoti hai

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// Chrome mein iframe register karo — whiteboard_page.dart se call hota hai
void registerIframe(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width  = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true
      // Allow clipboard, camera etc. agar whiteboard ko chahiye
      ..setAttribute('allow', 'clipboard-read; clipboard-write; camera; microphone');
    return iframe;
  });
}

/// New tab mein URL open karo (web only)
void openInNewTab(String url) {
  html.window.open(url, '_blank');
}