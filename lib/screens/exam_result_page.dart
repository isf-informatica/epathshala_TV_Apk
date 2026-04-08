// screens/exam_result_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'exam_detail_page.dart';

class ExamResultPage extends StatefulWidget {
  final List<McqQuestion> questions;
  final Map<int, int> selectedAnswers;
  final List<dynamic> serverResults; // mcq_exam_question_answer response
  final String examTitle;
  final String examCategory;
  final Map<String, dynamic> loginData;
  final int studentId;
  final int classroomId;
  final int examId;

  const ExamResultPage({
    Key? key,
    required this.questions,
    required this.selectedAnswers,
    required this.serverResults,
    required this.examTitle,
    required this.examCategory,
    required this.loginData,
    required this.studentId,
    required this.classroomId,
    required this.examId,
  }) : super(key: key);

  @override
  _ExamResultPageState createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  final ScrollController _scrollController = ScrollController();
  static const double _scrollStep = 200.0; // ek remote press = 200px scroll

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Server result se score nikalo ─────────────────────────────
  int get _correctCount {
    if (widget.serverResults.isEmpty) return 0;
    return widget.serverResults.where((r) {
      final correct  = r['answer_option']?.toString() ?? '';
      final selected = r['answer']?.toString() ?? '';
      return correct.isNotEmpty && selected.isNotEmpty && correct == selected;
    }).length;
  }

  int get _totalCount {
    return widget.serverResults.isNotEmpty
        ? widget.serverResults.length
        : widget.questions.length;
  }

  int get _attemptedCount {
    if (widget.serverResults.isNotEmpty) {
      return widget.serverResults
          .where((r) => (r['answer']?.toString() ?? '').isNotEmpty)
          .length;
    }
    return widget.selectedAnswers.length;
  }

  int get _wrongCount       => _attemptedCount - _correctCount;
  int get _unattemptedCount => _totalCount - _attemptedCount;
  double get _percentage    =>
      _totalCount > 0 ? (_correctCount / _totalCount * 100) : 0.0;

  Color get _resultColor {
    if (_percentage >= 75) return const Color(0xFF059669);
    if (_percentage >= 50) return const Color(0xFFFFA600);
    return const Color(0xFFDC2626);
  }

  String get _resultMessage {
    if (_percentage >= 90) return 'Outstanding! 🎉';
    if (_percentage >= 75) return 'Great Job! 👏';
    if (_percentage >= 50) return 'Good Effort! 👍';
    return 'Keep Practicing! 💪';
  }

  String get _starsEmoji {
    if (_percentage >= 90) return '⭐⭐⭐';
    if (_percentage >= 60) return '⭐⭐';
    if (_percentage >= 30) return '⭐';
    return '💪';
  }

