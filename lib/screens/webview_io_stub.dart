// lib/screens/webview_io_stub.dart
// Mobile pe dart:html aur dart:ui_web ka stub
// ignore_for_file: unused_element, unused_field

class _PlatformViewRegistry {
  void registerViewFactory(String viewId, dynamic Function(int) cb) {}
}

final platformViewRegistry = _PlatformViewRegistry();

class IFrameElement {
  String src = '';
  bool   allowFullscreen = false;
  _Style style = _Style();
  void setAttribute(String k, String v) {}
}

class _Style {
  String border = '';
  String width  = '';
  String height = '';
}