// quiz_screen.dart
// Restyled to match the "Aurora Glass" theme (see bottombar.dart)
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/quiz_result_screen.dart';

// ============================================================
// 2. THEME
// Local accents that ride on top of the shared AppTheme tokens.
// ============================================================
class QuizTheme {
  static const Color selectedBg = Color(0x269B6BFF); // violet @ ~15%
  static const Color divider = Color(0x1FFFFFFF); // white @ 12%

  // Educational-content font. Applied ONLY to actual question /
  // answer text — never to buttons, labels, progress text, dialogs,
  // or any other UI chrome, which all stay on the app-wide Poppins
  // theme font set in main.dart.
  static const String contentFont = 'AbhayaLibre';
}

// ============================================================
// 3. MODELS
// ============================================================

class QuizOption {
  final int id;
  final String optionKey;
  final String optionText;

  QuizOption({
    required this.id,
    required this.optionKey,
    required this.optionText,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as int,
      optionKey: (json['option_key'] ?? '') as String,
      optionText: (json['option_text'] ?? '') as String,
    );
  }
}

class QuizQuestion {
  final int id;
  final String questionText;
  final List<QuizOption> options;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    List<QuizOption> opts = [];

    final rawOptions = j['options'];

    if (rawOptions is List) {
      opts = rawOptions
          .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    return QuizQuestion(
      id: j['id'] as int,
      questionText: (j['question_text'] ?? j['question'] ?? '') as String,
      options: opts,
    );
  }
}

// ============================================================
// 4. QUIZ SCREEN
// ============================================================

class QuizScreen extends StatefulWidget {
  final int quizId;
  final List<QuizQuestion> questions;
  final String subjectName;
  final String difficulty;
  final Color subjectColor;

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.questions,
    required this.subjectName,
    required this.difficulty,
    required this.subjectColor,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  bool _submitting = false;

  QuizQuestion get _currentQuestion => widget.questions[_currentIndex];
  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == widget.questions.length - 1;
  int get _answeredCount => _answers.length;
  int get _unansweredCount => widget.questions.length - _answers.length;
  double get _progress => widget.questions.isEmpty
      ? 0.0
      : (_currentIndex + 1) / widget.questions.length;

  void _selectOption(int optionIndex) {
    setState(() {
      _answers[_currentQuestion.id] = optionIndex;
    });
  }

