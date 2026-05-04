// screens/exam_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'exam_result_page.dart';

// ── correct_option parse karo — multiple formats handle ──────────
// Format 1: "3"        → 3  (direct number, 1-based)
// Format 2: "option_3" → 3  (option_N string)
// Format 3: "c"        → 3  (a=1, b=2, c=3...)
int _parseCorrectOption(String raw) {
  if (raw.isEmpty) return 0;
  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;
  final optMatch = RegExp(r'option_?(\d+)', caseSensitive: false).firstMatch(raw);
  if (optMatch != null) return int.tryParse(optMatch.group(1) ?? '0') ?? 0;
  if (raw.length == 1) {
    final letter = raw.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
    if (letter >= 1 && letter <= 10) return letter;
  }
  return 0;
}

// ── MCQ Question model ────────────────────────────────────────────
class McqQuestion {
  final String id;
  final String questionTitle;
  final String questionImage;
  final List<String> options;
  final int correctOption; // 1-based

  const McqQuestion({
    required this.id,
    required this.questionTitle,
    required this.questionImage,
    required this.options,
    required this.correctOption,
  });

  factory McqQuestion.fromJson(Map<String, dynamic> json) {
    final opts = <String>[];
    for (int i = 1; i <= 10; i++) {
      opts.add(json['option_$i']?.toString() ?? '');
    }
    final rawCorrect = (json['answer_option']?.toString() ?? '').isNotEmpty
        ? json['answer_option'].toString()
        : json['correct_option']?.toString() ?? '';
    final parsedCorrect = _parseCorrectOption(rawCorrect);
    print('[MCQ] Q: ${json['question_title']?.toString().substring(0, (json['question_title']?.toString().length ?? 0).clamp(0, 20))} | correct_option raw="$rawCorrect" parsed=$parsedCorrect | opts=${opts.where((o) => o.isNotEmpty).toList()}');

    return McqQuestion(
      id:            json['id']?.toString() ?? '',
      questionTitle: json['question_title']?.toString() ?? '',
      questionImage: json['question_image']?.toString() ?? '',
      options:       opts,
      correctOption: parsedCorrect,
    );
  }
}

// ── ExamDetailPage ────────────────────────────────────────────────
class ExamDetailPage extends StatefulWidget {
  final int examId;
  final String examUniqueId;
  final int studentId;
  final int classroomId;
  final String examTitle;
  final String examCategory;
  final String examDuration;
  final int questionsCount;
  final String uniqueIdString;
  final Map<String, dynamic> loginData;

  const ExamDetailPage({
    Key? key,
    required this.examId,
    required this.examUniqueId,
    required this.studentId,
    required this.classroomId,
    required this.examTitle,
    required this.examCategory,
    required this.examDuration,
    required this.questionsCount,
    required this.uniqueIdString,
    required this.loginData,
  }) : super(key: key);

