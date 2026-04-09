import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ── Enums ────────────────────────────────────────────────────
enum _Screen { grid, create, edit, deleteConfirm }

class StickyNotesPage extends StatefulWidget {
  final Map<String, dynamic> loginData;
  const StickyNotesPage({Key? key, required this.loginData}) : super(key: key);

  @override
  _StickyNotesPageState createState() => _StickyNotesPageState();
}

class _StickyNotesPageState extends State<StickyNotesPage> {
  // ── API ──────────────────────────────────────────────────────
  static const _base = 'https://k12.easylearn.org.in';

  String get _email    => widget.loginData['email']?.toString()    ?? '';
  String get _password => widget.loginData['password']?.toString() ?? '';

  // ── State ────────────────────────────────────────────────────
  List<_StickyNote> _notes = [];
  bool _loading = true;
  bool _saving  = false;

  // Current screen
  _Screen _screen = _Screen.grid;

  // Grid focus — 0..n-1 = notes, n = "New Note" button
  int _gridFocus = 0;

  // Delete confirm focus: 0=Cancel, 1=Delete
  int _deleteFocus = 0;
  int? _deleteTarget;

  // Edit/Create form
  int  _formFocus = 0; // 0=title chars, 1=desc chars, 2=color, 3=Save, 4=Cancel
  // Title & desc as string buffers (TV virtual keyboard style)
  String _formTitle = '';
  String _formDesc  = '';
  int    _colorIdx  = 2; // default yellow
  int?   _editTarget;

  // Virtual keyboard
  bool _kbActive = false; // is keyboard shown
  int  _kbField  = 0;     // 0=title, 1=desc
  int  _kbRow    = 0;
  int  _kbCol    = 0;
  bool _kbShift  = false;

