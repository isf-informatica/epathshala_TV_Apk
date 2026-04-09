import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Conditional import: dart:js only on web, stub on mobile
import 'js_stub.dart'
    if (dart.library.js) 'dart:js' as js;

class TextSpeechPage extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const TextSpeechPage({Key? key, required this.loginData}) : super(key: key);

  @override
  _TextSpeechPageState createState() => _TextSpeechPageState();
}

class _TextSpeechPageState extends State<TextSpeechPage>
    with TickerProviderStateMixin {

  // ── TTS Engine (Android only) ────────────────────────────────
  FlutterTts? _tts;

  // ── State ────────────────────────────────────────────────────
  final TextEditingController _textController = TextEditingController();
  TtsState _ttsState = TtsState.stopped;

  double _volume = 1.0;
  double _pitch  = 1.0;
  double _rate   = 0.5;

  List<String> _languages = [];
  String _selectedLanguage = 'en-US';

  // Word highlight (Android only via flutter_tts progress handler)
  int _wordStart = 0;
  int _wordEnd   = 0;

  // ── TV Focus ─────────────────────────────────────────────────
  // 0=textarea(unused TV), 1=speak, 2=pause, 3=stop,
  // 4=lang, 5=vol-, 6=vol+, 7=pitch-, 8=pitch+, 9=rate-, 10=rate+
  int _focusIndex = 1;
  static const int _maxFocus = 10;

  // ── Animation ────────────────────────────────────────────────
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  // ── Common language fallback ─────────────────────────────────
  static const List<String> _fallbackLanguages = [
    'en-US', 'en-GB', 'en-IN',
    'hi-IN', 'mr-IN', 'gu-IN',
    'ta-IN', 'te-IN', 'kn-IN',
    'bn-IN', 'or-IN',
    'fr-FR', 'de-DE', 'es-ES',
    'zh-CN', 'ja-JP', 'ar-SA',
  ];

  // ── Init ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _waveAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    if (kIsWeb) {
      _initWebTts();
    } else {
      _tts = FlutterTts();
      _initAndroidTts();
    }
  }

  // ── Web: window.speechSynthesis ───────────────────────────────
  void _initWebTts() {
    // Voices may not be ready immediately on web — try now + retry after delay
    _loadWebVoices();
    Future.delayed(const Duration(milliseconds: 600), _loadWebVoices);
    Future.delayed(const Duration(milliseconds: 1500), _loadWebVoices);
  }

  void _loadWebVoices() {
    if (!mounted) return;
    try {
      final result = js.context.callMethod('eval', [
        '''(function(){
          var voices = window.speechSynthesis.getVoices();
          return voices.map(function(v){ return v.lang; });
        })()'''
      ]);
      if (result != null) {
        final rawList = result as js.JsArray;
        final langSet = <String>{};
        for (var i = 0; i < rawList.length; i++) {
          final l = rawList[i]?.toString() ?? '';
          if (l.isNotEmpty) langSet.add(l);
        }
        if (langSet.isNotEmpty && mounted) {
          final sorted = langSet.toList()..sort();
          setState(() {
            _languages = sorted;
            if (!sorted.contains(_selectedLanguage)) {
              _selectedLanguage = sorted.contains('en-US') ? 'en-US' : sorted.first;
            }
          });
          return;
        }
      }
    } catch (_) {}
    // Fallback if browser returned nothing
    if (_languages.isEmpty && mounted) {
      setState(() {
        _languages = _fallbackLanguages;
        _selectedLanguage = 'en-US';
      });
    }
  }

  // ── Android: flutter_tts ──────────────────────────────────────
  Future<void> _initAndroidTts() async {
    _tts!.setStartHandler(() => setState(() => _ttsState = TtsState.playing));
    _tts!.setCompletionHandler(() => setState(() => _ttsState = TtsState.stopped));
    _tts!.setPauseHandler(() => setState(() => _ttsState = TtsState.paused));
    _tts!.setContinueHandler(() => setState(() => _ttsState = TtsState.playing));
    _tts!.setErrorHandler((_) => setState(() => _ttsState = TtsState.stopped));

    _tts!.setProgressHandler((text, start, end, word) {
      if (mounted) setState(() { _wordStart = start; _wordEnd = end; });
    });

    try {
      final langs = await _tts!.getLanguages;
      if (langs != null && langs.isNotEmpty) {
        final sorted = List<String>.from(langs)..sort();
        setState(() {
          _languages = sorted;
          _selectedLanguage = sorted.contains('en-US') ? 'en-US' : sorted.first;
        });
      } else {
        setState(() { _languages = _fallbackLanguages; _selectedLanguage = 'en-US'; });
      }
    } catch (_) {
      setState(() { _languages = _fallbackLanguages; _selectedLanguage = 'en-US'; });
    }

    await _tts!.setLanguage(_selectedLanguage);
    await _tts!.setVolume(_volume);
    await _tts!.setPitch(_pitch);
    await _tts!.setSpeechRate(_rate);
    await _tts!.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      try { js.context.callMethod('eval', ['window.speechSynthesis.cancel()']); } catch (_) {}
    } else {
      _tts?.stop();
    }
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  // ── TTS Actions ──────────────────────────────────────────────
  Future<void> _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) { _showSnack('Please enter some text first'); return; }
    if (kIsWeb) {
      _webSpeak(text);
    } else {
      await _tts!.setLanguage(_selectedLanguage);
      await _tts!.setVolume(_volume);
      await _tts!.setPitch(_pitch);
      await _tts!.setSpeechRate(_rate);
      await _tts!.speak(text);
    }
  }

  Future<void> _pause() async {
    if (kIsWeb) {
      if (_ttsState == TtsState.playing) {
        try { js.context.callMethod('eval', ['window.speechSynthesis.pause()']); } catch (_) {}
        setState(() => _ttsState = TtsState.paused);
      } else if (_ttsState == TtsState.paused) {
        try { js.context.callMethod('eval', ['window.speechSynthesis.resume()']); } catch (_) {}
        setState(() => _ttsState = TtsState.playing);
      }
    } else {
      if (_ttsState == TtsState.playing) {
        await _tts!.pause();
      } else if (_ttsState == TtsState.paused) {
        await _tts!.speak(_textController.text.trim());
      }
    }
  }

  Future<void> _stop() async {
    if (kIsWeb) {
      try { js.context.callMethod('eval', ['window.speechSynthesis.cancel()']); } catch (_) {}
    } else {
      await _tts?.stop();
    }
    setState(() { _ttsState = TtsState.stopped; _wordStart = 0; _wordEnd = 0; });
  }

  Future<void> _applyTtsSettings() async {
    if (!kIsWeb && _tts != null) {
      await _tts!.setVolume(_volume);
      await _tts!.setPitch(_pitch);
      await _tts!.setSpeechRate(_rate);
    }
  }

  // ── Web Speech API JS interop ────────────────────────────────
  void _webSpeak(String text) {
    try {
      // Cancel any ongoing speech first
      js.context.callMethod('eval', ['window.speechSynthesis.cancel()']);

      final utterance = js.JsObject(
        js.context['SpeechSynthesisUtterance'] as js.JsFunction,
        [text],
      );

      utterance['lang']   = _selectedLanguage;
      utterance['volume'] = _volume;
      utterance['pitch']  = _pitch;
      // Web Speech rate: 0.1–10 (default 1). flutter_tts rate 0–1 map to 0.5–2x
      utterance['rate']   = 0.5 + (_rate * 1.5);

      // Match voice to language
      try {
        final voiceScript = '''(function(){
          var lang = "$_selectedLanguage";
          var voices = window.speechSynthesis.getVoices();
          for(var i=0;i<voices.length;i++){
            if(voices[i].lang===lang) return voices[i];
          }
          // fallback: match language prefix (e.g. 'en' for 'en-US')
          var prefix = lang.split('-')[0];
          for(var i=0;i<voices.length;i++){
            if(voices[i].lang.startsWith(prefix)) return voices[i];
          }
          return null;
        })()''';
        final voice = js.context.callMethod('eval', [voiceScript]);
        if (voice != null) utterance['voice'] = voice;
      } catch (_) {}

      // Event callbacks
      utterance['onstart']  = js.allowInterop((_) { if (mounted) setState(() => _ttsState = TtsState.playing); });
      utterance['onend']    = js.allowInterop((_) { if (mounted) setState(() { _ttsState = TtsState.stopped; _wordStart = 0; _wordEnd = 0; }); });
      utterance['onpause']  = js.allowInterop((_) { if (mounted) setState(() => _ttsState = TtsState.paused); });
      utterance['onresume'] = js.allowInterop((_) { if (mounted) setState(() => _ttsState = TtsState.playing); });
      utterance['onerror']  = js.allowInterop((_) { if (mounted) setState(() => _ttsState = TtsState.stopped); });

      // Word boundary (for live highlight on web)
      utterance['onboundary'] = js.allowInterop((event) {
        try {
          if (mounted && event['name'] == 'word') {
            final start = (event['charIndex'] as num).toInt();
            final len   = (event['charLength'] as num?)?.toInt() ?? 1;
            setState(() { _wordStart = start; _wordEnd = start + len; });
          }
        } catch (_) {}
      });

      js.context['speechSynthesis'].callMethod('speak', [utterance]);
    } catch (e) {
      _showSnack('Web Speech error: $e');
    }
  }

  // ── Snack ─────────────────────────────────────────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2A0C00),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Highlighted text (live word) ─────────────────────────────
  Widget _buildHighlightedText(String text) {
    if (text.isEmpty || (_wordStart == 0 && _wordEnd == 0)) {
      return Text(
        text.isEmpty ? 'Enter text above to hear it spoken aloud...' : text,
        style: TextStyle(color: text.isEmpty ? Colors.white30 : Colors.white70, fontSize: 16, height: 1.6),
      );
    }
    final before  = text.substring(0, _wordStart.clamp(0, text.length));
    final current = text.substring(_wordStart.clamp(0, text.length), _wordEnd.clamp(0, text.length));
    final after   = text.substring(_wordEnd.clamp(0, text.length));
    return RichText(text: TextSpan(
      style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
      children: [
        TextSpan(text: before),
        TextSpan(text: current, style: const TextStyle(
          color: Color(0xFFBF360C), fontWeight: FontWeight.w700,
          backgroundColor: Color(0x33FFA600),
        )),
        TextSpan(text: after),
      ],
    ));
  }

  // ── TV Key Handler ───────────────────────────────────────────
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
      _stop(); Navigator.maybePop(context); return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp)    { setState(() => _focusIndex = (_focusIndex - 1).clamp(1, _maxFocus)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowDown)  { setState(() => _focusIndex = (_focusIndex + 1).clamp(1, _maxFocus)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowLeft)  { setState(() => _focusIndex = (_focusIndex - 1).clamp(1, _maxFocus)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.arrowRight) { setState(() => _focusIndex = (_focusIndex + 1).clamp(1, _maxFocus)); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.gameButtonA) {
      _activateFocused(); return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activateFocused() {
    switch (_focusIndex) {
      case 1:  _speak(); break;
      case 2:  _pause(); break;
      case 3:  _stop();  break;
      case 5:  setState(() => _volume = (_volume - 0.1).clamp(0.0, 1.0)); _applyTtsSettings(); break;
      case 6:  setState(() => _volume = (_volume + 0.1).clamp(0.0, 1.0)); _applyTtsSettings(); break;
      case 7:  setState(() => _pitch  = (_pitch  - 0.1).clamp(0.5, 2.0)); _applyTtsSettings(); break;
      case 8:  setState(() => _pitch  = (_pitch  + 0.1).clamp(0.5, 2.0)); _applyTtsSettings(); break;
      case 9:  setState(() => _rate   = (_rate   - 0.1).clamp(0.1, 1.0)); _applyTtsSettings(); break;
      case 10: setState(() => _rate   = (_rate   + 0.1).clamp(0.1, 1.0)); _applyTtsSettings(); break;
    }
  }

  bool _isFocused(int idx) => _focusIndex == idx;

  // ── Action Button ────────────────────────────────────────────
  Widget _actionButton({required int focusIdx, required IconData icon, required String label,
      required Color color, required VoidCallback onTap, bool enabled = true}) {
    final focused = _isFocused(focusIdx);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: !enabled ? Colors.white12 : focused ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: focused ? Colors.white : color.withOpacity(0.4), width: focused ? 2.5 : 1.5),
          boxShadow: focused ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16, spreadRadius: 2)] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 22),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Slider Row ───────────────────────────────────────────────
  Widget _sliderRow({required String label, required int decIdx, required int incIdx,
      required double value, required double min, required double max,
      required String displayVal, required VoidCallback onDec, required VoidCallback onInc}) {
    final decF = _isFocused(decIdx);
    final incF = _isFocused(incIdx);
    final pct  = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 76, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        GestureDetector(onTap: onDec, child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: decF ? Colors.white : Colors.white12,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: decF ? Colors.white : Colors.white24),
          ),
          child: Icon(Icons.remove, color: decF ? const Color(0xFF1A0800) : Colors.white, size: 15),
        )),
        const SizedBox(width: 8),
        Expanded(child: Stack(children: [
          Container(height: 5, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(widthFactor: pct, child: Container(height: 5, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFFBF360C)]),
            borderRadius: BorderRadius.circular(3),
          ))),
        ])),
        const SizedBox(width: 8),
        GestureDetector(onTap: onInc, child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: incF ? Colors.white : Colors.white12,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: incF ? Colors.white : Colors.white24),
          ),
          child: Icon(Icons.add, color: incF ? const Color(0xFF1A0800) : Colors.white, size: 15),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text(displayVal,
          style: const TextStyle(color: Color(0xFFBF360C), fontSize: 13, fontWeight: FontWeight.w700),
          textAlign: TextAlign.right)),
      ]),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text      = _textController.text;
    final isPlaying = _ttsState == TtsState.playing;
    final isPaused  = _ttsState == TtsState.paused;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0800),
        body: SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Left panel ────────────────────────────────────
              Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Input box
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0800),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isFocused(0) ? const Color(0xFFBF360C) : Colors.white.withOpacity(0.12), width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Enter Text', style: TextStyle(color: Color(0xFFBF360C), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    ),
                    TextField(
                      controller: _textController, maxLines: 7,
                      style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'Type or paste text here to convert to speech...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ]),
                ),

                const SizedBox(height: 10),

                // Word count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Text(
                      '${text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length} words  •  ${text.length} chars',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const Spacer(),
                    if (text.isNotEmpty)
                      GestureDetector(
                        onTap: () { _textController.clear(); _stop(); setState(() {}); },
                        child: const Text('Clear', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),

                const SizedBox(height: 18),

                // Live preview
                if (text.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF071130),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFBF360C), size: 13),
                        const SizedBox(width: 6),
                        const Text('LIVE PREVIEW', style: TextStyle(color: Color(0xFFBF360C), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        const Spacer(),
                        if (isPlaying)
                          AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (_, __) => Row(
                              children: List.generate(4, (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 3,
                                height: 6 + (7 * _waveAnimation.value * (i % 2 == 0 ? 1.0 : 0.6)),
                                decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2)),
                              )),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      _buildHighlightedText(text),
                    ]),
                  ),
                  const SizedBox(height: 18),
                ],

                // Buttons
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _actionButton(focusIdx: 1, icon: isPlaying ? Icons.volume_up_rounded : Icons.play_circle_fill_rounded,
                    label: isPlaying ? 'Speaking...' : 'Speak', color: const Color(0xFF3B82F6),
                    onTap: _speak, enabled: text.isNotEmpty && !isPlaying),
                  const SizedBox(width: 16),
                  _actionButton(focusIdx: 2, icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    label: isPaused ? 'Resume' : 'Pause', color: const Color(0xFFBF360C),
                    onTap: _pause, enabled: isPlaying || isPaused),
                  const SizedBox(width: 16),
                  _actionButton(focusIdx: 3, icon: Icons.stop_rounded, label: 'Stop',
                    color: const Color(0xFFDC2626), onTap: _stop, enabled: isPlaying || isPaused),
                ]),
              ])),

              const SizedBox(width: 24),

              // ── Right panel: Settings ──────────────────────────
              SizedBox(width: 270, child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0800),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Title
                  const Row(children: [
                    Icon(Icons.tune_rounded, color: Color(0xFFBF360C), size: 16),
                    SizedBox(width: 8),
                    Text('Voice Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // Language
                  const Text('LANGUAGE', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isFocused(4) ? const Color(0xFFBF360C) : Colors.white.withOpacity(0.12)),
                    ),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      value: _languages.contains(_selectedLanguage) ? _selectedLanguage : (_languages.isNotEmpty ? _languages.first : null),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A0800),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      items: _languages.map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      )).toList(),
                      onChanged: (val) { if (val != null) setState(() => _selectedLanguage = val); },
                    )),
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),

                  // Controls
                  const Text('CONTROLS', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),

                  _sliderRow(label: '🔊 Vol', decIdx: 5, incIdx: 6, value: _volume, min: 0, max: 1,
                    displayVal: '${(_volume * 100).round()}%',
                    onDec: () { setState(() => _volume = (_volume - 0.1).clamp(0.0, 1.0)); _applyTtsSettings(); },
                    onInc: () { setState(() => _volume = (_volume + 0.1).clamp(0.0, 1.0)); _applyTtsSettings(); }),

                  _sliderRow(label: '🎵 Pitch', decIdx: 7, incIdx: 8, value: _pitch, min: 0.5, max: 2.0,
                    displayVal: _pitch.toStringAsFixed(1),
                    onDec: () { setState(() => _pitch = (_pitch - 0.1).clamp(0.5, 2.0)); _applyTtsSettings(); },
                    onInc: () { setState(() => _pitch = (_pitch + 0.1).clamp(0.5, 2.0)); _applyTtsSettings(); }),

                  _sliderRow(label: '⏩ Speed', decIdx: 9, incIdx: 10, value: _rate, min: 0.1, max: 1.0,
                    displayVal: _rate.toStringAsFixed(1),
                    onDec: () { setState(() => _rate = (_rate - 0.1).clamp(0.1, 1.0)); _applyTtsSettings(); },
                    onInc: () { setState(() => _rate = (_rate + 0.1).clamp(0.1, 1.0)); _applyTtsSettings(); }),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // Platform badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: (kIsWeb ? const Color(0xFF2563EB) : const Color(0xFF059669)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (kIsWeb ? const Color(0xFF2563EB) : const Color(0xFF059669)).withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Icon(kIsWeb ? Icons.language : Icons.tv_rounded,
                        color: kIsWeb ? const Color(0xFF3B82F6) : const Color(0xFF10B981), size: 13),
                      const SizedBox(width: 7),
                      Text(kIsWeb ? 'Web Speech API' : 'Android TTS',
                        style: TextStyle(color: kIsWeb ? const Color(0xFF3B82F6) : const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // Status dot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isPlaying ? const Color(0xFF3B82F6).withOpacity(0.15)
                           : isPaused  ? const Color(0xFFBF360C).withOpacity(0.15)
                           : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isPlaying ? const Color(0xFF3B82F6).withOpacity(0.4)
                           : isPaused  ? const Color(0xFFBF360C).withOpacity(0.4)
                           : Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying ? const Color(0xFF3B82F6) : isPaused ? const Color(0xFFBF360C) : Colors.white24,
                      )),
                      const SizedBox(width: 8),
                      Text(isPlaying ? 'Speaking' : isPaused ? 'Paused' : 'Ready',
                        style: TextStyle(
                          color: isPlaying ? const Color(0xFF3B82F6) : isPaused ? const Color(0xFFBF360C) : Colors.white38,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // TV hint
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                    child: const Text('📺 TV Remote:\n↑↓ navigate  •  OK activate\nBack to exit',
                      style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.6)),
                  ),
                ]),
              )),
            ]),
          )),
        ])),
      ),
    );
  }

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
          onTap: () { _stop(); Navigator.pop(context); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
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
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Text & Speech', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Text to Speech  •  AI Powered', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
        ]),
        const Spacer(),
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

// ── TTS State ─────────────────────────────────────────────────
enum TtsState { playing, stopped, paused, continued }