  @override
  _ExamDetailPageState createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage> {
  List<McqQuestion> _questions = [];
  bool _loading = true;
  bool _submitting = false;
  String _error = '';
  int _currentPage = 0;

  // TV Remote: highlighted option index (0-based), -1 = none highlighted
  int _focusedOptionIndex = 0;

  // key=questionIndex (0-based), value=selectedOptionIndex (0-based)
  final Map<int, int> _selectedAnswers = {};
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchMcqQuestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Step 1: Questions fetch ───────────────────────────────────
  Future<void> _fetchMcqQuestions() async {
    setState(() { _loading = true; _error = ''; });

    final results = await ApiService.getMcqQuestions(
      examId:      widget.examUniqueId,
      studentId:   widget.studentId.toString(),
      classroomId: widget.classroomId.toString(),
    );

    if (!mounted) return;
    if (results.isNotEmpty) {
      setState(() {
        _questions = results.map((e) => McqQuestion.fromJson(e)).toList();
        _loading = false;
        _focusedOptionIndex = 0;
      });
    } else {
      setState(() {
        _error = 'No questions found for this exam.';
        _loading = false;
      });
    }
  }

  // ── Step 2: Option select — local save + server save ─────────
  void _selectOption(int questionIdx, int optionIdx) {
    setState(() {
      _selectedAnswers[questionIdx] = optionIdx;
    });
    print('[EXAM] Q$questionIdx → opt$optionIdx | total: ${_selectedAnswers.length}');

    ApiService.saveAnswer(
      examId:     widget.examUniqueId,
      accountId:  widget.studentId.toString(),
      questionId: _questions[questionIdx].id,
      option:     (optionIdx + 1).toString(),
    );
  }

  // ── Step 3: Submit — result page pe jao ──────────────────────
  Future<void> _submitExam() async {
    setState(() => _submitting = true);

    final serverResults = await ApiService.getExamResult(
      studentId: widget.studentId.toString(),
      examId:    widget.examUniqueId,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExamResultPage(
          questions:       _questions,
          selectedAnswers: Map<int, int>.from(_selectedAnswers),
          serverResults:   serverResults,
          examTitle:       widget.examTitle,
          examCategory:    widget.examCategory,
          loginData:       widget.loginData,
          studentId:       widget.studentId,
          classroomId:     widget.classroomId,
          examId:          widget.examId,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── TV Remote — Full Navigation ───────────────────────────────
  // Keys:
  //   Up/Down   → option highlight move karo
  //   Enter/OK  → highlighted option select karo (ya submit agar last Q)
  //   Right     → next question (ya submit agar last Q)
  //   Left      → previous question
  //   Back/Esc  → navigator pop
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_loading || _questions.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ── UP: option highlight upra jao ──────────────────────────
    if (key == LogicalKeyboardKey.arrowUp) {
      final visibleOpts = _visibleOptionsCount(_currentPage);
      if (visibleOpts > 0) {
        setState(() {
          _focusedOptionIndex =
              (_focusedOptionIndex - 1 + visibleOpts) % visibleOpts;
        });
      }
      return KeyEventResult.handled;
    }

    // ── DOWN: option highlight neecha jao ──────────────────────
    if (key == LogicalKeyboardKey.arrowDown) {
      final visibleOpts = _visibleOptionsCount(_currentPage);
      if (visibleOpts > 0) {
        setState(() {
          _focusedOptionIndex = (_focusedOptionIndex + 1) % visibleOpts;
        });
      }
      return KeyEventResult.handled;
    }

    // ── ENTER / SELECT / OK: sirf option select karo, navigate mat karo ───
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      final visibleOpts = _visibleOptionsCount(_currentPage);
      if (visibleOpts > 0 && _focusedOptionIndex < visibleOpts) {
        _selectOption(_currentPage, _focusedOptionIndex);
        // Enter = select karo, phir automatically next pe jao (better UX)
        // Lekin last question pe submit nahi karo — user ko confirm karna chahiye
        if (_currentPage < _questions.length - 1) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _nextQuestion();
          });
        }
      }
      return KeyEventResult.handled;
    }

