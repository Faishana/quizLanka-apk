// lib/quiz_history_screen.dart
// QuizLanka AI — Quiz History Screen
// Restyled to a light "Aurora" theme with soft blue shadows
// Self-contained: models + API + UI in one file

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/quiz_result_screen.dart';

// ─────────────────────────────────────────────
// LIGHT THEME PALETTE (local to this screen)
// ------------------------------------------------------------
// This screen previously relied on AppTheme's dark "Aurora Glass"
// palette (AppTheme.backgroundGradient, .violet, .cyan, .success,
// .warning, .danger, .textPrimary/Secondary, .glassCard). Since
// appTheam.dart isn't part of this file, the light-theme colors
// and shadows are defined here so the screen is self-contained.
// If you want this app-wide, mirror these values into AppTheme.
// ─────────────────────────────────────────────
class _LightTheme {
  static const List<Color> backgroundGradient = [
    Color(0xFFFAFBFF),
    Color(0xFFEAF0FF),
  ];

  static const Color primaryBlue = Color(0xFF3D5CFF);
  static const Color accentCyan = Color(0xFF2FB6C9);
  static const Color violet = Color(0xFF6C5CE7);
  static const Color success = Color(0xFF2FB380);
  static const Color warning = Color(0xFFE0A23B);
  static const Color danger = Color(0xFFE05A5A);

