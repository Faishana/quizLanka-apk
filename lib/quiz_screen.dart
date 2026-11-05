// quiz_screen.dart
// Light theme redesign — clean, modern, high-contrast UI.
// + Live quiz timer (Stopwatch + Timer.periodic)
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/quiz_result_screen.dart';

// ============================================================
// 2. LIGHT THEME TOKENS
// ============================================================
class QuizTheme {
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F3F9);
  static const Color border = Color(0xFFE4E7F0);
  static const Color borderStrong = Color(0xFFCBD1E0);

  static const Color textPrimary = Color(0xFF1A1D2B);
  static const Color textSecondary = Color(0xFF5A6072);
  static const Color textMuted = Color(0xFF8A90A2);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE7F7EE);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color warning = Color(0xFFF59E0B);

  static const Color accent = Color(0xFF6C4DFF);
  static const Color accentSoft = Color(0xFFEFEBFF);

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

  // ── Timer state ──────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _formattedTime = '00:00';
  int _durationSeconds = 0;

  QuizQuestion get _currentQuestion => widget.questions[_currentIndex];
  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == widget.questions.length - 1;
  int get _answeredCount => _answers.length;
  int get _unansweredCount => widget.questions.length - _answers.length;
  double get _progress => widget.questions.isEmpty
      ? 0.0
      : (_currentIndex + 1) / widget.questions.length;

  // ── Lifecycle ────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Start the live timer as soon as the quiz screen is ready.
    // The backend already recorded `started_at` when /quiz/start was called,
    // so this stopwatch is purely for the live UI display.
    _startQuizTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ── Timer helpers ────────────────────────────────────────
  void _startQuizTimer() {
    if (_stopwatch.isRunning) {
      // Resume from where we paused (used after a failed submit).
      _timer?.cancel();
    } else {
      _stopwatch.start();
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _durationSeconds = _stopwatch.elapsed.inSeconds;
        _formattedTime = _formatDuration(_durationSeconds);
      });
    });
  }

  void _stopQuizTimer() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ── Answer / navigation ──────────────────────────────────
  void _selectOption(int optionIndex) {
    setState(() {
      _answers[_currentQuestion.id] = optionIndex;
    });
  }

  void _goToPrevious() {
    if (!_isFirst) setState(() => _currentIndex--);
  }

  void _goToNext() {
    if (!_isLast) setState(() => _currentIndex++);
  }

  void _goToQuestion(int index) {
    Navigator.pop(context);
    setState(() => _currentIndex = index);
  }

  void _skipQuestion() {
    setState(() => _answers.remove(_currentQuestion.id));
    if (!_isLast) _goToNext();
  }

  void _showQuestionNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QuestionNavigator(
        totalQuestions: widget.questions.length,
        currentIndex: _currentIndex,
        answeredIds: _answers.keys.toSet(),
        questions: widget.questions,
        onQuestionTap: _goToQuestion,
        subjectColor: widget.subjectColor,
      ),
    );
  }

  // ── Submit ───────────────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_unansweredCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _LightDialog(
          title: 'Submit Quiz?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: QuizTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: QuizTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _dialogStat(
                        'Answered',
                        '$_answeredCount',
                        QuizTheme.success,
                        QuizTheme.successSoft,
                      ),
                    ),
                    Container(width: 1, height: 40, color: QuizTheme.border),
                    Expanded(
                      child: _dialogStat(
                        'Remaining',
                        '$_unansweredCount',
                        QuizTheme.warning,
                        const Color(0xFFFFF4E0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Unanswered questions will be marked as wrong.',
                style: TextStyle(
                  color: QuizTheme.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: QuizTheme.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Review',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuizTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // Stop the live timer BEFORE sending the request.
    _stopQuizTimer();
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

        // The backend is the source of truth — use its duration.
        final durationSeconds =
            (json['duration_seconds'] as num?)?.toInt() ??
            _stopwatch.elapsed.inSeconds;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizResultScreen(
              quizId: widget.quizId,
              resultData: json,
              subjectName: widget.subjectName,
              subjectColor: widget.subjectColor,
              durationSeconds: durationSeconds,
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
      // Submission failed — resume the timer so the user's time is intact.
      _startQuizTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: QuizTheme.danger,
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

  Widget _dialogStat(String label, String value, Color color, Color bg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: QuizTheme.textMuted,
            fontSize: 11.5,
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
      builder: (context) => _LightDialog(
        title: 'Exit Quiz?',
        content: const Text(
          'Your progress won\'t be submitted if you exit now.',
          style: TextStyle(
            color: QuizTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: QuizTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuizTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      Navigator.pop(context);
    }
    return false;
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: QuizTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                        color: QuizTheme.textPrimary,
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
                      color: QuizTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: QuizTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProgressSection(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildQuestionCard(),
                      const SizedBox(height: 22),
                      _buildOptions(),
                      const SizedBox(height: 4),
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
    );
  }

  // ============================================================
  // TOP BAR (with timer chip)
  // ============================================================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () async => await _onWillPop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subjectName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuizTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.difficulty[0].toUpperCase()}${widget.difficulty.substring(1)} • ${widget.questions.length} questions',
                  style: const TextStyle(
                    color: QuizTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Live timer chip ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFF2563EB),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          // Answered count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.subjectColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.subjectColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fact_check_rounded,
                  color: widget.subjectColor,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  '$_answeredCount/${widget.questions.length}',
                  style: TextStyle(
                    color: widget.subjectColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
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
  // PROGRESS SECTION
  // ============================================================
  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${widget.questions.length}',
                style: const TextStyle(
                  color: QuizTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}% complete',
                style: const TextStyle(
                  color: QuizTheme.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: QuizTheme.surfaceMuted,
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
  // ============================================================
  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: QuizTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D2B).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: widget.subjectColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.subjectColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QUESTION ${_currentIndex + 1}',
                        style: TextStyle(
                          color: widget.subjectColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentQuestion.questionText,
                      style: const TextStyle(
                        fontFamily: QuizTheme.contentFont,
                        color: QuizTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPTIONS
  // ============================================================
  Widget _buildOptions() {
    final options = _currentQuestion.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.subjectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Select the correct answer',
                style: TextStyle(
                  color: QuizTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
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

  Widget _buildSkipButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _skipQuestion,
        style: TextButton.styleFrom(
          foregroundColor: QuizTheme.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        icon: const Icon(Icons.skip_next_rounded, size: 18),
        label: const Text(
          'Skip Question',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: QuizTheme.surface,
        border: Border(top: BorderSide(color: QuizTheme.border)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D2B).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showQuestionNavigator,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: QuizTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QuizTheme.border),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: QuizTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.subjectColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_answeredCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _isFirst ? null : _goToPrevious,
              style: OutlinedButton.styleFrom(
                foregroundColor: QuizTheme.textPrimary,
                disabledForegroundColor: QuizTheme.textMuted,
                side: BorderSide(
                  color: _isFirst ? QuizTheme.border : QuizTheme.borderStrong,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: _isLast
                  ? ElevatedButton(
                      onPressed: _submitting ? null : _submitQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.subjectColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: widget.subjectColor.withValues(
                          alpha: 0.5,
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
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.send_rounded, size: 18),
                              ],
                            ),
                    )
                  : ElevatedButton(
                      onPressed: _goToNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.subjectColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
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
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 5. LIGHT DIALOG WRAPPER
// ============================================================
class _LightDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const _LightDialog({
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: QuizTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: QuizTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1D2B).withValues(alpha: 0.12),
              blurRadius: 32,
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
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: QuizTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            content,
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. OPTION CARD
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.07)
              : QuizTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : QuizTheme.border,
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF1A1D2B).withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: selected ? accentColor : QuizTheme.borderStrong,
                  width: 1.8,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.14)
                    : QuizTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? accentColor : QuizTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: QuizTheme.contentFont,
                  color: selected
                      ? QuizTheme.textPrimary
                      : QuizTheme.textSecondary,
                  fontSize: 17,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.45,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 7. QUESTION NAVIGATOR
// ============================================================
class _QuestionNavigator extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final Set<int> answeredIds;
  final List<QuizQuestion> questions;
  final Function(int) onQuestionTap;
  final Color subjectColor;

  const _QuestionNavigator({
    required this.totalQuestions,
    required this.currentIndex,
    required this.answeredIds,
    required this.questions,
    required this.onQuestionTap,
    required this.subjectColor,
  });

  bool _isAnswered(int index) => answeredIds.contains(questions[index].id);

  @override
  Widget build(BuildContext context) {
    final answeredCount = List.generate(
      totalQuestions,
      _isAnswered,
    ).where((v) => v).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: const BoxDecoration(
        color: QuizTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: QuizTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question Navigator',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: QuizTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$answeredCount of $totalQuestions answered',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: QuizTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: QuizTheme.textSecondary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: QuizTheme.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: QuizTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QuizTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legend(subjectColor, 'Current'),
                _legend(QuizTheme.success, 'Answered'),
                _legend(QuizTheme.borderStrong, 'Not answered'),
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
                final isAnswered = _isAnswered(index);

                Color bg;
                Color border;
                Color fg;
                if (isCurrent) {
                  bg = subjectColor.withValues(alpha: 0.12);
                  border = subjectColor;
                  fg = subjectColor;
                } else if (isAnswered) {
                  bg = QuizTheme.successSoft;
                  border = QuizTheme.success.withValues(alpha: 0.4);
                  fg = QuizTheme.success;
                } else {
                  bg = QuizTheme.surface;
                  border = QuizTheme.border;
                  fg = QuizTheme.textSecondary;
                }

                return GestureDetector(
                  onTap: () => onQuestionTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: border,
                        width: isCurrent ? 2 : 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: fg,
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: subjectColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: QuizTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 8. CIRCLE ICON BUTTON
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
          color: QuizTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: QuizTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1D2B).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: QuizTheme.textPrimary),
      ),
    );
  }
}