  // ── TV Remote Navigation ──────────────────────────────────────
  // Keys:
  //   Up    → scroll up
  //   Down  → scroll down
  //   Back  → home pe jao
  //   Enter → home pe jao
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      final target = (_scrollController.offset + _scrollStep)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final target = (_scrollController.offset - _scrollStep)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      // Back = exam list pe jao
      Navigator.of(context).popUntil((r) => r.isFirst);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter  ||
        key == LogicalKeyboardKey.gameButtonA) {
      // OK/Enter = scroll karo ya home pe jao (agar end pe hai)
      final atEnd = _scrollController.hasClients &&
          _scrollController.offset >= _scrollController.position.maxScrollExtent - 10;
      if (atEnd) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        // Scroll down karo
        final target = (_scrollController.offset + _scrollStep)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1C45),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              // TV hint bar
              _buildTvHintBar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildScoreCard(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      widget.serverResults.isNotEmpty
                          ? _buildServerReview()
                          : _buildLocalReview(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TV hint bar ───────────────────────────────────────────────
  Widget _buildTvHintBar() {
    return Container(
      color: const Color(0xFF060F28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _hintChip('▲▼', 'Scroll'),
          const SizedBox(width: 20),
          _hintChip('▲▼ / OK', 'Scroll'),
          const SizedBox(width: 20),
          _hintChip('Back', 'Home pe jao'),
        ],
      ),
    );
  }

  Widget _hintChip(String key, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E55),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: const Color(0xFF0D1A3E),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exam Result',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(widget.examTitle,
                    style: const TextStyle(
                        color: Color(0xFF8B949E), fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Home button (TV remote ke liye clearly visible)
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_rounded, color: Color(0xFF93C5FD), size: 18),
                  SizedBox(width: 6),
                  Text('Home',
                      style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1A3E),
            _resultColor.withOpacity(0.2),
            const Color(0xFF0D1C45),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _resultColor.withOpacity(0.6), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _resultColor.withOpacity(0.25),
            blurRadius: 24, spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(_starsEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            _resultMessage,
            style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          // Score circle
          SizedBox(
            width: 160, height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160, height: 160,
                  child: CircularProgressIndicator(
                    value: _percentage / 100,
                    strokeWidth: 14,
                    backgroundColor: const Color(0xFF1A2E55),
                    valueColor: AlwaysStoppedAnimation(_resultColor),
                  ),
                ),
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _resultColor.withOpacity(0.1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _resultColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$_correctCount / $_totalCount',
                        style: const TextStyle(
                          color: Colors.white70, fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _statCard('Correct',     '$_correctCount',     const Color(0xFF059669), Icons.check_circle_rounded),
      const SizedBox(width: 12),
      _statCard('Wrong',       '$_wrongCount',       const Color(0xFFDC2626), Icons.cancel_rounded),
      const SizedBox(width: 12),
      _statCard('Unattempted', '$_unattemptedCount', const Color(0xFF8B949E), Icons.remove_circle_rounded),
    ]);
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── Server result review ──────────────────────────────────────
  Widget _buildServerReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A3E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: const [
            Text('🔍', style: TextStyle(fontSize: 16)),
            SizedBox(width: 6),
            Text('Question Review',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 14),
        ...List.generate(widget.serverResults.length, (i) {
          final row           = widget.serverResults[i];
          final questionTitle = row['question_title']?.toString() ?? 'Question ${i + 1}';
          final correctOpt    = row['answer_option']?.toString() ?? '';
          final studentOpt    = row['answer']?.toString() ?? '';
          final isSkipped     = studentOpt.isEmpty;
          final isCorrect     = !isSkipped && studentOpt == correctOpt;
          final opts = <String>[];
          for (int j = 1; j <= 10; j++) {
            final v = row['option_$j']?.toString() ?? '';
            if (v.isNotEmpty) opts.add(v);
          }
          debugPrint('[REVIEW] Q$i: correctOpt="$correctOpt" studentOpt="$studentOpt" isCorrect=$isCorrect');

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A3E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSkipped
                    ? const Color(0xFF1A2E55)
                    : isCorrect
                        ? const Color(0xFF059669).withOpacity(0.5)
                        : const Color(0xFFDC2626).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: isSkipped
                              ? const Color(0xFF1A2E55)
                              : isCorrect
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isSkipped
                              ? const Icon(Icons.remove, color: Colors.white54, size: 14)
                              : Icon(
                                  isCorrect ? Icons.check : Icons.close,
                                  color: Colors.white, size: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Q${i + 1}',
                          style: const TextStyle(
                              color: Color(0xFF8B949E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (isSkipped)
                        const Text('Skipped',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12))
                      else if (isCorrect)
                        const Text('Correct',
                            style: TextStyle(color: Color(0xFF059669), fontSize: 12))
                      else
                        const Text('Wrong',
                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(questionTitle,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 10),
                  ...opts.asMap().entries.map((entry) {
                    final idx    = entry.key;
                    final text   = entry.value;
                    final optNum = (idx + 1).toString();
                    final isCorrectOpt  = correctOpt.isNotEmpty && (
                        optNum == correctOpt || text.trim() == correctOpt.trim());
                    final isSelectedOpt = studentOpt.isNotEmpty && (
                        optNum == studentOpt || text.trim() == studentOpt.trim());

                    Color? bgColor;
                    Color borderColor = const Color(0xFF1A2E55);
                    Color textColor   = Colors.white54;

                    if (isCorrectOpt && isSelectedOpt) {
                      bgColor     = const Color(0xFF059669).withOpacity(0.2);
                      borderColor = const Color(0xFF059669);
                      textColor   = const Color(0xFF34D399);
                    } else if (isCorrectOpt && !isSelectedOpt) {
                      bgColor     = const Color(0xFF059669).withOpacity(0.08);
                      borderColor = const Color(0xFF059669).withOpacity(0.5);
                      textColor   = const Color(0xFF6EE7B7);
                    } else if (isSelectedOpt && !isCorrectOpt) {
                      bgColor     = const Color(0xFFDC2626).withOpacity(0.12);
                      borderColor = const Color(0xFFDC2626);
                      textColor   = const Color(0xFFF87171);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: isCorrectOpt
                                  ? const Color(0xFF059669)
                                  : (isSelectedOpt && !isCorrectOpt)
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF1A2E55),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                ['A','B','C','D','E','F','G','H','I','J'][idx.clamp(0,9)],
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(text,
                                style: TextStyle(color: textColor, fontSize: 13)),
                          ),
                          if (isCorrectOpt && isSelectedOpt)
                            const Text('✅', style: TextStyle(fontSize: 14)),
                          if (isCorrectOpt && !isSelectedOpt)
                            const Text('👆', style: TextStyle(fontSize: 14)),
                          if (isSelectedOpt && !isCorrectOpt)
                            const Text('❌', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Fallback: agar server result nahi aaya ────────────────────
  Widget _buildLocalReview() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Result details not available.\nPlease check your internet connection.',
          style: TextStyle(color: Colors.white54, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}