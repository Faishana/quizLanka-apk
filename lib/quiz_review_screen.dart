// review_screen.dart
// Light theme — scrollable single-list review.
// Ticket: all questions viewable in one scroll (no Next/Prev pagination).
// Presentation refreshed to match the light theme used across the app.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';

// ============================================================
// 2. LIGHT THEME TOKENS
// ============================================================
class ReviewTheme {
  // Surfaces
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F3F9);
  static const Color border = Color(0xFFE4E7F0);
  static const Color borderStrong = Color(0xFFCBD1E0);

  // Text
  static const Color textPrimary = Color(0xFF1A1D2B);
  static const Color textSecondary = Color(0xFF5A6072);
  static const Color textMuted = Color(0xFF8A90A2);

  // States
  static const Color primary = AppTheme.violet; // kept violet accent
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE7F7EE);
  static const Color successBorder = Color(0xFFBBE7CE);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color dangerBorder = Color(0xFFF5C6C6);

  // Explanation callout
  static const Color explanationBg = Color(0xFFFFF8EB);
  static const Color explanationBorder = Color(0xFFFBE3B8);
  static const Color explanationAccent = Color(0xFFB45309);
  static const Color explanationText = Color(0xFF5A3F0E);

  // Content font
  static const String contentFont = 'AbhayaLibre';
}

