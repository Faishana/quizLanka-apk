// review_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';

// ============================================================
// 2. THEME — Aurora Glass, matching Dashboard / Profile / Nav.
// If appTheam.dart already exposes matching tokens (background
// gradient, glass card color, primary text color), swap those
// in below instead of the hardcoded fallbacks so every screen
// pulls from one source of truth.
// ============================================================
class ReviewTheme {
  static const Color primary = AppTheme.violet;
  static const Color bgTop = Color(0xFF0E0C29);
  static const Color bgBottom = Color(0xFF1B1540);
  static const Color card = Color(0xFF1C1A3D);
  static const Color cardBorder = Colors.white;
  static const Color textDark = Colors.white; // primary text, kept name for
  // minimal diff with original file
  static const Color textMid = Color(0xFFA0A3BD);
  static const Color textLight = Color(0xFF6B6890);
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFEF5A6C);
  static const Color divider = Color(0xFF2A2854);
  static const Color explanationBg = Color(0xFF352A12);
  static const Color explanationBorder = Color(0xFF6B4E16);
  static const Color explanationAccent = Color(0xFFFBBF52);
  static const Color explanationText = Color(0xFFF4D9A0);
  static const Color shadow = Color(0x66000000);

  // Educational-content font. Applied ONLY to actual question /
  // answer / explanation text — never to buttons, labels, badges,
  // or other UI chrome, which all stay on the app-wide Poppins
  // theme font set in main.dart.
  static const String contentFont = 'AbhayaLibre';
}

// ============================================================
// 3. MODELS  (unchanged)
// ============================================================

class ReviewOption {
  final int id;
  final String optionKey;
  final String optionText;

  ReviewOption({
    required this.id,
    required this.optionKey,
    required this.optionText,
  });

  factory ReviewOption.fromJson(Map<String, dynamic> json) {
    return ReviewOption(
      id: json['id'] as int? ?? 0,
      optionKey:
          (json['option_key'] ?? json['key'] ?? json['label'] ?? '') as String,
      optionText:
          (json['option_text'] ?? json['text'] ?? json['value'] ?? '')
              as String,
    );
  }
}

class ReviewQuestion {
  final int questionId;
  final String questionText;
  final List<ReviewOption> options;
  final int? selectedOptionId;
  final int correctOptionId;
  final bool isCorrect;
  final String? explanation;

  ReviewQuestion({
    required this.questionId,
    required this.questionText,
    required this.options,
    this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    this.explanation,
  });

