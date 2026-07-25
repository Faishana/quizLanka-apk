// subjects_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/quiz_screen.dart';

// ============================================================
// 2. MODELS — unchanged
// ============================================================

class Subject {
  final int id;
  final String name;
  final String? icon;
  final String color;
  final int? questionsCount;

  Subject({
    required this.id,
    required this.name,
    this.icon,
    required this.color,
    this.questionsCount,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as int,
    name: json['name'] as String,
    icon: json['icon'] as String?,
    color: json['color'] as String,
    questionsCount: json['questions_count'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'questions_count': questionsCount,
  };

  Color get flutterColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4E3AE8);
    }
  }
}

// ============================================================
// 3. SUBJECT SERVICE — unchanged
// ============================================================

class SubjectService {
  final http.Client _client = http.Client();

  Future<List<Subject>> getSubjects() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/subjects'),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Could not reach the server. Please try again.');
    } on FormatException {
      throw Exception('Invalid server response. Please try again.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Received an invalid response from the server.');
    }

    if (response.statusCode == 200 && data['success'] == true) {
      final subjectsList = data['subjects'] as List<dynamic>;
      return subjectsList
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode >= 500) {
      throw Exception('Server error. Please try again later.');
    }

    throw Exception(data['message'] ?? 'Failed to load subjects.');
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 4. SUBJECTS SCREEN — updated with KeepAlive, removed bottom bar
// ============================================================

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

// ✅ Step 5: Added AutomaticKeepAliveClientMixin
class _SubjectsScreenState extends State<SubjectsScreen>
    with AutomaticKeepAliveClientMixin {
  final SubjectService _service = SubjectService();
  late Future<List<Subject>> _subjectsFuture;

  int? _expandedSubjectId;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _service.getSubjects();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _subjectsFuture = _service.getSubjects();
    });
  }

  void _toggleExpansion(int subjectId) {
    setState(() {
      if (_expandedSubjectId == subjectId) {
        _expandedSubjectId = null;
      } else {
        _expandedSubjectId = subjectId;
      }
    });
  }

  // ✅ Step 3: Removed _handleBack() method completely

  // Helper method to find questions deeply in response — unchanged
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

  // Start quiz with robust error handling — unchanged, only the
  // loading dialog's visuals were restyled to match the dark theme.
  void _startQuiz(Subject subject, String difficulty) async {
    setState(() {
      _expandedSubjectId = null;
    });

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
        body: jsonEncode({'subject_id': subject.id, 'difficulty': difficulty}),
      );

      Navigator.pop(context); // Close loading dialog

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizScreen(
                quizId: quizId,
                questions: questions,
                subjectName: subject.name,
                difficulty: difficulty,
                subjectColor: subject.flutterColor,
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
      print('Error starting quiz: $e');
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
    }
  }

  @override
  bool get wantKeepAlive => true; // ✅ Step 5: Keep page alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Step 5: Call super.build

    // ✅ Steps 1 & 2: Bottom bar removed, import removed
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ✅ Step 4: Updated TopBar with inline back logic
              _TopBar(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: FutureBuilder<List<Subject>>(
                  future: _subjectsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _LoadingView();
                    }

                    if (snapshot.hasError) {
                      return _ErrorView(
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }

                    final subjects = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      color: AppTheme.violet,
                      backgroundColor: const Color(0xFF14132F),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Select a subject to start your quiz',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: subjects.isEmpty
                                  ? const _EmptyView()
                                  : ListView.separated(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      itemCount: subjects.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (_, index) {
                                        final subject = subjects[index];
                                        final isExpanded =
                                            _expandedSubjectId == subject.id;
                                        return _SubjectCard(
                                          subject: subject,
                                          isExpanded: isExpanded,
                                          onTap: () =>
                                              _toggleExpansion(subject.id),
                                          onStartQuiz: (difficulty) =>
                                              _startQuiz(subject, difficulty),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 5. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 5.0 Top Bar — now only checks canPop, no navigation fallback
// ------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(
                canPop ? Icons.arrow_back_ios_new_rounded : Icons.home_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Choose Subject',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.1 Loading View
// ------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.violet, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Loading subjects…',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.2 Error View
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load subjects',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.violet, AppTheme.cyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
}

// ------------------------------------------------------------
// 5.3 Empty View
// ------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No subjects available',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Subjects for your grade will appear here',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.4 Subject Card with Difficulty Selection
// ------------------------------------------------------------
class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(String) onStartQuiz;

  const _SubjectCard({
    required this.subject,
    required this.isExpanded,
    required this.onTap,
    required this.onStartQuiz,
  });

  IconData _getIcon() {
    final name = subject.name.toLowerCase();
    if (name.contains('math')) return Icons.calculate_outlined;
    if (name.contains('science')) return Icons.science_outlined;
    if (name.contains('english')) return Icons.menu_book_outlined;
    if (name.contains('sinhala')) return Icons.translate_rounded;
    if (name.contains('tamil')) return Icons.translate_rounded;
    if (name.contains('ict') || name.contains('comput')) {
      return Icons.computer_outlined;
    }
    if (name.contains('history')) return Icons.account_balance_outlined;
    if (name.contains('commerce')) return Icons.bar_chart_rounded;
    if (name.contains('bio') || name.contains('biology')) {
      return Icons.eco_outlined;
    }
    if (name.contains('physic')) return Icons.bolt_outlined;
    if (name.contains('chem')) return Icons.science_rounded;
    if (name.contains('geo')) return Icons.public_outlined;
    if (name.contains('art')) return Icons.palette_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final color = subject.flutterColor;
    final questionCount = subject.questionsCount ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: AppTheme.glassCard(radius: 18),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_getIcon(), color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          questionCount > 0
                              ? '$questionCount Practice Questions'
                              : 'No questions available',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? color.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? color : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Difficulty',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DifficultyChip(
                        label: 'Easy',
                        color: AppTheme.success,
                        onTap: () => onStartQuiz('easy'),
                      ),
                      const SizedBox(width: 10),
                      _DifficultyChip(
                        label: 'Medium',
                        color: AppTheme.warning,
                        onTap: () => onStartQuiz('medium'),
                      ),
                      const SizedBox(width: 10),
                      _DifficultyChip(
                        label: 'Hard',
                        color: AppTheme.danger,
                        onTap: () => onStartQuiz('hard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.5 Difficulty Chip
// ------------------------------------------------------------
class _DifficultyChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.6 "Starting quiz…" dialog, restyled to match the theme
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
