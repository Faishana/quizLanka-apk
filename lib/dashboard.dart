// dashboard_screen.dart
// QuizLanka AI — Student / Candidate dashboard (navy + gold design)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart' show TokenStorage, LoginScreen;
import 'package:quiz_lanka/ProfileScreen.dart';
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/past_paper_subject_selection_screen.dart';
import 'package:quiz_lanka/quiz_history_screen.dart';
import 'package:quiz_lanka/subjects_screen.dart';

// ============================================================
// 1. SMALL PARSING HELPERS
// ============================================================
int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _toNullableInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _toDouble(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : 0;
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

// ============================================================
// 2. MODELS (same JSON contract as before)
// ============================================================
class Grade {
  final int id;
  final String name;

  Grade({required this.id, required this.name});

  factory Grade.fromJson(Map<String, dynamic> json) =>
      Grade(id: _toInt(json['id']), name: (json['name'] ?? '').toString());

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class User {
  final int id;
  final String name;
  final String email;
  final String? school;
  final String? district;
  final Grade? grade;
  final String? avatarUrl;
  final String? userCategory;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.school,
    this.district,
    this.grade,
    this.avatarUrl,
    this.userCategory,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? avatarUrl;
    for (final key in const [
      'display_avatar',
      'profile_image',
      'avatar_url',
      'avatar',
      'profile_photo',
    ]) {
      final v = json[key];
      if (v != null && v.toString().isNotEmpty) {
        avatarUrl = v.toString();
        break;
      }
    }

    Grade? parsedGrade;
    final rawGrade = json['grade'];
    if (rawGrade is Map<String, dynamic> && rawGrade['id'] != null) {
      parsedGrade = Grade.fromJson(rawGrade);
    }

    return User(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      school: json['school'] is String ? json['school'] as String : null,
      district: json['district'] is String ? json['district'] as String : null,
      grade: parsedGrade,
      avatarUrl: avatarUrl,
      userCategory: json['user_category'] is String
          ? json['user_category'] as String
          : null,
    );
  }

  String get _normalizedCategory => (userCategory ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool get isStudent => _normalizedCategory == 'student';

  bool get isGovernmentExamCandidate {
    final c = _normalizedCategory;
    return c == 'government exam candidate' ||
        c == 'government exam' ||
        c == 'gov exam candidate' ||
        c == 'govt exam candidate' ||
        c == 'government';
  }

  /// Government candidate: explicit category, or no category and no grade.
  bool get _treatAsGovernment =>
      isGovernmentExamCandidate || (grade == null && !isStudent);

  String get subtitleLabel {
    if (_treatAsGovernment) {
      return (district != null && district!.isNotEmpty)
          ? 'Government Exam Candidate · $district'
          : 'Government Exam Candidate';
    }
    final g = grade;
    if (g != null) {
      final parts = <String>[g.name];
      if (school != null && school!.isNotEmpty) parts.add(school!);
      return parts.join(' · ');
    }
    return district ?? 'QuizLanka AI learner';
  }

  /// 'grade5' | 'ol' | 'al' | 'government' | 'general'
  /// 'general' = a student in Grade 6–9 (no past-paper category exists).
  String get pastPaperCategory {
    if (_treatAsGovernment) return 'government';

    final name = grade?.name.trim().toLowerCase() ?? '';
    final n = int.tryParse(RegExp(r'\d+').firstMatch(name)?.group(0) ?? '');

    if (n == 5 || name.contains('scholarship')) return 'grade5';
    if (n == 10 ||
        n == 11 ||
        name.contains('ordinary') ||
        name.contains('o/l')) {
      return 'ol';
    }
    if (n == 12 ||
        n == 13 ||
        name.contains('advanced') ||
        name.contains('a/l')) {
      return 'al';
    }
    return 'general';
  }
}

class Stats {
  final int selectedSubjects;
  final int completedQuizzes;
  final double averageScore;
  final int? xpPoints;
  final int? streakDays;
  final int? notificationsCount;

  Stats({
    required this.selectedSubjects,
    required this.completedQuizzes,
    required this.averageScore,
    this.xpPoints,
    this.streakDays,
    this.notificationsCount,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    selectedSubjects: _toInt(json['selected_subjects']),
    completedQuizzes: _toInt(json['completed_quizzes']),
    averageScore: _toDouble(json['average_score']),
    xpPoints: _toNullableInt(json['xp_points']),
    streakDays: _toNullableInt(json['streak_days']),
    notificationsCount: _toNullableInt(json['notifications_count']),
  );
}

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
    id: _toInt(json['id']),
    name: (json['name'] as String?) ?? 'Unknown Subject',
    icon: json['icon'] as String?,
    color: (json['color'] as String?) ?? '#2563EB',
    questionsCount: _toNullableInt(json['questions_count']),
  );

  Color get flutterColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }
}