  void _goToPrevious() {
    if (!_isFirst) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToNext() {
    if (!_isLast) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
    });
    Navigator.pop(context);
  }

  void _skipQuestion() {
    // Remove answer if exists
    setState(() {
      _answers.remove(_currentQuestion.id);
    });
    // Go to next question if not last
    if (!_isLast) {
      _goToNext();
    }
  }

  void _showQuestionNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuestionNavigator(
        totalQuestions: widget.questions.length,
        currentIndex: _currentIndex,
        answers: _answers,
        onQuestionTap: _goToQuestion,
        subjectColor: widget.subjectColor,
      ),
    );
  }

  Future<void> _submitQuiz() async {
    if (_unansweredCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _GlassDialog(
          title: 'Submit Quiz?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Answered',
                      '$_answeredCount',
                      AppTheme.success,
                      Icons.check_circle_rounded,
                    ),
                    _buildStatItem(
                      'Remaining',
                      '$_unansweredCount',
                      AppTheme.danger,
                      Icons.warning_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unanswered questions will be marked as wrong.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Review',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _submitting = true);

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final answersPayload = widget.questions.map((q) {
        final selectedIdx = _answers[q.id];
        return {
          'question_id': q.id,
          'selected_option_id': selectedIdx != null
              ? q.options[selectedIdx].id
              : null,
        };
      }).toList();

      final response = await http
          .post(
            ApiConfig.uri(ApiConfig.quizSubmit),
            headers: ApiConfig.getHeaders(token),
            body: jsonEncode({
              'quiz_id': widget.quizId,
              'answers': answersPayload,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizResultScreen(
              quizId: widget.quizId,
              resultData: json,
              subjectName: widget.subjectName,
              subjectColor: widget.subjectColor,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please log in again.');
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to submit quiz.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const Text('', style: TextStyle(fontSize: 0)),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GlassDialog(
        title: 'Exit Quiz?',
        content: const Text(
          'Your progress won\'t be submitted if you exit now.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    // If user confirmed exit, pop the screen
    if (confirm == true) {
      Navigator.pop(context);
      return false; // Return false to prevent default back behavior
    }

    // User chose to continue
    return false; // Return false to stay on the screen
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B22),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppTheme.backgroundGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Quiz',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'No questions found for this quiz.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B22),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppTheme.backgroundGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildProgressSection(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildQuestionCard(),
                        const SizedBox(height: 20),
                        _buildOptions(),
                        const SizedBox(height: 8),
                        _buildSkipButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR — UI chrome, stays on the default Poppins theme font
  // ============================================================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () async {
              await _onWillPop();
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.subjectName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.violet.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_rounded,
                  color: AppTheme.violet,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_answeredCount/${widget.questions.length}',
                  style: const TextStyle(
                    color: AppTheme.violet,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS SECTION — UI chrome, stays on Poppins
  // ============================================================
  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${widget.questions.length}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(widget.subjectColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUESTION CARD
  // ------------------------------------------------------------
  // EDUCATIONAL CONTENT — this is the actual quiz question text,
  // so it gets AbhayaLibre explicitly. Everything surrounding it
  // (the card chrome, if any were added) stays Poppins.
  //
  // Typography tuned for AbhayaLibre's metrics (it renders smaller
  // than Poppins at the same fontSize), per the readability pass:
  // fontSize 22, weight 600, line-height 1.5, +0.1 letter spacing.
  // ============================================================
  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(radius: 20),
      child: Text(
        _currentQuestion.questionText,
        style: const TextStyle(
          fontFamily: QuizTheme.contentFont,
          color: AppTheme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ============================================================
  // OPTIONS — the "Select the correct answer" label is UI chrome
  // (Poppins); the individual option text handed to _OptionCard
  // is educational content and gets AbhayaLibre inside that widget.
  // ============================================================
  Widget _buildOptions() {
    final options = _currentQuestion.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Select the correct answer',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...List.generate(options.length, (index) {
          final isSelected = _answers[_currentQuestion.id] == index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionCard(
              label: options[index].optionKey,
              text: options[index].optionText,
              selected: isSelected,
              accentColor: widget.subjectColor,
              onTap: () => _selectOption(index),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // SKIP BUTTON — UI chrome, stays Poppins
  // ============================================================
  Widget _buildSkipButton() {
    return Center(
      child: TextButton(
        onPressed: _skipQuestion,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text(
          'Skip Question',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR — UI chrome, stays Poppins
  // ============================================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF14132F).withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Question Navigator Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: IconButton(
              onPressed: _showQuestionNavigator,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.violet,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_answeredCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Previous Button
          OutlinedButton(
            onPressed: _isFirst ? null : _goToPrevious,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              disabledForegroundColor: AppTheme.textSecondary.withValues(
                alpha: 0.4,
              ),
              side: BorderSide(
                color: _isFirst
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 18),
                SizedBox(width: 4),
                Text(
                  'Previous',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Next / Submit Button
          Expanded(
            child: _isLast
                ? ElevatedButton(
                    onPressed: _submitting ? null : _submitQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppTheme.violet.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit Quiz',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.send_rounded, size: 18),
                            ],
                          ),
                  )
                : ElevatedButton(
                    onPressed: _goToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 5. GLASS DIALOG WRAPPER — UI chrome, stays Poppins
// ============================================================
class _GlassDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const _GlassDialog({
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF191735),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            content,
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. OPTION CARD
// ------------------------------------------------------------
// EDUCATIONAL CONTENT — `text` is the actual answer option shown
// to the student, so it gets AbhayaLibre. `label` (the A/B/C/D
// chip) is UI chrome and stays on the default Poppins theme font.
//
// Typography tuned for AbhayaLibre's metrics, per the readability
// pass: fontSize 18, line-height 1.45, +0.1 letter spacing, and
// weight bumped to w600 when selected (w500 otherwise) so answers
// read clearly against the smaller Poppins UI chrome around them.
// ============================================================
class _OptionCard extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio style circle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 12 : 0,
                  height: selected ? 12 : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accentColor : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Label — UI chrome (A/B/C/D chip), stays Poppins
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? accentColor : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Option text — educational content, gets AbhayaLibre
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: QuizTheme.contentFont,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.45,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            // Check mark
            if (selected)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 7. QUESTION NAVIGATOR BOTTOM SHEET — UI chrome, stays Poppins
// (numbers/labels for jumping between questions, not content)
// ============================================================
class _QuestionNavigator extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final Map<int, int> answers;
  final Function(int) onQuestionTap;
  final Color subjectColor;

  const _QuestionNavigator({
    required this.totalQuestions,
    required this.currentIndex,
    required this.answers,
    required this.onQuestionTap,
    required this.subjectColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.58,
      decoration: BoxDecoration(
        color: const Color(0xFF14132F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Question Navigator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(subjectColor, 'Current'),
                _buildLegendItem(AppTheme.success, 'Answered'),
                _buildLegendItem(
                  Colors.white.withValues(alpha: 0.15),
                  'Not Answered',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: totalQuestions,
              itemBuilder: (context, index) {
                final isCurrent = index == currentIndex;
                final isAnswered = answers.containsKey(index);

                Color bgColor;
                Color borderColor;
                if (isCurrent) {
                  bgColor = subjectColor.withValues(alpha: 0.22);
                  borderColor = subjectColor;
                } else if (isAnswered) {
                  bgColor = AppTheme.success.withValues(alpha: 0.18);
                  borderColor = AppTheme.success.withValues(alpha: 0.5);
                } else {
                  bgColor = Colors.white.withValues(alpha: 0.05);
                  borderColor = Colors.white.withValues(alpha: 0.1);
                }

                Color textColor;
                if (isCurrent) {
                  textColor = subjectColor;
                } else if (isAnswered) {
                  textColor = AppTheme.success;
                } else {
                  textColor = AppTheme.textSecondary;
                }

                return GestureDetector(
                  onTap: () => onQuestionTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 8. SHARED WIDGETS — UI chrome, stays Poppins
// ============================================================
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }
}
