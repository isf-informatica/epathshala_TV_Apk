// web_shim_stub.dart — Mobile/TV stub (no dart:html or dart:ui_web)
// Place in: lib/screens/web_shim_stub.dart

void registerIframeFactory(
  String viewType,
  String initialUrl, {
  String? iframeId,
  bool useSrcdoc = false,
  String? srcdocContent,
}) {}

void updateIframeSrcdoc(String iframeId, String newSrcdoc) {}