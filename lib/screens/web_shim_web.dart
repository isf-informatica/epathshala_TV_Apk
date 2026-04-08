// web_shim_web.dart — Flutter Web implementation
// Place in: lib/screens/web_shim_web.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void registerIframeFactory(
  String viewType,
  String initialUrl, {
  String? iframeId,
  bool useSrcdoc = false,
  String? srcdocContent,
}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true
      ..setAttribute('allow', 'fullscreen; clipboard-read; clipboard-write');
    if (iframeId != null) iframe.id = iframeId;
    if (useSrcdoc && srcdocContent != null) {
      iframe.srcdoc = srcdocContent;
    } else {
      iframe.src = initialUrl;
    }
    return iframe;
  });
}

void updateIframeSrcdoc(String iframeId, String newSrcdoc) {
  final frames = html.document.querySelectorAll('iframe');
  for (final el in frames) {
    if (el is html.IFrameElement && el.id == iframeId) {
      el.srcdoc = newSrcdoc;
      break;
    }
  }
}