// ============================================================
// 3. MODELS (unchanged)
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
// 4. REVIEW SERVICE (unchanged)
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
// 5. REVIEW SCREEN — SCROLLABLE SINGLE LIST (light theme)
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

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _questionKeys = {};

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
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) =>
      _questionKeys.putIfAbsent(index, () => GlobalKey());

  void _scrollToQuestion(int index) {
    final key = _questionKeys[index];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReviewTheme.background,
      appBar: AppBar(
        title: const Text(
          'Review Answers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ReviewTheme.textPrimary,
          ),
        ),
        backgroundColor: ReviewTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0xFF1A1D2B).withValues(alpha: 0.08),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: ReviewTheme.textPrimary,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: ReviewTheme.border),
        ),
      ),
      body: Stack(
        children: [
          // Soft pastel orbs for subtle depth
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              color: AppTheme.violet.withValues(alpha: 0.10),
              size: 240,
            ),
          ),
          Positioned(
            top: 260,
            left: -80,
            child: _GlowOrb(
              color: ReviewTheme.success.withValues(alpha: 0.08),
              size: 220,
            ),
          ),
          FutureBuilder<ReviewData>(
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
                          .catchError((_) {
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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: ReviewTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ReviewTheme.border),
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            size: 34,
                            color: ReviewTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No review data available.',
                          style: TextStyle(
                            color: ReviewTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Complete a quiz to see your review.',
                          style: TextStyle(
                            color: ReviewTheme.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Header summary
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _ReviewHeader(
                        correctCount: data.correctCount,
                        totalQuestions: data.totalQuestions,
                        scorePercentage: data.scorePercentage,
                      ),
                    ),
                  ),

                  // Jump-to-question chips
                  SliverToBoxAdapter(
                    child: _QuestionChips(
                      total: data.questions.length,
                      onTap: _scrollToQuestion,
                    ),
                  ),

                  // Section title
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        children: [
                          Text(
                            'All Questions',
                            style: TextStyle(
                              color: ReviewTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Question cards
                  SliverList.builder(
                    itemCount: data.questions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        key: _keyFor(index),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _QuestionCard(
                          question: data.questions[index],
                          questionNumber: index + 1,
                        ),
                      );
                    },
                  ),

                  // Done button footer
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ReviewTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.check_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Soft radial glow orb
// ------------------------------------------------------------
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

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
// 6. WIDGETS (light theme)
// ============================================================

// 6.1 Error view
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
                color: ReviewTheme.dangerSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ReviewTheme.dangerBorder),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: ReviewTheme.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load review',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ReviewTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReviewTheme.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 6.2 White card wrapper
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding}) : margin = null;

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
        color: ReviewTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ReviewTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D2B).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// 6.3 Header summary
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
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Score',
              value: '$correctCount/$totalQuestions',
              color: ReviewTheme.primary,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _StatItem(
              label: 'Correct',
              value: '$correctCount',
              color: ReviewTheme.success,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _StatItem(
              label: 'Wrong',
              value: '${totalQuestions - correctCount}',
              color: ReviewTheme.danger,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _StatItem(
              label: 'Percentage',
              value: '${scorePercentage.toStringAsFixed(0)}%',
              color: ReviewTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 34, color: ReviewTheme.border);
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
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: ReviewTheme.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// 6.4 Jump-to-question chips
class _QuestionChips extends StatelessWidget {
  final int total;
  final void Function(int index) onTap;

  const _QuestionChips({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Material(
            color: ReviewTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: ReviewTheme.border, width: 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTap(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: ReviewTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 6.5 Question card
class _QuestionCard extends StatelessWidget {
  final ReviewQuestion question;
  final int questionNumber;

  const _QuestionCard({required this.question, required this.questionNumber});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: number + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ReviewTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$questionNumber',
                  style: const TextStyle(
                    color: ReviewTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(isCorrect: question.isCorrect),
            ],
          ),
          const SizedBox(height: 16),

          // Question text (content font)
          Text(
            question.questionText,
            style: const TextStyle(
              fontFamily: ReviewTheme.contentFont,
              color: ReviewTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.55,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 18),

          // Options
          ...List.generate(question.options.length, (index) {
            final option = question.options[index];
            final isSelected = question.selectedOptionId == option.id;
            final isCorrect = question.correctOptionId == option.id;

            // Default (neutral) styling
            Color bg = ReviewTheme.surface;
            Color borderColor = ReviewTheme.border;
            Color keyBg = ReviewTheme.surfaceMuted;
            Color keyFg = ReviewTheme.textSecondary;
            Color textColor = ReviewTheme.textSecondary;
            IconData? trailingIcon;
            Color? trailingColor;

            if (isCorrect) {
              bg = ReviewTheme.successSoft;
              borderColor = ReviewTheme.success;
              keyBg = ReviewTheme.success;
              keyFg = Colors.white;
              textColor = ReviewTheme.success;
              trailingIcon = Icons.check_circle_rounded;
              trailingColor = ReviewTheme.success;
            } else if (isSelected && !isCorrect) {
              bg = ReviewTheme.dangerSoft;
              borderColor = ReviewTheme.danger;
              keyBg = ReviewTheme.danger;
              keyFg = Colors.white;
              textColor = ReviewTheme.danger;
              trailingIcon = Icons.cancel_rounded;
              trailingColor = ReviewTheme.danger;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: (isCorrect || (isSelected && !isCorrect))
                        ? 1.6
                        : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: keyBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          option.optionKey,
                          style: TextStyle(
                            color: keyFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(
                          fontFamily: ReviewTheme.contentFont,
                          color: textColor,
                          fontSize: 15.5,
                          fontWeight: isCorrect || (isSelected && !isCorrect)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.4,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, color: trailingColor, size: 20),
                    ],
                  ],
                ),
              ),
            );
          }),

          // Status labels below options for clarity
          if (question.selectedOptionId == null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ReviewTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ReviewTheme.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: ReviewTheme.textMuted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Not answered',
                    style: TextStyle(
                      color: ReviewTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Explanation
          if (question.explanation != null &&
              question.explanation!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ReviewTheme.explanationBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ReviewTheme.explanationBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ReviewTheme.explanationAccent.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: ReviewTheme.explanationAccent,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Explanation',
                          style: TextStyle(
                            color: ReviewTheme.explanationAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.explanation!,
                          style: const TextStyle(
                            fontFamily: ReviewTheme.contentFont,
                            color: ReviewTheme.explanationText,
                            fontSize: 14.5,
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCorrect;

  const _StatusBadge({required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? ReviewTheme.success : ReviewTheme.danger;
    final bg = isCorrect ? ReviewTheme.successSoft : ReviewTheme.dangerSoft;
    final border = isCorrect
        ? ReviewTheme.successBorder
        : ReviewTheme.dangerBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            isCorrect ? 'Correct' : 'Wrong',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