  static const List<List<String>> _kbRows = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l','-'],
    ['z','x','c','v','b','n','m',',','.','!'],
    ['⇧','SPACE','⌫','DONE'],
  ];

  // Colors
  static const List<String> _colorNames = [
    'red','purple','yellow','green','orange','pink','blue'
  ];
  static const List<Color> _colorSwatches = [
    Color(0xFFFFB8B8), Color(0xFFDFB8FF), Color(0xFFF7FFB8),
    Color(0xFFB3FFD7), Color(0xFFFFE7B3), Color(0xFFFFB3E3), Color(0xFFB3D4FF),
  ];
  static const List<Color> _colorText = [
    Color(0xFF5C2B29), Color(0xFF42275E), Color(0xFF635D19),
    Color(0xFF345920), Color(0xFF614A19), Color(0xFF5B2245), Color(0xFF1E3A5F),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromServer();
  }

  // ── API ──────────────────────────────────────────────────────
  Future<void> _loadFromServer() async {
    setState(() => _loading = true);
    try {
      final r = await http.post(
        Uri.parse('$_base/Easylearn/Dashboard_Controller/get_sticky_note'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'email=${Uri.encodeComponent(_email)}&password=${Uri.encodeComponent(_password)}',
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 && r.body.isNotEmpty) {
        try {
          final d = json.decode(r.body);
          if (d is List) {
            setState(() => _notes = d.map((n) => _StickyNote.fromJson(n)).toList());
          }
        } catch (_) {}
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveToServer() async {
    setState(() => _saving = true);
    try {
      final j = json.encode(_notes.map((n) => n.toJson()).toList());
      await http.post(
        Uri.parse('$_base/Easylearn/Dashboard_Controller/update_sticky_note'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'note_json_string=${Uri.encodeComponent(j)}'
            '&email=${Uri.encodeComponent(_email)}'
            '&password=${Uri.encodeComponent(_password)}',
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
    setState(() => _saving = false);
  }

  // ── Navigation helpers ───────────────────────────────────────
  void _goCreate() {
    _formTitle  = '';
    _formDesc   = '';
    _colorIdx   = 2;
    _formFocus  = 0;
    _editTarget = null;
    _kbActive   = false;
    setState(() => _screen = _Screen.create);
  }

  void _goEdit(int idx) {
    final n = _notes[idx];
    _formTitle  = n.title;
    _formDesc   = n.description;
    _colorIdx   = _colorNames.indexOf(n.color).clamp(0, 6);
    _formFocus  = 0;
    _editTarget = idx;
    _kbActive   = false;
    setState(() => _screen = _Screen.edit);
  }

  void _saveForm() {
    if (_formTitle.isEmpty && _formDesc.isEmpty) return;
    if (_editTarget != null) {
      _notes[_editTarget!] = _StickyNote(
        title: _formTitle, description: _formDesc,
        color: _colorNames[_colorIdx],
      );
    } else {
      _notes.add(_StickyNote(
        title: _formTitle, description: _formDesc,
        color: _colorNames[_colorIdx],
      ));
      _gridFocus = _notes.length - 1;
    }
    setState(() => _screen = _Screen.grid);
    _saveToServer();
  }

  void _confirmDelete(int idx) {
    _deleteTarget = idx;
    _deleteFocus  = 0;
    setState(() => _screen = _Screen.deleteConfirm);
  }

  void _doDelete() {
    if (_deleteTarget != null) {
      _notes.removeAt(_deleteTarget!);
      _gridFocus = _gridFocus.clamp(0, _notes.length);
      _saveToServer();
    }
    setState(() => _screen = _Screen.grid);
  }

  // ── Master key handler ───────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent ev) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;
    final k = ev.logicalKey;

    switch (_screen) {
      case _Screen.grid:         return _keyGrid(k);
      case _Screen.create:
      case _Screen.edit:         return _keyForm(k);
      case _Screen.deleteConfirm: return _keyDelete(k);
    }
  }

  // ── Grid keys ────────────────────────────────────────────────
  KeyEventResult _keyGrid(LogicalKeyboardKey k) {
    final total = _notes.length + 1; // +1 for New button
    final cols  = _cols;

    if (k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.browserBack) {
      Navigator.maybePop(context); return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      setState(() => _gridFocus = (_gridFocus + 1).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      setState(() => _gridFocus = (_gridFocus - 1).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _gridFocus = (_gridFocus + cols).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _gridFocus = (_gridFocus - cols).clamp(0, total - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter  ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_gridFocus == _notes.length) { _goCreate(); }
      else { _goEdit(_gridFocus); }
      return KeyEventResult.handled;
    }
    // Long press simulation: gameButtonB / X = delete
    if (k == LogicalKeyboardKey.gameButtonB) {
      if (_gridFocus < _notes.length) _confirmDelete(_gridFocus);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Form keys ────────────────────────────────────────────────
  // formFocus: 0=title(open kb), 1=desc(open kb), 2=colorLeft, 3=colorRight, 4=Save, 5=Cancel
  KeyEventResult _keyForm(LogicalKeyboardKey k) {
    if (_kbActive) return _keyKb(k);

    if (k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.escape) {
      setState(() => _screen = _Screen.grid);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _formFocus = (_formFocus + 1).clamp(0, 5));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _formFocus = (_formFocus - 1).clamp(0, 5));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (_formFocus == 2) setState(() => _colorIdx = (_colorIdx - 1).clamp(0, 6));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_formFocus == 2) setState(() => _colorIdx = (_colorIdx + 1).clamp(0, 6));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter  ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (_formFocus == 0) { _kbField = 0; setState(() => _kbActive = true); }
      else if (_formFocus == 1) { _kbField = 1; setState(() => _kbActive = true); }
      else if (_formFocus == 4) { _saveForm(); }
      else if (_formFocus == 5) { setState(() => _screen = _Screen.grid); }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Virtual keyboard keys ────────────────────────────────────
  KeyEventResult _keyKb(LogicalKeyboardKey k) {
    final row = _kbRows[_kbRow];

    if (k == LogicalKeyboardKey.arrowRight) {
      setState(() => _kbCol = (_kbCol + 1).clamp(0, row.length - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      setState(() => _kbCol = (_kbCol - 1).clamp(0, row.length - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_kbRow < _kbRows.length - 1) {
        setState(() {
          _kbRow++;
          _kbCol = _kbCol.clamp(0, _kbRows[_kbRow].length - 1);
        });
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      if (_kbRow > 0) {
        setState(() {
          _kbRow--;
          _kbCol = _kbCol.clamp(0, _kbRows[_kbRow].length - 1);
        });
      } else {
        // Close keyboard on up from top row
        setState(() => _kbActive = false);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter  ||
        k == LogicalKeyboardKey.gameButtonA) {
      _tapKbKey(_kbRows[_kbRow][_kbCol]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.escape) {
      setState(() => _kbActive = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _tapKbKey(String key) {
    setState(() {
      if (key == 'DONE') { _kbActive = false; return; }
      if (key == '⌫') {
        if (_kbField == 0 && _formTitle.isNotEmpty) _formTitle = _formTitle.substring(0, _formTitle.length - 1);
        if (_kbField == 1 && _formDesc.isNotEmpty)  _formDesc  = _formDesc.substring(0, _formDesc.length - 1);
        return;
      }
      if (key == '⇧') { _kbShift = !_kbShift; return; }
      String ch = key == 'SPACE' ? ' ' : (_kbShift ? key.toUpperCase() : key);
      if (_kbField == 0) _formTitle += ch;
      if (_kbField == 1) _formDesc  += ch;
      if (_kbShift && key != '⇧') _kbShift = false;
    });
  }

  // ── Delete confirm keys ──────────────────────────────────────
  KeyEventResult _keyDelete(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      setState(() => _deleteFocus = _deleteFocus == 0 ? 1 : 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.gameButtonA) {
      if (_deleteFocus == 1) _doDelete();
      else setState(() => _screen = _Screen.grid);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      setState(() => _screen = _Screen.grid);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int get _cols {
    try {
      final w = MediaQuery.of(context).size.width;
      if (w >= 1400) return 6;
      if (w >= 1100) return 5;
      if (w >= 800)  return 4;
      return 3;
    } catch (_) { return 5; }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ])),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screen) {
      case _Screen.grid:          return _buildGrid();
      case _Screen.create:
      case _Screen.edit:          return _buildForm();
      case _Screen.deleteConfirm: return _buildDeleteConfirm();
    }
  }

  // ── GRID SCREEN ──────────────────────────────────────────────
  Widget _buildGrid() {
    if (_loading) return _buildLoading();

    final cols = _cols;
    final total = _notes.length + 1;

    return GridView.builder(
      padding: const EdgeInsets.all(28),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 1.05,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == _notes.length) return _buildAddCard();
        return _buildNoteCard(i);
      },
    );
  }

  Widget _buildNoteCard(int i) {
    final note     = _notes[i];
    final focused  = _gridFocus == i && _screen == _Screen.grid;
    final ci       = _colorNames.indexOf(note.color).clamp(0, 6);
    final bg       = _colorSwatches[ci];
    final tc       = _colorText[ci];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? const Color(0xFFBF360C) : Colors.transparent,
          width: focused ? 3.5 : 0,
        ),
        boxShadow: focused
            ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.5), blurRadius: 20, spreadRadius: 3)]
            : [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(2, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Color dot + title
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
              color: tc.withOpacity(0.5), shape: BoxShape.circle,
            )),
            const SizedBox(width: 8),
            Expanded(child: Text(note.title,
              style: TextStyle(color: tc, fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 8),
          Expanded(child: Text(note.description,
            style: TextStyle(color: tc.withOpacity(0.8), fontSize: 13, height: 1.45),
            overflow: TextOverflow.fade,
          )),
          const SizedBox(height: 6),
          // Bottom hint
          if (focused) Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hintChip(tc, '✏ OK = Edit'),
              _hintChip(tc, '🗑 B = Delete'),
            ],
          ) else Row(children: [
            Icon(Icons.edit_rounded, color: tc.withOpacity(0.3), size: 12),
            const SizedBox(width: 4),
            Text('OK to edit', style: TextStyle(color: tc.withOpacity(0.3), fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _hintChip(Color tc, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: tc.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(color: tc.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _buildAddCard() {
    final focused = _gridFocus == _notes.length && _screen == _Screen.grid;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? const Color(0xFFBF360C) : Colors.white.withOpacity(0.12),
          width: focused ? 3.5 : 1.5,
        ),
        boxShadow: focused
            ? [BoxShadow(color: const Color(0xFFBF360C).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: focused ? 56 : 48, height: focused ? 56 : 48,
          decoration: BoxDecoration(
            color: focused
                ? const Color(0xFFBF360C)
                : const Color(0xFFF59E0B).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_rounded,
            color: focused ? Colors.white : const Color(0xFFF59E0B),
            size: focused ? 32 : 26),
        ),
        const SizedBox(height: 12),
        Text('New Note', style: TextStyle(
          color: focused ? const Color(0xFFBF360C) : Colors.white38,
          fontSize: 14, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 4),
        Text('OK to create', style: TextStyle(
          color: Colors.white.withOpacity(0.2), fontSize: 11,
        )),
      ]),
    );
  }

  // ── FORM SCREEN ──────────────────────────────────────────────
  Widget _buildForm() {
    final isEdit = _screen == _Screen.edit;
    final bg  = _colorSwatches[_colorIdx];
    final tc  = _colorText[_colorIdx];

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Left: form fields ──────────────────────────────────
      Expanded(flex: 3, child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Text(isEdit ? 'Edit Note' : 'Create Note', style: const TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Use ↑↓ to navigate, OK to type', style: TextStyle(color: Colors.white38, fontSize: 13)),

          const SizedBox(height: 28),

          // Title field
          _formField(
            label: 'Title',
            value: _formTitle,
            focused: _formFocus == 0 && !_kbActive,
            active: _kbActive && _kbField == 0,
            onTap: () { _kbField = 0; setState(() { _formFocus = 0; _kbActive = true; }); },
          ),

          const SizedBox(height: 16),

          // Description field
          _formField(
            label: 'Content',
            value: _formDesc,
            focused: _formFocus == 1 && !_kbActive,
            active: _kbActive && _kbField == 1,
            maxLines: 5,
            onTap: () { _kbField = 1; setState(() { _formFocus = 1; _kbActive = true; }); },
          ),

          const SizedBox(height: 24),

          // Color picker row
          const Text('Color', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: List.generate(_colorNames.length, (i) {
            final sel = _colorIdx == i;
            final rowFocused = _formFocus == 2 && !_kbActive;
            return GestureDetector(
              onTap: () => setState(() { _colorIdx = i; _formFocus = 2; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 10),
                width: sel ? 40 : 32, height: sel ? 40 : 32,
                decoration: BoxDecoration(
                  color: _colorSwatches[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel
                        ? (rowFocused ? Colors.white : Colors.white70)
                        : Colors.transparent,
                    width: sel ? 3 : 0,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: _colorSwatches[i].withOpacity(0.6), blurRadius: 10, spreadRadius: 2)]
                      : [],
                ),
              ),
            );
          })),

          const SizedBox(height: 32),

          // Action buttons
          Row(children: [
            _formButton(label: 'Save', focused: _formFocus == 4 && !_kbActive,
              color: const Color(0xFF059669), onTap: _saveForm),
            const SizedBox(width: 16),
            _formButton(label: 'Cancel', focused: _formFocus == 5 && !_kbActive,
              color: Colors.white24,
              onTap: () => setState(() => _screen = _Screen.grid)),
          ]),

          // TV hint
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '📺 ↑↓ navigate fields  •  OK open keyboard\n← → change color  •  Back = cancel',
              style: TextStyle(color: Colors.white24, fontSize: 12, height: 1.6),
            ),
          ),
        ]),
      )),

      // ── Right: live preview ────────────────────────────────
      Expanded(flex: 2, child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Preview', style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: bg.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_formTitle.isNotEmpty)
                Text(_formTitle, style: TextStyle(
                  color: tc, fontSize: 18, fontWeight: FontWeight.w700)),
              if (_formTitle.isNotEmpty) const SizedBox(height: 8),
              if (_formDesc.isNotEmpty)
                Text(_formDesc, style: TextStyle(
                  color: tc.withOpacity(0.8), fontSize: 14, height: 1.5)),
              if (_formTitle.isEmpty && _formDesc.isEmpty)
                Text('Your note preview will\nappear here...', style: TextStyle(
                  color: tc.withOpacity(0.4), fontSize: 14, height: 1.5)),
            ]),
          ),

          // Keyboard
          if (_kbActive) ...[
            const SizedBox(height: 24),
            _buildKeyboard(),
          ],
        ]),
      )),
    ]);
  }

  Widget _formField({
    required String label,
    required String value,
    required bool focused,
    required bool active,
    required VoidCallback onTap,
    int maxLines = 1,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          constraints: BoxConstraints(minHeight: maxLines > 1 ? 120 : 52),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withOpacity(0.12)
                : focused
                    ? Colors.white.withOpacity(0.09)
                    : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFFBF360C)
                  : focused
                      ? Colors.white38
                      : Colors.white.withOpacity(0.1),
              width: active ? 2 : 1.5,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(
              value.isEmpty ? (label == 'Title' ? 'Enter title...' : 'Enter content...') : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.white24 : Colors.white,
                fontSize: 15, height: 1.5,
              ),
            )),
            if (active) Container(width: 2, height: 18,
              color: const Color(0xFFBF360C),
              margin: const EdgeInsets.only(left: 4)),
          ]),
        ),
      ]),
    );
  }

  Widget _formButton({required String label, required bool focused, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: focused ? color : color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? Colors.white : color.withOpacity(0.4),
            width: focused ? 2.5 : 1.5,
          ),
          boxShadow: focused
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)]
              : [],
        ),
        child: Text(label, style: TextStyle(
          color: Colors.white.withOpacity(focused ? 1.0 : 0.7),
          fontSize: 16, fontWeight: FontWeight.w700,
        )),
      ),
    );
  }

  // ── Virtual Keyboard ─────────────────────────────────────────
  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: List.generate(_kbRows.length, (r) {
          final row = _kbRows[r];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(row.length, (c) {
                final key     = row[c];
                final focused = _kbRow == r && _kbCol == c;
                final isWide  = key == 'SPACE' || key == 'DONE';
                return GestureDetector(
                  onTap: () { _kbRow = r; _kbCol = c; _tapKbKey(key); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: isWide ? 80 : 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: focused
                          ? const Color(0xFFBF360C)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: focused ? Colors.white : Colors.white.withOpacity(0.1),
                        width: focused ? 1.5 : 1,
                      ),
                    ),
                    child: Center(child: Text(
                      key == 'SPACE' ? '⎵'
                          : key == '⇧' ? (_kbShift ? '⇧' : '⇧')
                          : key,
                      style: TextStyle(
                        color: focused ? Colors.white : Colors.white70,
                        fontSize: key.length > 2 ? 10 : 13,
                        fontWeight: focused ? FontWeight.w800 : FontWeight.w500,
                      ),
                    )),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  // ── DELETE CONFIRM SCREEN ────────────────────────────────────
  Widget _buildDeleteConfirm() {
    final idx = _deleteTarget;
    final note = (idx != null && idx < _notes.length) ? _notes[idx] : null;
    final ci = note != null ? _colorNames.indexOf(note.color).clamp(0, 6) : 0;
    final bg = _colorSwatches[ci];
    final tc = _colorText[ci];

    return Center(child: Container(
      width: 460,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
          ),
          child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 32),
        ),
        const SizedBox(height: 20),
        const Text('Delete Note?', style: TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        if (note != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (note.title.isNotEmpty)
                Text(note.title, style: TextStyle(color: tc, fontSize: 14, fontWeight: FontWeight.w700)),
              if (note.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note.description,
                    style: TextStyle(color: tc.withOpacity(0.8), fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        const Text('This cannot be undone.', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 28),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _deleteBtn(label: 'Cancel', focused: _deleteFocus == 0,
            color: Colors.white24,
            onTap: () => setState(() => _screen = _Screen.grid)),
          const SizedBox(width: 20),
          _deleteBtn(label: 'Delete', focused: _deleteFocus == 1,
            color: const Color(0xFFDC2626),
            onTap: _doDelete),
        ]),

        const SizedBox(height: 16),
        const Text('← → to select  •  OK to confirm', style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    ));
  }

  Widget _deleteBtn({required String label, required bool focused, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          color: focused ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused ? Colors.white : color.withOpacity(0.5),
            width: focused ? 2.5 : 1.5,
          ),
          boxShadow: focused
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 18, spreadRadius: 3)]
              : [],
        ),
        child: Text(label, style: TextStyle(
          color: Colors.white.withOpacity(focused ? 1 : 0.6),
          fontSize: 16, fontWeight: FontWeight.w700,
        )),
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────
  Widget _buildLoading() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(color: const Color(0xFFF59E0B), strokeWidth: 2.5,
              backgroundColor: Colors.white.withOpacity(0.1)),
          const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFF59E0B), size: 24),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Loading Notes...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    ],
  ));

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A0800),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (_screen != _Screen.grid) { setState(() => _screen = _Screen.grid); }
            else { Navigator.pop(context); }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12)),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        const SizedBox(width: 18),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sticky Notes', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            _screen == _Screen.grid
                ? '${_notes.length} note${_notes.length != 1 ? "s" : ""}'
                : _screen == _Screen.edit ? 'Editing note' : 'New note',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
          ),
        ]),
        const Spacer(),
        if (_saving) ...[
          const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBF360C))),
          const SizedBox(width: 8),
          const Text('Saving...', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 16),
        ],
        if (_screen == _Screen.grid) GestureDetector(
          onTap: _goCreate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Add Note', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFBF360C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBF360C).withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.build_rounded, color: Color(0xFFBF360C), size: 13),
            SizedBox(width: 5),
            Text('Tools', style: TextStyle(color: Color(0xFFBF360C), fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ── Model ────────────────────────────────────────────────────
class _StickyNote {
  final String title, description, color;
  const _StickyNote({required this.title, required this.description, required this.color});

  factory _StickyNote.fromJson(Map<String, dynamic> j) => _StickyNote(
    title:       j['title']?.toString()       ?? '',
    description: j['description']?.toString() ?? '',
    color:       j['color']?.toString()        ?? 'yellow',
  );

  Map<String, dynamic> toJson() => {
    'title': title, 'description': description, 'color': color,
    'left': '10%', 'top': '10%', 'width': 200, 'height': 150, 'z_index': 100,
  };
}