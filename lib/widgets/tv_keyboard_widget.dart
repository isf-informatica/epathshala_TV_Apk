// widgets/tv_keyboard_widget.dart
// On-screen keyboard for TV remote navigation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvKeyboardWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isPassword;
  final VoidCallback? onDone;

  const TvKeyboardWidget({
    Key? key,
    required this.controller,
    this.isPassword = false,
    this.onDone,
  }) : super(key: key);

  @override
  State<TvKeyboardWidget> createState() => _TvKeyboardWidgetState();
}

class _TvKeyboardWidgetState extends State<TvKeyboardWidget> {
  int _focusRow = 0;
  int _focusCol = 0;
  bool _capsLock = false;
  bool _showNumbers = false;

  final List<List<String>> _letters = [
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['⇧','z','x','c','v','b','n','m','⌫'],
    ['123','@','.','_','-','SPACE','✓'],
  ];

  final List<List<String>> _numbers = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['!','@','#','\$','%','^','&','*','(',')',],
    ['-','_','.','/',':',';','\'','"','⌫'],
    ['ABC','SPACE','✓'],
  ];

  List<List<String>> get _layout => _showNumbers ? _numbers : _letters;

  void _onKey(String key) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    int pos = sel.baseOffset < 0 ? text.length : sel.baseOffset;

    setState(() {
      if (key == '⌫') {
        if (pos > 0) {
          final newText = text.substring(0, pos - 1) + text.substring(pos);
          ctrl.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: pos - 1),
          );
        }
      } else if (key == 'SPACE') {
        final newText = text.substring(0, pos) + ' ' + text.substring(pos);
        ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos + 1),
        );
      } else if (key == '⇧') {
        _capsLock = !_capsLock;
      } else if (key == '123') {
        _showNumbers = true;
      } else if (key == 'ABC') {
        _showNumbers = false;
      } else if (key == '✓') {
        widget.onDone?.call();
      } else {
        final char = _capsLock ? key.toUpperCase() : key;
        final newText = text.substring(0, pos) + char + text.substring(pos);
        ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos + 1),
        );
      }
    });
  }

  void _moveFocus(int dRow, int dCol) {
    final layout = _layout;
    int newRow = (_focusRow + dRow).clamp(0, layout.length - 1);
    int newCol = (_focusCol + dCol).clamp(0, layout[newRow].length - 1);
    setState(() {
      _focusRow = newRow;
      _focusCol = newCol;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp:    _moveFocus(-1, 0); return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowDown:  _moveFocus(1, 0);  return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowLeft:  _moveFocus(0, -1); return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowRight: _moveFocus(0, 1);  return KeyEventResult.handled;
          case LogicalKeyboardKey.select:
          case LogicalKeyboardKey.enter:
            _onKey(layout[_focusRow][_focusCol]);
            return KeyEventResult.handled;
          default: return KeyEventResult.ignored;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2333),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(layout.length, (rowIdx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(layout[rowIdx].length, (colIdx) {
                  final key = layout[rowIdx][colIdx];
                  final isFocused = rowIdx == _focusRow && colIdx == _focusCol;
                  final isWide = key == 'SPACE';
                  final isMed = ['⌫','⇧','123','ABC','✓','SPACE'].contains(key);

                  return GestureDetector(
                    onTap: () {
                      setState(() { _focusRow = rowIdx; _focusCol = colIdx; });
                      _onKey(key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: isWide ? 120 : isMed ? 56 : 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? const Color(0xFF4F46E5)
                            : key == '⇧' && _capsLock
                                ? const Color(0xFF4F46E5).withOpacity(0.5)
                                : const Color(0xFF0B0E13),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isFocused ? const Color(0xFF818CF8) : Colors.white12,
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused ? [
                          BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.5), blurRadius: 8),
                        ] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _capsLock && key.length == 1 ? key.toUpperCase() : key,
                        style: TextStyle(
                          color: isFocused ? Colors.white : Colors.white70,
                          fontSize: key == 'SPACE' ? 11 : 13,
                          fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}