class ContinueLearning {
  final int quizId;
  final Subject subject;
  final int lastScore;
  final double lastPercentage;
  final String completedAt;
  final int? recommendedQuizCount;
  final int? minutesLeft;

  ContinueLearning({
    required this.quizId,
    required this.subject,
    required this.lastScore,
    required this.lastPercentage,
    required this.completedAt,
    this.recommendedQuizCount,
    this.minutesLeft,
  });

  factory ContinueLearning.fromJson(Map<String, dynamic> json) =>
      ContinueLearning(
        quizId: _toInt(json['quiz_id']),
        subject: Subject.fromJson(
          (json['subject'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
        lastScore: _toInt(json['last_score']),
        lastPercentage: _toDouble(json['last_percentage']),
        completedAt: (json['completed_at'] ?? '').toString(),
        recommendedQuizCount: _toNullableInt(json['recommended_quiz_count']),
        minutesLeft: _toNullableInt(json['minutes_left']),
      );
}

class RecentQuiz {
  final int id;
  final Subject subject;
  final String quizType;
  final int score;
  final double percentage;
  final String completedAt;

  RecentQuiz({
    required this.id,
    required this.subject,
    required this.quizType,
    required this.score,
    required this.percentage,
    required this.completedAt,
  });

  factory RecentQuiz.fromJson(Map<String, dynamic> json) => RecentQuiz(
    id: _toInt(json['id']),
    subject: Subject.fromJson(
      (json['subject'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
    quizType: (json['quiz_type'] ?? '').toString(),
    score: _toInt(json['score']),
    percentage: _toDouble(json['percentage']),
    completedAt: (json['completed_at'] ?? '').toString(),
  );
}

class DashboardModel {
  final bool success;
  final User user;
  final Stats stats;
  final ContinueLearning? continueLearning;
  final List<Subject> subjects;
  final List<RecentQuiz> recentQuizzes;

  DashboardModel({
    required this.success,
    required this.user,
    required this.stats,
    this.continueLearning,
    required this.subjects,
    required this.recentQuizzes,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final rawRecent = json['recent_quizzes'];
    final rawSubjects = json['subjects'];

    return DashboardModel(
      success: json['success'] as bool? ?? false,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      stats: Stats.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      continueLearning: json['continue_learning'] is Map<String, dynamic>
          ? ContinueLearning.fromJson(
              json['continue_learning'] as Map<String, dynamic>,
            )
          : null,
      subjects: rawSubjects is List
          ? rawSubjects
                .whereType<Map<String, dynamic>>()
                .map(Subject.fromJson)
                .toList()
          : <Subject>[],
      recentQuizzes: rawRecent is List
          ? rawRecent
                .whereType<Map<String, dynamic>>()
                .map(RecentQuiz.fromJson)
                .toList()
          : <RecentQuiz>[],
    );
  }
}

// ============================================================
// 3. SERVICE
// ============================================================
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Your session has expired. Please log in again.';
}

class DashboardService {
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _get(String url) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) throw SessionExpiredException();

    http.Response response;
    try {
      response = await _client
          .get(Uri.parse(url), headers: ApiConfig.getHeaders(token))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Could not reach the server. Please try again.');
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw SessionExpiredException();
    }

    if (response.statusCode >= 500) {
      throw Exception('Server error. Please try again later.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Received an invalid response from the server.');
    }

    if (response.statusCode == 200 && data['success'] == true) return data;

    throw Exception(data['message'] ?? 'Request failed.');
  }

  Future<DashboardModel> getDashboard() async {
    final data = await _get('${ApiConfig.baseUrl}${ApiConfig.dashboard}');
    return DashboardModel.fromJson(data);
  }

  Future<List<Subject>> getSubjects() async {
    final data = await _get('${ApiConfig.baseUrl}/subjects');
    final list = data['subjects'];
    if (list is! List) {
      throw Exception('Invalid subjects data received from server.');
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(Subject.fromJson)
        .toList();
  }

  void dispose() => _client.close();
}

// ============================================================
// 4. LOCAL LOOK
// ============================================================
class _D {
  _D._();

  static const Color bg = Color(0xFFF1F5FC);
  static const Color success = Color(0xFF1B7F4B);
  static const Color tint = Color(0xFFEAF0FF);

  static BoxDecoration card({double radius = 22}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFDCE4F4)),
    boxShadow: const [
      BoxShadow(color: Color(0x14123066), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );

  static double hPad(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= 600 ? 36 : 20;

  static double maxWidth(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= 600 ? 680 : double.infinity;
}

// ============================================================
// 5. DASHBOARD SCREEN
// ============================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final DashboardService _service = DashboardService();

  DashboardModel? _dashboard;
  List<Subject>? _subjects;
  String? _error;
  String? _subjectsError;
  bool _sessionExpired = false;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<({List<Subject>? data, String? error})> _safeSubjects() async {
    try {
      return (data: await _service.getSubjects(), error: null);
    } catch (e) {
      return (data: null, error: _clean(e));
    }
  }

  /// Loads both endpoints in parallel. Existing content stays on screen
  /// while refreshing, so pull-to-refresh never flashes a spinner.
  Future<void> _load() async {
    if (_dashboard == null) setState(() => _loading = true);

    final subjectsFuture = _safeSubjects();

    try {
      final d = await _service.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = d;
        _error = null;
        _sessionExpired = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _sessionExpired = true;
        _error = SessionExpiredException().toString();
        _dashboard = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_dashboard == null) {
        setState(() => _error = _clean(e));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: QL.danger,
            content: Text(_clean(e)),
          ),
        );
      }
    }

    final s = await subjectsFuture;
    if (!mounted) return;
    setState(() {
      if (s.data != null) _subjects = s.data;
      _subjectsError = s.error;
      _loading = false;
    });
  }

  Future<void> _reloadSubjects() async {
    setState(() => _subjectsError = null);
    final s = await _safeSubjects();
    if (!mounted) return;
    setState(() {
      if (s.data != null) _subjects = s.data;
      _subjectsError = s.error;
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _push(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => _load());
  }

  void _openPastPapers(String category, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PastPaperSubjectSelectionScreen(category: category, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(backgroundColor: _D.bg, body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _dashboard == null) {
      return const Center(
        child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
      );
    }

    final data = _dashboard;
    if (data == null) {
      return _ErrorView(
        message: _error ?? 'Something went wrong.',
        sessionExpired: _sessionExpired,
        onRetry: _load,
        onLogin: _goToLogin,
      );
    }

    final hPad = _D.hPad(context);

    return RefreshIndicator(
      onRefresh: _load,
      color: QL.blue,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _HeroHeader(
            user: data.user,
            greeting: _greeting(),
            xp: data.stats.xpPoints,
            streakDays: data.stats.streakDays,
            notificationsCount: data.stats.notificationsCount,
            onAvatarTap: () =>
                _push(ProfileScreen(key: ValueKey(data.user.id))),
            onBellTap: () => _push(const QuizHistoryScreen()),
          ),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _D.maxWidth(context)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.continueLearning != null)
                        _ContinueLearningCard(
                          data: data.continueLearning!,
                          onResume: () => _push(const SubjectsScreen()),
                        )
                      else
                        _StatsSummaryCard(stats: data.stats),
                      const SizedBox(height: 26),
                      _SectionTitle(_quickAccessTitle(data.user)),
                      const SizedBox(height: 12),
                      _buildQuickAccess(data.user),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionTitle('Subjects'),
                          _ViewAllButton(
                            onTap: () => _push(const SubjectsScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSubjects(),
                      const SizedBox(height: 26),
                      const _BattleComingSoonCard(),
                      const SizedBox(height: 26),
                      const _SectionTitle('Your recent activity'),
                      const SizedBox(height: 12),
                      _RecentActivityCard(
                        user: data.user,
                        stats: data.stats,
                        recentQuizzes: data.recentQuizzes,
                        onViewAll: () => _push(const QuizHistoryScreen()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _quickAccessTitle(User user) {
    switch (user.pastPaperCategory) {
      case 'grade5':
        return 'Grade 5 past papers';
      case 'ol':
        return 'O/L past papers';
      case 'al':
        return 'A/L past papers';
      case 'general':
        return 'Quick practice';
      default:
        return 'Government exam papers';
    }
  }

  Widget _buildQuickAccess(User user) {
    switch (user.pastPaperCategory) {
      case 'grade5':
        return _QuickAccessTile(
          icon: Icons.grade_rounded,
          title: 'Grade 5 Scholarship',
          subtitle: 'Practise real past papers',
          onTap: () => _openPastPapers('primary', 'Grade 5 Past Papers'),
        );
      case 'ol':
        return _QuickAccessTile(
          icon: Icons.quiz_rounded,
          title: 'O/L Past Papers',
          subtitle: 'Practise real past papers',
          onTap: () => _openPastPapers('ol', 'O/L Past Papers'),
        );
      case 'al':
        return _QuickAccessTile(
          icon: Icons.school_rounded,
          title: 'A/L Past Papers',
          subtitle: 'Practise real past papers',
          onTap: () => _openPastPapers('al', 'A/L Past Papers'),
        );
      case 'general':
        return _QuickAccessTile(
          icon: Icons.bolt_rounded,
          title: 'Practise by subject',
          subtitle: 'Pick a subject and start a quiz',
          onTap: () => _push(const SubjectsScreen()),
        );
      default:
        return _QuickAccessTile(
          icon: Icons.assignment_rounded,
          title: 'Government Exam Papers',
          subtitle: 'Practise real past papers',
          onTap: () =>
              _openPastPapers('government', 'Government Exam Past Papers'),
        );
    }
  }

  Widget _buildSubjects() {
    if (_subjects == null && _subjectsError == null) {
      return Container(
        height: 100,
        decoration: _D.card(radius: 18),
        child: const Center(
          child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
        ),
      );
    }

    if (_subjects == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _D.card(radius: 18),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 30, color: QL.danger),
            const SizedBox(height: 8),
            Text(
              _subjectsError ?? 'Failed to load subjects',
              textAlign: TextAlign.center,
              style: const TextStyle(color: QL.muted, fontSize: 13),
            ),
            TextButton(
              onPressed: _reloadSubjects,
              style: TextButton.styleFrom(
                foregroundColor: QL.blue,
                minimumSize: const Size(64, 44),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return _SubjectsRow(
      subjects: _subjects!,
      onSubjectTap: () => _push(const SubjectsScreen()),
    );
  }
}

// ============================================================
// 6. WIDGETS
// ============================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.sessionExpired,
    required this.onRetry,
    required this.onLogin,
  });

  final String message;
  final bool sessionExpired;
  final VoidCallback onRetry;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: QL.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sessionExpired
                      ? Icons.lock_outline_rounded
                      : Icons.cloud_off_rounded,
                  size: 34,
                  color: QL.danger,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                sessionExpired ? 'Session expired' : 'Unable to load dashboard',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: QL.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: QL.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: QLPrimaryButton(
                  label: sessionExpired ? 'Log in' : 'Retry',
                  onTap: sessionExpired ? onLogin : onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.user,
    required this.greeting,
    required this.xp,
    required this.streakDays,
    required this.notificationsCount,
    required this.onAvatarTap,
    required this.onBellTap,
  });

  final User user;
  final String greeting;
  final int? xp;
  final int? streakDays;
  final int? notificationsCount;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    final hPad = _D.hPad(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Stack(
        children: [
          const Positioned.fill(child: QLBackdrop()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _D.maxWidth(context)),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: QLBrandMark(size: 38, fontSize: 17),
                            ),
                          ),
                          _NotificationBell(
                            count: notificationsCount,
                            onTap: onBellTap,
                          ),
                          const SizedBox(width: 10),
                          _AvatarButton(user: user, onTap: onAvatarTap),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        greeting,
                        style: const TextStyle(
                          color: QL.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.subtitleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: QL.ice, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStatChip(
                              icon: Icons.auto_awesome_rounded,
                              value: xp != null ? '$xp' : '—',
                              label: 'Total XP',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeroStatChip(
                              icon: Icons.local_fire_department_rounded,
                              value: streakDays != null ? '$streakDays' : '—',
                              label: 'Day streak',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBadge = count != null && count! > 0;

    return Semantics(
      button: true,
      label: hasBadge ? 'Notifications, $count new' : 'Notifications',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: QL.navyDeep,
            shape: BoxShape.circle,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 22,
              ),
              if (hasBadge)
                Positioned(
                  top: 3,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: QL.gold,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: QL.navy, width: 1.5),
                    ),
                    child: Text(
                      count! > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QL.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
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
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Open profile',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: QL.gold,
          ),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: QL.navyLight,
            backgroundImage: hasImage ? NetworkImage(user.avatarUrl!) : null,
            child: hasImage
                ? null
                : Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: QL.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: QL.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: QL.ice, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.data, required this.onResume});

  final ContinueLearning data;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final color = data.subject.flutterColor;
    final progress = (data.lastPercentage / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _D.card(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue learning',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: QL.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subject.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: QL.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.minutesLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _D.tint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: QL.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.minutesLeft} min left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: QL.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (data.recommendedQuizCount != null) ...[
            const SizedBox(height: 10),
            Text(
              'AI recommends ${data.recommendedQuizCount} quizzes based on '
              'your weak areas.',
              style: const TextStyle(
                fontSize: 12.5,
                color: QL.muted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Last score',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: QL.muted,
                ),
              ),
              Text(
                '${data.lastPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: QL.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _D.tint,
              valueColor: const AlwaysStoppedAnimation(QL.blue),
            ),
          ),
          const SizedBox(height: 16),
          QLPrimaryButton(label: 'Resume', onTap: onResume),
        ],
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: _D.card(radius: 26),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.menu_book_rounded,
              value: '${stats.selectedSubjects}',
              label: 'Subjects',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.quiz_rounded,
              value: '${stats.completedQuizzes}',
              label: 'Quizzes',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.trending_up_rounded,
              value: '${stats.averageScore.toStringAsFixed(0)}%',
              label: 'Avg score',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _D.tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: QL.blue, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: QL.ink,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: QL.muted)),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _D.card(radius: 20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: QL.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: QL.gold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: QL.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: QL.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: QL.blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectsRow extends StatelessWidget {
  const _SubjectsRow({required this.subjects, required this.onSubjectTap});

  final List<Subject> subjects;
  final VoidCallback onSubjectTap;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _D.card(radius: 18),
        child: const Column(
          children: [
            Icon(Icons.school_outlined, size: 38, color: QL.muted),
            SizedBox(height: 10),
            Text(
              'No subjects available',
              style: TextStyle(
                color: QL.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please check back later',
              style: TextStyle(color: QL.muted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    final displayed = subjects.take(4).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 per row on narrow screens, otherwise all in one row.
        final perRow = constraints.maxWidth < 340 ? 2 : displayed.length;
        final tileWidth = (constraints.maxWidth - 10 * (perRow - 1)) / perRow;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in displayed)
              SizedBox(
                width: tileWidth,
                child: _SubjectTile(subject: s, onTap: onSubjectTap),
              ),
          ],
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, required this.onTap});

  final Subject subject;
  final VoidCallback onTap;

  IconData _icon() {
    final n = subject.name.toLowerCase();
    if (n.contains('math')) return Icons.calculate_outlined;
    if (n.contains('science')) return Icons.science_outlined;
    if (n.contains('english')) return Icons.menu_book_outlined;
    if (n.contains('sinhala') ||
        n.contains('tamil') ||
        n.contains('language')) {
      return Icons.translate_rounded;
    }
    if (n.contains('ict') || n.contains('comput'))
      return Icons.computer_outlined;
    if (n.contains('history')) return Icons.account_balance_outlined;
    if (n.contains('commerce')) return Icons.bar_chart_rounded;
    if (n.contains('bio')) return Icons.eco_outlined;
    if (n.contains('physic')) return Icons.bolt_outlined;
    if (n.contains('chem')) return Icons.science_rounded;
    if (n.contains('geo')) return Icons.public_outlined;
    if (n.contains('art')) return Icons.palette_outlined;
    if (n.contains('qa') || n.contains('aptitude'))
      return Icons.psychology_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final color = subject.flutterColor;

    return Semantics(
      button: true,
      label: subject.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: _D.card(radius: 18),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon(), color: color, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                subject.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: QL.ink,
                ),
              ),
              if (subject.questionsCount != null)
                Text(
                  '${subject.questionsCount} Qs',
                  style: const TextStyle(fontSize: 11, color: QL.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real-time battles are a planned feature (not in the backend yet), so this
/// card is honest about it instead of showing a fake "Matching…" opponent.
class _BattleComingSoonCard extends StatelessWidget {
  const _BattleComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [QL.navy, QL.navyDeep],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: QL.gold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: QL.navy, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live quiz battles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Challenge classmates in real time and earn XP.',
                  style: TextStyle(color: QL.ice, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: QL.gold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Soon',
              style: TextStyle(
                color: QL.navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.user,
    required this.stats,
    required this.recentQuizzes,
    required this.onViewAll,
  });

  final User user;
  final Stats stats;
  final List<RecentQuiz> recentQuizzes;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final rows = recentQuizzes.take(5).toList();
    final hasImage = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return Container(
      decoration: _D.card(radius: 22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _D.tint,
                backgroundImage: hasImage
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: hasImage
                    ? null
                    : Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: QL.blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: QL.ink,
                      ),
                    ),
                    Text(
                      user.subtitleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: QL.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: QL.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stats.xpPoints ?? 0} XP',
                  style: const TextStyle(
                    color: QL.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE3E9F5)),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No quiz history yet. Take your first quiz to see it here.',
                style: TextStyle(color: QL.muted, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _RecentQuizRow(rank: i + 1, quiz: rows[i]),
          Align(
            alignment: Alignment.centerRight,
            child: _ViewAllButton(onTap: onViewAll),
          ),
        ],
      ),
    );
  }
}

class _RecentQuizRow extends StatelessWidget {
  const _RecentQuizRow({required this.rank, required this.quiz});

  final int rank;
  final RecentQuiz quiz;

  @override
  Widget build(BuildContext context) {
    final color = quiz.subject.flutterColor;
    final pct = quiz.percentage;
    final good = pct >= 50;
    final badge = good ? _D.success : QL.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: QL.muted,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 3,
                    backgroundColor: _D.tint,
                    valueColor: AlwaysStoppedAnimation(badge),
                  ),
                ),
                Text(
                  quiz.subject.name.isNotEmpty
                      ? quiz.subject.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: QL.ink,
                  ),
                ),
                Text(
                  quiz.quizType,
                  style: const TextStyle(fontSize: 11.5, color: QL.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badge.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                color: badge,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: QL.ink,
      letterSpacing: -0.2,
    ),
  );
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: QL.blue,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: const Text(
        'View all',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