  factory ReviewQuestion.fromJson(Map<String, dynamic> json) {
    final questionId = json['question_id'] ?? json['id'] ?? 0;
    final questionText =
        json['question_text'] ??
        json['question'] ??
        json['text'] ??
        'Question text not available';

    List<ReviewOption> options = [];

    if (json['options'] != null) {
      final optionsList = json['options'] as List<dynamic>;
      options = optionsList
          .map((o) => ReviewOption.fromJson(o as Map<String, dynamic>))
          .toList();
    } else if (json['answers'] != null) {
      final optionsList = json['answers'] as List<dynamic>;
      options = optionsList
          .map((o) => ReviewOption.fromJson(o as Map<String, dynamic>))
          .toList();
    } else if (json['choices'] != null) {
      final optionsList = json['choices'] as List<dynamic>;
      options = optionsList
          .map((o) => ReviewOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    if (options.isEmpty) {
      options = [
        ReviewOption(id: 1, optionKey: 'A', optionText: 'Option A'),
        ReviewOption(id: 2, optionKey: 'B', optionText: 'Option B'),
        ReviewOption(id: 3, optionKey: 'C', optionText: 'Option C'),
        ReviewOption(id: 4, optionKey: 'D', optionText: 'Option D'),
      ];
    }

    return ReviewQuestion(
      questionId: questionId,
      questionText: questionText,
      options: options,
      selectedOptionId:
          json['selected_option_id'] ??
          json['user_answer_id'] ??
          json['user_answer'] as int?,
      correctOptionId:
          json['correct_option_id'] ??
          json['correct_answer_id'] ??
          json['correct_answer'] ??
          0,
      isCorrect: json['is_correct'] ?? json['correct'] ?? false,
      explanation: json['explanation'] ?? json['explain'] as String?,
    );
  }
}

class ReviewData {
  final List<ReviewQuestion> questions;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final double scorePercentage;

  ReviewData({
    required this.questions,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.scorePercentage,
  });

  factory ReviewData.fromJson(Map<String, dynamic> json) {
    List<dynamic> questionsList = [];

    if (json['answers'] != null) {
      questionsList = json['answers'] as List<dynamic>;
    } else if (json['questions'] != null) {
      questionsList = json['questions'] as List<dynamic>;
    } else if (json['data'] != null && json['data']['questions'] != null) {
      questionsList = json['data']['questions'] as List<dynamic>;
    } else if (json['results'] != null) {
      questionsList = json['results'] as List<dynamic>;
    } else if (json['items'] != null) {
      questionsList = json['items'] as List<dynamic>;
    }

    final questions = questionsList
        .map((q) => ReviewQuestion.fromJson(q))
        .toList();

    final quiz = json['quiz'];

    return ReviewData(
      questions: questions,
      totalQuestions: quiz?['total_questions'] ?? questions.length,
      correctCount: quiz?['correct_answers'] ?? 0,
      wrongCount: quiz?['wrong_answers'] ?? 0,
      scorePercentage: (quiz?['percentage'] ?? 0).toDouble(),
    );
  }

  factory ReviewData.empty() {
    return ReviewData(
      questions: [],
      totalQuestions: 0,
      correctCount: 0,
      wrongCount: 0,
      scorePercentage: 0.0,
    );
  }
}

// ============================================================
// 4. REVIEW SERVICE  (unchanged — logic untouched)
// ============================================================

class ReviewService {
  final http.Client _client = http.Client();

  Future<ReviewData> getReview(int quizId) async {
    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final url = ApiConfig.uri(ApiConfig.quizReview(quizId));
      print('🔄 Requesting review URL: $url');

      final response = await _client.get(
        url,
        headers: ApiConfig.getHeaders(token),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          return ReviewData.fromJson(data);
        } else if (data['questions'] != null) {
          final wrappedData = {'success': true, 'questions': data['questions']};
          return ReviewData.fromJson(wrappedData);
        } else if (data['data'] != null) {
          final wrappedData = {
            'success': true,
            'questions': data['data']['questions'] ?? [],
          };
          return ReviewData.fromJson(wrappedData);
        } else {
          throw Exception(data['message'] ?? 'Failed to load review data.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Review data not found for this quiz.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getReview: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 5. REVIEW SCREEN
// ============================================================

class ReviewScreen extends StatefulWidget {
  final int quizId;

  const ReviewScreen({super.key, required this.quizId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ReviewService _service = ReviewService();
  late Future<ReviewData> _reviewFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _service.getReview(widget.quizId).catchError((error) {
      print('Error loading review: $error');
      return ReviewData.empty();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToNext(ReviewData data) {
    if (_currentIndex < data.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: ReviewTheme.bgTop,
      appBar: AppBar(
        title: const Text(
          'Review Answers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ReviewTheme.textDark,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: ReviewTheme.textDark,
        ),
      ),
      body: Stack(
        children: [
          // Aurora background — same soft glow-blob treatment as
          // Dashboard / Profile so this screen feels like one app.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ReviewTheme.bgTop, ReviewTheme.bgBottom],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: _GlowBlob(
                      color: AppTheme.violet.withValues(alpha: 0.26),
                      size: 220,
                    ),
                  ),
                  Positioned(
                    top: 220,
                    left: -60,
                    child: _GlowBlob(
                      color: ReviewTheme.success.withValues(alpha: 0.12),
                      size: 200,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<ReviewData>(
              future: _reviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ReviewTheme.primary,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: () {
                      setState(() {
                        _reviewFuture = _service
                            .getReview(widget.quizId)
                            .catchError((error) {
                              return ReviewData.empty();
                            });
                      });
                    },
                  );
                }

                final data = snapshot.data!;
                if (data.questions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 64,
                            color: ReviewTheme.textLight,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No review data available.',
                            style: TextStyle(
                              color: ReviewTheme.textMid,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete a quiz to see your review.',
                            style: TextStyle(
                              color: ReviewTheme.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 8),
                    // Header Summary
                    _ReviewHeader(
                      correctCount: data.correctCount,
                      totalQuestions: data.totalQuestions,
                      scorePercentage: data.scorePercentage,
                    ),
                    const SizedBox(height: 12),

                    // Progress
                    _QuestionProgress(
                      currentIndex: _currentIndex,
                      totalQuestions: data.totalQuestions,
                    ),
                    const SizedBox(height: 12),

                    // Question Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _QuestionCard(
                          question: data.questions[_currentIndex],
                          questionNumber: _currentIndex + 1,
                        ),
                      ),
                    ),

                    // Bottom Navigation
                    _BottomNav(
                      currentIndex: _currentIndex,
                      totalQuestions: data.totalQuestions,
                      onPrevious: _goToPrevious,
                      onNext: () => _goToNext(data),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Soft radial glow blob used for the aurora background
// ------------------------------------------------------------
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

// ============================================================
// 6. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 6.1 Error View — UI chrome, stays Poppins
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    String displayMessage = message.replaceFirst('Exception: ', '');
    if (displayMessage.contains('ClientException')) {
      displayMessage = 'Network error. Please check your internet connection.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ReviewTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ReviewTheme.danger.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ReviewTheme.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ReviewTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ReviewTheme.textMid, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ReviewTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.2 Glass card wrapper — shared look for header / question card
// ------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ReviewTheme.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ReviewTheme.cardBorder.withValues(alpha: 0.08),
        ),
        boxShadow: const [
          BoxShadow(
            color: ReviewTheme.shadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------
// 6.3 Review Header — UI chrome (stats), stays Poppins
// ------------------------------------------------------------
class _ReviewHeader extends StatelessWidget {
  final int correctCount;
  final int totalQuestions;
  final double scorePercentage;

  const _ReviewHeader({
    required this.correctCount,
    required this.totalQuestions,
    required this.scorePercentage,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Score',
            value: '$correctCount/$totalQuestions',
            color: ReviewTheme.primary,
          ),
          _StatItem(
            label: 'Correct',
            value: '$correctCount',
            color: ReviewTheme.success,
          ),
          _StatItem(
            label: 'Wrong',
            value: '${totalQuestions - correctCount}',
            color: ReviewTheme.danger,
          ),
          _StatItem(
            label: 'Percentage',
            value: '${scorePercentage.toStringAsFixed(0)}%',
            color: ReviewTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ReviewTheme.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 6.4 Question Progress — UI chrome, stays Poppins
// ------------------------------------------------------------
class _QuestionProgress extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;

  const _QuestionProgress({
    required this.currentIndex,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions > 0
        ? (currentIndex + 1) / totalQuestions
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentIndex + 1} of $totalQuestions',
                style: const TextStyle(
                  color: ReviewTheme.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: ReviewTheme.textMid,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: ReviewTheme.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ReviewTheme.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.5 Question Card
// ------------------------------------------------------------
class _QuestionCard extends StatelessWidget {
  final ReviewQuestion question;
  final int questionNumber;

  const _QuestionCard({required this.question, required this.questionNumber});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number and status — UI chrome, stays Poppins
            Row(
              children: [
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(
                    color: ReviewTheme.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: question.isCorrect
                        ? ReviewTheme.success.withValues(alpha: 0.14)
                        : ReviewTheme.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        question.isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: question.isCorrect
                            ? ReviewTheme.success
                            : ReviewTheme.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        question.isCorrect ? 'Correct' : 'Wrong',
                        style: TextStyle(
                          color: question.isCorrect
                              ? ReviewTheme.success
                              : ReviewTheme.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question text — EDUCATIONAL CONTENT, gets AbhayaLibre
            Text(
              question.questionText,
              style: const TextStyle(
                fontFamily: ReviewTheme.contentFont,
                color: ReviewTheme.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),

            // Options
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];
              final isSelected = question.selectedOptionId == option.id;
              final isCorrect = question.correctOptionId == option.id;

              Color bgColor = Colors.white.withValues(alpha: 0.03);
              Color borderColor = ReviewTheme.divider;
              IconData? trailingIcon;
              Color? trailingColor;

              if (isCorrect) {
                bgColor = ReviewTheme.success.withValues(alpha: 0.12);
                borderColor = ReviewTheme.success;
                trailingIcon = Icons.check_circle_rounded;
                trailingColor = ReviewTheme.success;
              } else if (isSelected && !isCorrect) {
                bgColor = ReviewTheme.danger.withValues(alpha: 0.12);
                borderColor = ReviewTheme.danger;
                trailingIcon = Icons.cancel_rounded;
                trailingColor = ReviewTheme.danger;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: (isCorrect || (isSelected && !isCorrect))
                          ? 2
                          : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Label — UI chrome (A/B/C/D chip), stays Poppins
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? ReviewTheme.success
                              : isSelected && !isCorrect
                              ? ReviewTheme.danger
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            option.optionKey,
                            style: TextStyle(
                              color: isCorrect || (isSelected && !isCorrect)
                                  ? Colors.white
                                  : ReviewTheme.textMid,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Option text — EDUCATIONAL CONTENT, gets AbhayaLibre
                      Expanded(
                        child: Text(
                          option.optionText,
                          style: TextStyle(
                            fontFamily: ReviewTheme.contentFont,
                            color: isCorrect
                                ? ReviewTheme.success
                                : isSelected && !isCorrect
                                ? ReviewTheme.danger
                                : ReviewTheme.textDark,
                            fontSize: 14,
                            fontWeight: isCorrect || (isSelected && !isCorrect)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // Status icon
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: trailingColor, size: 20),
                      const SizedBox(width: 4),
                      // Labels — UI chrome, stays Poppins
                      if (isCorrect)
                        const Text(
                          'Correct Answer',
                          style: TextStyle(
                            color: ReviewTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (isSelected && !isCorrect)
                        const Text(
                          'Your Answer',
                          style: TextStyle(
                            color: ReviewTheme.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            // Explanation
            if (question.explanation != null &&
                question.explanation!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ReviewTheme.explanationBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ReviewTheme.explanationBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: ReviewTheme.explanationAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Explanation" label — UI chrome, stays Poppins
                          const Text(
                            'Explanation',
                            style: TextStyle(
                              color: ReviewTheme.explanationAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Explanation body — EDUCATIONAL CONTENT,
                          // gets AbhayaLibre
                          Text(
                            question.explanation!,
                            style: const TextStyle(
                              fontFamily: ReviewTheme.contentFont,
                              color: ReviewTheme.explanationText,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.6 Bottom Navigation — UI chrome, stays Poppins
// ------------------------------------------------------------
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _BottomNav({
    required this.currentIndex,
    required this.totalQuestions,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentIndex == 0;
    final isLast = currentIndex == totalQuestions - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: ReviewTheme.card.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: ReviewTheme.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Previous Button
          OutlinedButton(
            onPressed: isFirst ? null : onPrevious,
            style: OutlinedButton.styleFrom(
              foregroundColor: ReviewTheme.primary,
              disabledForegroundColor: ReviewTheme.textLight,
              side: BorderSide(
                color: isFirst ? ReviewTheme.divider : ReviewTheme.primary,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
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
          const SizedBox(width: 12),

          // Next / Done Button
          Expanded(
            child: isLast
                ? ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ReviewTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.check_rounded, size: 18),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ReviewTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
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
