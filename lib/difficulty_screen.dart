// difficulty_screen.dart
// ============================================================
// Screen shown after a subject is picked on SubjectsScreen.
// Lets the student choose Easy / Medium / Hard, then starts the quiz.
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/quiz_screen.dart';
import 'package:quiz_lanka/subjects_screen.dart';

class DifficultyScreen extends StatefulWidget {
  final Subject subject;

  const DifficultyScreen({super.key, required this.subject});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  bool _isStarting = false;

  // Helper method to find questions deeply in response — same logic
  // as the old subjects_screen implementation.
  List<dynamic> _findQuestionsDeep(Map<dynamic, dynamic> data) {
    for (var value in data.values) {
      if (value is List) {
        if (value.isNotEmpty && value[0] is Map) {
          final first = value[0] as Map<dynamic, dynamic>;
          if (first.containsKey('question_text') ||
              first.containsKey('question') ||
              first.containsKey('options')) {
            return value;
          }
        }
      } else if (value is Map) {
        final found = _findQuestionsDeep(value);
        if (found.isNotEmpty) {
          return found;
        }
      }
    }
    return [];
  }

  Future<void> _startQuiz(String difficulty) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _StartingQuizDialog(),
    );

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        Navigator.pop(context); // Close loading dialog
        throw Exception('Session expired. Please login again.');
      }

      final response = await http.post(
        ApiConfig.uri(ApiConfig.quizStart),
        headers: ApiConfig.getHeaders(token),
        body: jsonEncode({
          'subject_id': widget.subject.id,
          'difficulty': difficulty,
        }),
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == false) {
          throw Exception(data['message'] ?? 'Failed to start quiz');
        }

        Map<String, dynamic> quizData = {};
        List<dynamic> questionsList = [];
        int quizId = 0;

        if (data.containsKey('quiz') && data['quiz'] is Map) {
          quizData = data['quiz'] as Map<String, dynamic>;
          quizId = quizData['id'] ?? quizData['quiz_id'] ?? 0;
          questionsList = quizData['questions'] ?? [];
        } else if (data.containsKey('data') && data['data'] is Map) {
          final inner = data['data'] as Map<String, dynamic>;
          if (inner.containsKey('quiz')) {
            quizData = inner['quiz'] as Map<String, dynamic>;
          } else {
            quizData = inner;
          }
          quizId = quizData['id'] ?? quizData['quiz_id'] ?? 0;
          questionsList = quizData['questions'] ?? [];
        } else if (data.containsKey('id') || data.containsKey('quiz_id')) {
          quizData = data;
          quizId = data['id'] ?? data['quiz_id'] ?? 0;
          questionsList = data['questions'] ?? [];
        } else if (data.containsKey('questions')) {
          questionsList = data['questions'] as List<dynamic>;
          quizId =
              data['quiz_id'] ??
              data['id'] ??
              DateTime.now().millisecondsSinceEpoch;
        }

        if (questionsList.isEmpty) {
          questionsList = _findQuestionsDeep(data);
        }

        if (questionsList.isEmpty) {
          throw Exception('No questions found in the response');
        }

        if (quizId == 0) {
          throw Exception('Quiz ID not found in the response');
        }

        final questions = questionsList
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                quizId: quizId,
                questions: questions,
                subjectName: widget.subject.name,
                difficulty: difficulty,
                subjectColor: widget.subject.flutterColor,
              ),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please login again.');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to start quiz');
      }
    } catch (e) {
      debugPrint('Error starting quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final color = subject.flutterColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.backgroundGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.35),
                      color.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(subject: subject, color: color),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Difficulty',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Choose a level that matches your confidence',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _DifficultyCard(
                            label: 'Easy',
                            subtitle: 'Great for building the basics',
                            icon: Icons.wb_sunny_rounded,
                            color: AppTheme.success,
                            enabled: !_isStarting,
                            onTap: () => _startQuiz('easy'),
                          ),
                          const SizedBox(height: 14),
                          _DifficultyCard(
                            label: 'Medium',
                            subtitle: 'A balanced challenge to test yourself',
                            icon: Icons.trending_up_rounded,
                            color: AppTheme.warning,
                            enabled: !_isStarting,
                            onTap: () => _startQuiz('medium'),
                          ),
                          const SizedBox(height: 14),
                          _DifficultyCard(
                            label: 'Hard',
                            subtitle: 'For students aiming to master the topic',
                            icon: Icons.local_fire_department_rounded,
                            color: AppTheme.danger,
                            enabled: !_isStarting,
                            onTap: () => _startQuiz('hard'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Top bar — shows the subject the student picked, with its icon
// ------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final Subject subject;
  final Color color;

  const _TopBar({required this.subject, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SubjectIcon(subject: subject, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ready when you are',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Difficulty option card
// ------------------------------------------------------------
class _DifficultyCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                color.withValues(alpha: 0.07),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// "Starting quiz…" dialog
// ------------------------------------------------------------
class _StartingQuizDialog extends StatelessWidget {
  const _StartingQuizDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 60),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF201E4A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.violet, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Starting quiz...',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}