  static const Color textPrimary = Color(0xFF1B2440);
  static const Color textSecondary = Color(0xFF6B7A99);

  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3F6FF);
  static const Color border = Color(0xFFDCE4FF);

  static List<BoxShadow> blueShadow({
    double blur = 24,
    double spread = 0,
    Offset offset = const Offset(0, 10),
    double opacity = 0.16,
  }) {
    return [
      BoxShadow(
        color: primaryBlue.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
    ];
  }

  static BoxDecoration card({double radius = 18}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: blueShadow(),
    );
  }
}

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class _QuizSubject {
  final int id;
  final String name;
  final String color;

  _QuizSubject({required this.id, required this.name, required this.color});

  factory _QuizSubject.fromJson(Map<String, dynamic> j) => _QuizSubject(
    id: j['id'] as int,
    name: j['name'] as String,
    color: (j['color'] as String?) ?? '#6C5CE7',
  );

  Color get flutterColor {
    try {
      return Color(int.parse('FF${color.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _LightTheme.violet;
    }
  }
}

class _QuizHistoryItem {
  final int id;
  final _QuizSubject subject;
  final String quizType;
  final int score;
  final int totalQuestions;
  final double percentage;
  final String completedAt;
  final Map<String, dynamic> rawData; // passed straight to Result screen

  _QuizHistoryItem({
    required this.id,
    required this.subject,
    required this.quizType,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.completedAt,
    required this.rawData,
  });

  factory _QuizHistoryItem.fromJson(Map<String, dynamic> j) {
    final subject = _QuizSubject.fromJson(j['subject'] as Map<String, dynamic>);
    return _QuizHistoryItem(
      id: j['id'] as int,
      subject: subject,
      quizType: (j['quiz_type'] ?? 'practice') as String,
      score: (j['score'] as num?)?.toInt() ?? 0,
      totalQuestions:
          (j['total_questions'] ?? j['total'] as num?)?.toInt() ?? 0,
      percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
      completedAt: (j['completed_at'] ?? '') as String,
      rawData: j,
    );
  }

  String get formattedDate {
    if (completedAt.isEmpty) return '—';
    try {
      final dt = DateTime.parse(completedAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return completedAt;
    }
  }

  String get quizTypeLabel {
    final t = quizType.toLowerCase();
    if (t == 'practice') return 'Practice';
    if (t == 'exam') return 'Exam';
    if (t == 'mock') return 'Mock';
    return quizType.isEmpty
        ? 'Quiz'
        : quizType[0].toUpperCase() + quizType.substring(1);
  }

  Color get percentageColor {
    if (percentage >= 75) return _LightTheme.success;
    if (percentage >= 50) return _LightTheme.warning;
    return _LightTheme.danger;
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

// ✅ Step 3: Added AutomaticKeepAliveClientMixin
class _QuizHistoryScreenState extends State<QuizHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  List<_QuizHistoryItem> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final res = await http
          .get(
            ApiConfig.uri(ApiConfig.quizHistory),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final list =
            (json['data'] ?? json['quizzes'] ?? json['history'] ?? json)
                as List<dynamic>;
        setState(() {
          _history = list
              .map((e) => _QuizHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else if (res.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please log in again.');
      } else {
        throw Exception('Server error (${res.statusCode}).');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true; // ✅ Step 3: Keep page alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Step 3: Call super.build

    // ✅ Steps 1 & 2: Import removed, bottom bar removed
    return Scaffold(
      backgroundColor: _LightTheme.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _LightTheme.backgroundGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // ✅ Step 4: Updated back button with canPop check
          _CircleIconButton(
            icon: Navigator.canPop(context)
                ? Icons.arrow_back_ios_new_rounded
                : Icons.history_rounded,
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Quiz History',
              style: TextStyle(
                color: _LightTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          _CircleIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadHistory,
            accent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_history.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _LightTheme.violet,
      backgroundColor: _LightTheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildSummaryRow(),
          const SizedBox(height: 20),
          const Text(
            'All Quizzes',
            style: TextStyle(
              color: _LightTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._history.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(
                item: item,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizResultScreen(
                        quizId: item.id,
                        resultData: item.rawData,
                        subjectName: item.subject.name,
                        subjectColor: item.subject.flutterColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = _history.length;
    final avgPct = total == 0
        ? 0.0
        : _history.map((h) => h.percentage).reduce((a, b) => a + b) / total;
    final best = total == 0
        ? 0.0
        : _history.map((h) => h.percentage).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            value: total.toString(),
            label: 'Total',
            color: _LightTheme.accentCyan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            value: '${avgPct.toStringAsFixed(0)}%',
            label: 'Average',
            color: _LightTheme.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            value: '${best.toStringAsFixed(0)}%',
            label: 'Best',
            color: _LightTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: _LightTheme.violet,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 16),
          Text(
            'Loading history…',
            style: TextStyle(color: _LightTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
                color: _LightTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _LightTheme.danger.withValues(alpha: 0.25),
                ),
                boxShadow: _LightTheme.blueShadow(
                  blur: 16,
                  offset: const Offset(0, 6),
                  opacity: 0.10,
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: _LightTheme.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load history',
              style: TextStyle(
                color: _LightTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LightTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style:
                  FilledButton.styleFrom(
                    backgroundColor: _LightTheme.violet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ).copyWith(
                    shadowColor: WidgetStateProperty.all(
                      _LightTheme.primaryBlue.withValues(alpha: 0.35),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _LightTheme.violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _LightTheme.violet.withValues(alpha: 0.25),
              ),
              boxShadow: _LightTheme.blueShadow(
                blur: 16,
                offset: const Offset(0, 6),
                opacity: 0.10,
              ),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: _LightTheme.violet,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No quiz history yet',
            style: TextStyle(
              color: _LightTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your first quiz to see history here.',
            style: TextStyle(color: _LightTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HISTORY CARD
// ─────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final _QuizHistoryItem item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.subject.flutterColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _LightTheme.card(radius: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 78,
                color: color.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 14),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    item.subject.name.isNotEmpty ? item.subject.name[0] : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject.name,
                      style: const TextStyle(
                        color: _LightTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(label: item.quizTypeLabel),
                        const SizedBox(width: 6),
                        Text(
                          item.totalQuestions > 0
                              ? '${item.score}/${item.totalQuestions}'
                              : 'Score: ${item.score}',
                          style: const TextStyle(
                            color: _LightTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.formattedDate,
                      style: TextStyle(
                        color: _LightTheme.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: item.percentageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.percentageColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${item.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: item.percentageColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _LightTheme.textSecondary.withValues(alpha: 0.8),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent
              ? _LightTheme.violet.withValues(alpha: 0.12)
              : _LightTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: accent
                ? _LightTheme.violet.withValues(alpha: 0.3)
                : _LightTheme.border,
          ),
          boxShadow: _LightTheme.blueShadow(
            blur: 10,
            offset: const Offset(0, 3),
            opacity: 0.12,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: accent ? _LightTheme.violet : _LightTheme.textPrimary,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _LightTheme.card(radius: 16),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: _LightTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _LightTheme.violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _LightTheme.violet.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _LightTheme.violet,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