    // ── RIGHT: next question ────────────────────────────────────
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_currentPage == _questions.length - 1) {
        // Last question pe confirm dialog dikhao
        _showSubmitConfirmDialog();
      } else {
        _nextQuestion();
      }
      return KeyEventResult.handled;
    }

    // ── LEFT: previous question ─────────────────────────────────
    if (key == LogicalKeyboardKey.arrowLeft) {
      _prevQuestion();
      return KeyEventResult.handled;
    }

    // ── BACK / ESC: wapas jao ───────────────────────────────────
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // Kitne visible options hain current question pe
  int _visibleOptionsCount(int questionIdx) {
    if (_questions.isEmpty || questionIdx >= _questions.length) return 0;
    return _questions[questionIdx]
        .options
        .where((o) => o.isNotEmpty)
        .length;
  }

  void _showSubmitConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Exam?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Aapne ${_selectedAnswers.length} / ${_questions.length} sawaalon ke jawab diye hain.\nKya aap exam submit karna chahte hain?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBF360C),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (!_submitting) _submitExam();
            },
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _nextQuestion() {
    if (_currentPage < _questions.length - 1) {
      setState(() {
        _currentPage++;
        _focusedOptionIndex = 0; // naye question pe pehla option highlight
      });
      _pageController.animateToPage(_currentPage,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevQuestion() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _focusedOptionIndex = 0;
      });
      _pageController.animateToPage(_currentPage,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  String _formatDuration(String d) {
    try {
      final mins = int.parse(d);
      return mins < 60
          ? '$mins min'
          : '${mins ~/ 60} hr${mins % 60 > 0 ? ' : ${mins % 60} min' : ''}';
    } catch (_) { return d; }
  }

  // ── Main Build ────────────────────────────────────────────────
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
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: const Color(0xFF1A0800),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.examTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${widget.examCategory} • ${_formatDuration(widget.examDuration)} • ${widget.questionsCount} Questions',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_loading && _questions.isNotEmpty)
            _submitting
                ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Color(0xFFBF360C), strokeWidth: 2.5))
                : ElevatedButton(
              onPressed: _submitExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBF360C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Submit',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Color(0xFFBF360C)),
          SizedBox(height: 16),
          Text('Loading Questions...',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ]),
      );
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
          const SizedBox(height: 16),
          Text(_error,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchMcqQuestions,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBF360C),
                foregroundColor: Colors.black),
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    if (_questions.isEmpty) {
      return const Center(
          child: Text('No questions available.',
              style: TextStyle(color: Colors.white70, fontSize: 18)));
    }
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(child: _buildPageView()),
        _buildNavButtons(),
      ],
    );
  }

  // ── Progress bar + dots ───────────────────────────────────────
  static const List<String> _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
  static const List<Color> _optionColors = [
    Color(0xFF6366F1), // A - Indigo
    Color(0xFF059669), // B - Green
    Color(0xFF0EA5E9), // C - Sky Blue
    Color(0xFFF59E0B), // D - Amber
    Color(0xFF8B5CF6), // E - Purple
    Color(0xFFEC4899), // F - Pink
    Color(0xFF14B8A6), // G - Teal
    Color(0xFF6366F1), // H - Indigo
  ];

  Widget _buildProgressBar() {
    final answered  = _selectedAnswers.length;
    final total     = _questions.length;
    final progress  = total > 0 ? (_currentPage + 1) / total : 0.0;

    return Container(
      color: const Color(0xFF1A0800),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Q ${_currentPage + 1} of $total',
                style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: answered > 0
                    ? const Color(0xFF059669).withOpacity(0.2)
                    : const Color(0xFF2A0C00),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: answered > 0
                      ? const Color(0xFF059669).withOpacity(0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, size: 11,
                    color: answered > 0 ? const Color(0xFF059669) : Colors.white38),
                const SizedBox(width: 4),
                Text('$answered answered',
                    style: TextStyle(
                      color: answered > 0 ? const Color(0xFF4ADE80) : Colors.white38,
                      fontSize: 10, fontWeight: FontWeight.w600,
                    )),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2A0C00),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFBF360C)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(total, (i) {
              final isAnswered = _selectedAnswers.containsKey(i);
              final isCurrent  = i == _currentPage;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentPage = i;
                    _focusedOptionIndex = 0;
                  });
                  _pageController.animateToPage(i,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isCurrent ? 32 : 26,
                  height: isCurrent ? 32 : 26,
                  decoration: BoxDecoration(
                    gradient: isCurrent
                        ? const LinearGradient(
                      colors: [Color(0xFFBF360C), Color(0xFFFF6B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : isAnswered
                        ? const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                    )
                        : null,
                    color: (!isCurrent && !isAnswered) ? const Color(0xFF2A0C00) : null,
                    borderRadius: BorderRadius.circular(isCurrent ? 10 : 6),
                    boxShadow: isCurrent
                        ? [BoxShadow(
                        color: const Color(0xFFBF360C).withOpacity(0.6),
                        blurRadius: 8, spreadRadius: 1)]
                        : [],
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFFFD700)
                          : isAnswered
                          ? const Color(0xFF34D399)
                          : Colors.white12,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                          color: (isCurrent || isAnswered) ? Colors.white : Colors.white38,
                          fontSize: isCurrent ? 13 : 10,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  // ── TV remote hint bar ────────────────────────────────────────
  Widget _buildTvHintBar() {
    return Container(
      color: const Color(0xFF060F28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _hintChip('▲▼', 'Option choose'),
          const SizedBox(width: 16),
          _hintChip('OK', 'Select & Next'),
          const SizedBox(width: 16),
          _hintChip('◄ ►', 'Prev / Next'),
          const SizedBox(width: 16),
          _hintChip('Back', 'Exit'),
        ],
      ),
    );
  }

  Widget _hintChip(String key, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2A0C00),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF3B82F6), width: 1),
        ),
        child: Text(key,
            style: const TextStyle(
                color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }

  // ── PageView ──────────────────────────────────────────────────
  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      itemCount: _questions.length,
      onPageChanged: (i) => setState(() {
        _currentPage = i;
        _focusedOptionIndex = 0;
      }),
      itemBuilder: (ctx, i) => _buildQuestionCard(i),
    );
  }

  // ── Single question card ──────────────────────────────────────
  Widget _buildQuestionCard(int questionIdx) {
    final question = _questions[questionIdx];

    return StatefulBuilder(
      builder: (context, setCardState) {
        final selectedOptionIdx = _selectedAnswers[questionIdx];
        final visibleOptions = question.options
            .asMap()
            .entries
            .where((e) => e.value.isNotEmpty)
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Question card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF1A0800)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFBF360C), Color(0xFFFF6B00)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${questionIdx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            question.questionTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Options — evenly fill remaining space ─────
                  Expanded(
                    child: Column(
                      children: List.generate(visibleOptions.length, (i) {
                        final entry = visibleOptions[i];
                        final optIdx = entry.key;
                        final optText = entry.value;
                        final isSelected = selectedOptionIdx == optIdx;
                        final isTvFocused = _focusedOptionIndex == i;
                        final label = optIdx < _optionLabels.length ? _optionLabels[optIdx] : '${optIdx + 1}';
                        final optColor = optIdx < _optionColors.length ? _optionColors[optIdx] : const Color(0xFF6366F1);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _selectOption(questionIdx, optIdx);
                              setCardState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [optColor, optColor.withOpacity(0.7)],
                                )
                                    : null,
                                color: isSelected ? null : const Color(0xFF1A0800),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTvFocused && !isSelected ? Colors.white : isSelected ? optColor : optColor.withOpacity(0.3),
                                  width: isTvFocused || isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: optColor.withOpacity(0.45), blurRadius: 14, spreadRadius: 1, offset: const Offset(0, 4))]
                                    : isTvFocused
                                    ? [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 10, spreadRadius: 1)]
                                    : [],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : isTvFocused ? optColor.withOpacity(0.35) : optColor.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.transparent : isTvFocused ? Colors.white : optColor.withOpacity(0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(label, style: TextStyle(color: optColor, fontSize: 14, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: TextStyle(
                                      color: isSelected || isTvFocused ? Colors.white : Colors.white70,
                                      fontSize: 15,
                                      fontWeight: isSelected || isTvFocused ? FontWeight.w700 : FontWeight.w400,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isTvFocused && !isSelected)
                                  Container(
                                    width: 26, height: 26,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
                                  ),
                                if (isSelected)
                                  Container(
                                    width: 26, height: 26,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                  ),
                              ]),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Prev / Next buttons — big fun style ────────────────────
  Widget _buildNavButtons() {
    final isFirst = _currentPage == 0;
    final isLast  = _currentPage == _questions.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TV remote hint bar
        _buildTvHintBar(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF1A0800),
            border: Border(top: BorderSide(color: Color(0xFF2A0C00), width: 1)),
          ),
          child: Row(children: [
            // Previous button
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isFirst ? 0.35 : 1.0,
                child: GestureDetector(
                  onTap: isFirst ? null : _prevQuestion,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0C00),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A3E6A), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text('Previous',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Next / Submit button
            Expanded(
              child: isLast
                  ? _submitting
                  ? Container(
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBF360C), Color(0xFFFF6B00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                ),
              )
                  : GestureDetector(
                onTap: _submitExam,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF360C), Color(0xFFFF6B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBF360C).withOpacity(0.5),
                        blurRadius: 14, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Submit Exam',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              )
                  : GestureDetector(
                onTap: _nextQuestion,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 12, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}