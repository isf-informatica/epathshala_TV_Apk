// js_stub.dart — Mobile/TV stub for dart:js
// Place in: lib/screens/js_stub.dart
// All dart:js calls are inside kIsWeb guards so these never run on mobile.

// ignore_for_file: unused_element

class JsObject {
  JsObject(dynamic constructor, [List? args]);
  dynamic operator [](dynamic key) => null;
  void operator []=(dynamic key, dynamic value) {}
  dynamic callMethod(String method, [List? args]) => null;
}

class JsFunction extends JsObject {
  JsFunction() : super(null);
}

// JsArray does NOT extend JsObject — avoids operator[] signature conflict
class JsArray<T> {
  int get length => 0;
  dynamic operator [](dynamic index) => null;
  void operator []=(dynamic index, dynamic value) {}
}

final context = _JsContext();

class _JsContext {
  dynamic operator [](dynamic key) => null;
  void operator []=(dynamic key, dynamic value) {}
  dynamic callMethod(String method, [List? args]) => null;
}

T allowInterop<T extends Function>(T f) => f;