// dashboard_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/ProfileScreen.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/quiz_history_screen.dart';
import 'package:quiz_lanka/subjects_screen.dart';
import 'package:quiz_lanka/past_paper_subject_selection_screen.dart';

// ============================================================
// 2. MODELS  (unchanged — same fields, same parsing, same features)
// ============================================================

class Grade {
  final int id;
  final String name;

  Grade({required this.id, required this.name});

  factory Grade.fromJson(Map<String, dynamic> json) =>
      Grade(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class User {
  final int id;
  final String name;
  final String email;
  final String school;
  final String district;
  final Grade grade;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.school,
    required this.district,
    required this.grade,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    debugPrint("========== USER FROM JSON ==========");
    debugPrint("avatar_url: ${json['avatar_url']}");
    debugPrint("profile_image: ${json['profile_image']}");
    debugPrint("display_avatar: ${json['display_avatar']}");
    debugPrint("avatar: ${json['avatar']}");
    debugPrint("profile_photo: ${json['profile_photo']}");
    debugPrint("====================================");

    String? avatarUrl;

    if (json['display_avatar'] != null &&
        json['display_avatar'].toString().isNotEmpty) {
      avatarUrl = json['display_avatar'].toString();
    } else if (json['profile_image'] != null &&
        json['profile_image'].toString().isNotEmpty) {
      avatarUrl = json['profile_image'].toString();
    } else if (json['avatar_url'] != null &&
        json['avatar_url'].toString().isNotEmpty) {
      avatarUrl = json['avatar_url'].toString();
    } else if (json['avatar'] != null && json['avatar'].toString().isNotEmpty) {
      avatarUrl = json['avatar'].toString();
    } else if (json['profile_photo'] != null &&
        json['profile_photo'].toString().isNotEmpty) {
      avatarUrl = json['profile_photo'].toString();
    }

    debugPrint("Selected Avatar URL: $avatarUrl");
    debugPrint("====================================");

    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      school: json['school'] as String,
      district: json['district'] as String,
      grade: Grade.fromJson(json['grade'] as Map<String, dynamic>),
      avatarUrl: avatarUrl,
    );
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
    selectedSubjects: json['selected_subjects'] as int,
    completedQuizzes: json['completed_quizzes'] as int,
    averageScore: (json['average_score'] as num).toDouble(),
    xpPoints: json['xp_points'] as int?,
    streakDays: json['streak_days'] as int?,
    notificationsCount: json['notifications_count'] as int?,
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
    id: json['id'] as int,
    name: json['name'] as String,
    icon: json['icon'] as String?,
    color: json['color'] as String,
    questionsCount: json['questions_count'] as int?,
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
        quizId: json['quiz_id'] as int,
        subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
        lastScore: json['last_score'] as int,
        lastPercentage: (json['last_percentage'] as num).toDouble(),
        completedAt: json['completed_at'] as String,
        recommendedQuizCount: json['recommended_quiz_count'] as int?,
        minutesLeft: json['minutes_left'] as int?,
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
    id: json['id'] as int,
    subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
    quizType: json['quiz_type'] as String,
    score: json['score'] as int,
    percentage: (json['percentage'] as num).toDouble(),
    completedAt: json['completed_at'] as String,
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
    debugPrint("========== DASHBOARD RESPONSE ==========");
    debugPrint("Full Response: ${jsonEncode(json)}");
    debugPrint("========================================");

    // Debug subjects specifically
    debugPrint("========== SUBJECTS FROM API ==========");
    if (json['subjects'] != null) {
      debugPrint("Subjects type: ${json['subjects'].runtimeType}");
      debugPrint("Subjects length: ${(json['subjects'] as List).length}");
      for (var subject in json['subjects']) {
        debugPrint("Subject data: $subject");
      }
    } else {
      debugPrint("No subjects key found in response");
      debugPrint("Available keys: ${json.keys}");
    }
    debugPrint("========================================");

    return DashboardModel(
      success: json['success'] as bool,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
      continueLearning: json['continue_learning'] != null
          ? ContinueLearning.fromJson(
              json['continue_learning'] as Map<String, dynamic>,
            )
          : null,
      subjects: json['subjects'] != null
          ? (json['subjects'] as List<dynamic>)
                .map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      recentQuizzes: (json['recent_quizzes'] as List<dynamic>)
          .map((e) => RecentQuiz.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================
// 3. SERVICE  (unchanged — same endpoints, same error handling)
// ============================================================

class DashboardService {
  final http.Client _client = http.Client();

  Future<DashboardModel> getDashboard() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.dashboard}'),
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
      return DashboardModel.fromJson(data);
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode >= 500) {
      throw Exception('Server error. Please try again later.');
    }

    throw Exception(data['message'] ?? 'Failed to load dashboard.');
  }

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

    debugPrint('Subjects API Status: ${response.statusCode}');
    debugPrint('Subjects API Response: ${response.body}');

    if (response.statusCode == 200 && data['success'] == true) {
      final subjectsList = data['subjects'];
      if (subjectsList == null || subjectsList is! List) {
        throw Exception('Invalid subjects data received from server.');
      }
      return subjectsList
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }

    throw Exception(data['message'] ?? 'Failed to load subjects.');
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 4. DESIGN TOKENS
// ============================================================

class _Palette {
  _Palette._();

  static const String backgroundAsset = 'assets/appHeader.png';

  static const Color violet = Color(0xFF7C3AED);
  static const Color violetDeep = Color(0xFF4C2E8F);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color gold = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFF97316);
  static const Color teal = Color(0xFF14B8A6);

  static const List<Color> ctaGradient = [violet, blue];
  static const List<Color> battleGradient = [violetDeep, violet, blue];

  static const Color scaffold = Color(0xFFEAF1FB);
  static const Color cardWhite = Color(0xFFF6FAFF);
  static const Color border = Color(0xFFDCE7F7);

  static const Color textPrimary = Color(0xFF181B34);
  static const Color textSecondary = Color(0xFF6B7086);

  static const Color textOnPhoto = Colors.white;
  static const Color textOnPhotoMuted = Color(0xFFE3E1FA);

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);

  static BoxDecoration card({double radius = 22, Color? tint}) {
    return BoxDecoration(
      color: tint ?? cardWhite,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16232B6B),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    );
  }
}

// ============================================================
// 4b. RESPONSIVE HELPERS
// ------------------------------------------------------------
// Centralizes every breakpoint decision so the rest of the file
// stays declarative. Nothing here changes *what* is shown —
// only how much space, padding, and text scale it gets on
// phones vs. tablets vs. wider/foldable screens.
// ============================================================

enum _DeviceType { compactPhone, phone, tablet, desktop }

class _Responsive {
  _Responsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static _DeviceType deviceType(BuildContext context) {
    final w = width(context);
    if (w >= 1024) return _DeviceType.desktop;
    if (w >= 600) return _DeviceType.tablet;
    if (w < 340) return _DeviceType.compactPhone;
    return _DeviceType.phone;
  }

  static bool isTabletUp(BuildContext context) => width(context) >= 600;
  static bool isCompact(BuildContext context) => width(context) < 340;

  /// Horizontal page padding — grows with the viewport so content
  /// never feels cramped on a tablet or stretched edge-to-edge.
  static double horizontalPadding(BuildContext context) {
    switch (deviceType(context)) {
      case _DeviceType.desktop:
        return 56;
      case _DeviceType.tablet:
        return 36;
      case _DeviceType.phone:
      case _DeviceType.compactPhone:
        return 20;
    }
  }

  /// Caps how wide the main content column can grow on large
  /// screens, then the caller centers it — this is what keeps
  /// cards from looking absurdly wide on a tablet/desktop.
  static double maxContentWidth(BuildContext context) {
    switch (deviceType(context)) {
      case _DeviceType.desktop:
        return 900;
      case _DeviceType.tablet:
        return 680;
      case _DeviceType.phone:
      case _DeviceType.compactPhone:
        return double.infinity;
    }
  }

  static double heroHeight(BuildContext context) {
    switch (deviceType(context)) {
      case _DeviceType.desktop:
        return 340;
      case _DeviceType.tablet:
        return 310;
      case _DeviceType.phone:
      case _DeviceType.compactPhone:
        return 275;
    }
  }

  /// Gentle font-size scaling — never more than ~15% either way,
  /// so type never looks jarring, just comfortably sized per device.
  static double scale(BuildContext context, double base) {
    switch (deviceType(context)) {
      case _DeviceType.desktop:
        return base * 1.15;
      case _DeviceType.tablet:
        return base * 1.08;
      case _DeviceType.phone:
        return base;
      case _DeviceType.compactPhone:
        return base * 0.94;
    }
  }

  static double avatarRadius(BuildContext context, double base) {
    switch (deviceType(context)) {
      case _DeviceType.desktop:
      case _DeviceType.tablet:
        return base * 1.15;
      case _DeviceType.phone:
      case _DeviceType.compactPhone:
        return base;
    }
  }
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
  late Future<DashboardModel> _dashboardFuture;
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _service.getDashboard();
    _subjectsFuture = _service.getSubjects();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = _service.getDashboard();
      _subjectsFuture = _service.getSubjects();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigateToProfile(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(key: ValueKey(user.id))),
    ).then((_) => _refresh());
  }

  void _navigateToSubjects() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubjectsScreen()),
    ).then((_) => _refresh());
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizHistoryScreen()),
    ).then((_) => _refresh());
  }

  void _navigateToPastPapers({
    required String category,
    required String title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PastPaperSubjectSelectionScreen(category: category, title: title),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _Palette.scaffold,
      body: FutureBuilder<DashboardModel>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _Palette.violet,
                strokeWidth: 2.5,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!;

          debugPrint("========== FINAL AVATAR URL ==========");
          debugPrint("Avatar URL: ${data.user.avatarUrl}");
          debugPrint("======================================");

          final hPad = _Responsive.horizontalPadding(context);
          final maxWidth = _Responsive.maxContentWidth(context);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: _Palette.violet,
            child: _FadeInOnLoad(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
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
                    onAvatarTap: () => _navigateToProfile(data.user),
                    onBellTap: _navigateToHistory,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.continueLearning != null)
                                _ContinueLearningCard(
                                  data: data.continueLearning!,
                                  onResume: _navigateToSubjects,
                                )
                              else
                                _StatsSummaryCard(stats: data.stats),
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const _SectionTitle('Quick Access'),
                                  //_ViewAllButton(onTap: _navigateToSubjects),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _QuickAccessRow(
                                stats: data.stats,
                                onSubjects: _navigateToSubjects,
                                onHistory: _navigateToHistory,
                                onProfile: () => _navigateToProfile(data.user),
                                onPastPapers: _navigateToPastPapers,
                              ),
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const _SectionTitle('Subjects'),
                                  _ViewAllButton(onTap: _navigateToSubjects),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Use FutureBuilder for subjects
                              FutureBuilder<List<Subject>>(
                                future: _subjectsFuture,
                                builder: (context, subjectSnapshot) {
                                  if (subjectSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      height: 100,
                                      decoration: _Palette.card(radius: 18),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: _Palette.violet,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    );
                                  }

                                  if (subjectSnapshot.hasError) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: _Palette.card(radius: 18),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            size: 32,
                                            color: _Palette.danger,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Failed to load subjects',
                                            style: TextStyle(
                                              color: _Palette.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _subjectsFuture = _service
                                                    .getSubjects();
                                              });
                                            },
                                            child: const Text(
                                              'Retry',
                                              style: TextStyle(
                                                color: _Palette.violet,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final subjects = subjectSnapshot.data ?? [];
                                  return _SubjectsRow(
                                    subjects: subjects,
                                    onSubjectTap: _navigateToSubjects,
                                  );
                                },
                              ),
                              const SizedBox(height: 26),
                              _LiveQuizBattleCard(
                                user: data.user,
                                userXp: data.stats.xpPoints ?? 0,
                                onStartBattle: _navigateToSubjects,
                              ),
                              const SizedBox(height: 26),
                              const _SectionTitle('Your Recent Activity'),
                              const SizedBox(height: 4),
                              const Text(
                                'A live cross-student leaderboard needs a '
                                'ranking endpoint that isn\'t in the API yet — '
                                'showing your own recent results instead.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _Palette.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _PersonalLeaderboardCard(
                                user: data.user,
                                stats: data.stats,
                                recentQuizzes: data.recentQuizzes,
                                onViewAll: _navigateToHistory,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// 6. WIDGETS
// ============================================================

class _FadeInOnLoad extends StatelessWidget {
  const _FadeInOnLoad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.scaffold,
      child: Center(
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
                  decoration: BoxDecoration(
                    color: _Palette.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: _Palette.danger,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unable to load dashboard',
                  style: TextStyle(
                    fontSize: _Responsive.scale(context, 18),
                    fontWeight: FontWeight.w800,
                    color: _Palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: _Palette.ctaGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _Palette.violet.withValues(alpha: 0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _HeroHeader extends StatelessWidget {
  final User user;
  final String greeting;
  final int? xp;
  final int? streakDays;
  final int? notificationsCount;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;

  const _HeroHeader({
    required this.user,
    required this.greeting,
    required this.xp,
    required this.streakDays,
    required this.notificationsCount,
    required this.onAvatarTap,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = _Responsive.horizontalPadding(context);
    final maxWidth = _Responsive.maxContentWidth(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: SizedBox(
        height: _Responsive.heroHeight(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _Palette.backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Palette.violetDeep, Color(0xFF14132F)],
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x552D1B69),
                    Color(0x77120B2E),
                    Color(0x77120B2E),
                    _Palette.scaffold,
                    _Palette.scaffold,
                  ],
                  stops: [0.0, 0.45, 0.84, 0.94, 1.0],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: _AppLogo()),
                            _NotificationBell(
                              count: notificationsCount,
                              onTap: onBellTap,
                            ),
                            const SizedBox(width: 12),
                            _AvatarButton(user: user, onTap: onAvatarTap),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          greeting,
                          style: TextStyle(
                            color: _Palette.textOnPhotoMuted,
                            fontSize: _Responsive.scale(context, 13),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  fontSize: _Responsive.scale(context, 26),
                                  fontWeight: FontWeight.w900,
                                  color: _Palette.textOnPhoto,
                                  letterSpacing: -0.5,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 12,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('👋', style: TextStyle(fontSize: 22)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Keep learning, keep winning!',
                          style: TextStyle(
                            color: _Palette.textOnPhotoMuted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 50, top: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _HeroStatChip(
                                  icon: Icons.auto_awesome_rounded,
                                  iconColor: _Palette.gold,
                                  value: xp != null ? '$xp' : '—',
                                  label: 'Total XP',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HeroStatChip(
                                  icon: Icons.local_fire_department_rounded,
                                  iconColor: const Color(0xFFFF7A45),
                                  value: streakDays != null
                                      ? '$streakDays'
                                      : '—',
                                  label: 'Day Streak',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _Palette.ctaGradient),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: _Palette.violet.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_alt_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: _Responsive.scale(context, 16.5),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            children: const [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(color: _Palette.cyan),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int? count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBadge = count != null && count! > 0;
    final size = _Responsive.avatarRadius(context, 40);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 19,
            ),
            if (hasBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 17),
                  decoration: BoxDecoration(
                    color: _Palette.danger,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _Palette.violetDeep, width: 1.5),
                  ),
                  child: Text(
                    count! > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _AvatarButton({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    debugPrint("========== AVATAR BUTTON ==========");
    debugPrint("Avatar URL: ${user.avatarUrl}");
    debugPrint("Avatar URL isEmpty: ${user.avatarUrl?.isEmpty ?? true}");
    debugPrint("User Name: ${user.name}");
    debugPrint("===================================");

    final radius = _Responsive.avatarRadius(context, 19);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_Palette.violet, _Palette.cyan],
          ),
          boxShadow: [
            BoxShadow(
              color: _Palette.violet.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF201E4A),
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _HeroStatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _Responsive.scale(context, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _Palette.textOnPhotoMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  final ContinueLearning data;
  final VoidCallback onResume;

  const _ContinueLearningCard({required this.data, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final color = data.subject.flutterColor;
    final progress = (data.lastPercentage / 100).clamp(0.0, 1.0);
    final isTabletUp = _Responsive.isTabletUp(context);

    return Container(
      padding: EdgeInsets.all(isTabletUp ? 22 : 18),
      decoration: _Palette.card(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.55)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _Palette.violet,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue Learning',
                      style: TextStyle(
                        fontSize: 12,
                        color: _Palette.violet,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subject.name,
                      style: TextStyle(
                        fontSize: _Responsive.scale(context, 17),
                        fontWeight: FontWeight.w800,
                        color: _Palette.textPrimary,
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
                    color: _Palette.scaffold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: _Palette.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.minutesLeft} min left',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _Palette.textSecondary,
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
                fontSize: 12,
                color: _Palette.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _Palette.violet,
                ),
              ),
              Text(
                '${data.lastPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _Palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(_Palette.blue),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onResume,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _Palette.ctaGradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _Palette.violet.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Resume',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  final Stats stats;

  const _StatsSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isTabletUp = _Responsive.isTabletUp(context);
    return Container(
      padding: EdgeInsets.all(isTabletUp ? 24 : 20),
      decoration: _Palette.card(radius: 26),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.menu_book_rounded,
              color: _Palette.violet,
              value: '${stats.selectedSubjects}',
              label: 'Subjects',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.quiz_rounded,
              color: _Palette.blue,
              value: '${stats.completedQuizzes}',
              label: 'Quizzes',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.trending_up_rounded,
              color: _Palette.success,
              value: '${stats.averageScore.toStringAsFixed(0)}%',
              label: 'Avg Score',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: _Responsive.scale(context, 16),
            fontWeight: FontWeight.w800,
            color: _Palette.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: _Palette.textSecondary),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Quick Access — now redirects to Past Papers screens.
// ------------------------------------------------------------
typedef _QuickAccessItem = ({
  IconData icon,
  String label,
  String sub,
  List<Color> colors,
  VoidCallback onTap,
});

class _QuickAccessRow extends StatelessWidget {
  final Stats stats;
  final VoidCallback onSubjects;
  final VoidCallback onHistory;
  final VoidCallback onProfile;
  final void Function({required String category, required String title})
  onPastPapers;

  const _QuickAccessRow({
    required this.stats,
    required this.onSubjects,
    required this.onHistory,
    required this.onProfile,
    required this.onPastPapers,
  });

  @override
  Widget build(BuildContext context) {
    final List<_QuickAccessItem> items = [
      (
        icon: Icons.grade_rounded,
        label: 'Grade 5',
        sub: 'Past Papers',
        colors: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
        onTap: () =>
            onPastPapers(category: 'primary', title: 'Grade 5 Past Papers'),
      ),
      (
        icon: Icons.quiz_rounded,
        label: 'O/L',
        sub: 'Past Papers',
        colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        onTap: () => onPastPapers(category: 'ol', title: 'O/L Past Papers'),
      ),
      (
        icon: Icons.school_rounded,
        label: 'A/L',
        sub: 'Past Papers',
        colors: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
        onTap: () => onPastPapers(category: 'al', title: 'A/L Past Papers'),
      ),
      (
        icon: Icons.assignment_rounded,
        label: 'GOV',
        sub: 'Past Papers',
        colors: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
        onTap: () => onPastPapers(
          category: 'government',
          title: 'Government Exam Past Papers',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;

        if (compact) {
          final tileWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => SizedBox(
                    width: tileWidth,
                    child: _QuickAccessTile(item: item),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: List.generate(items.length, (i) {
            final isLast = i == items.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 10),
                child: _QuickAccessTile(item: items[i]),
              ),
            );
          }),
        );
      },
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final _QuickAccessItem item;
  const _QuickAccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isTabletUp = _Responsive.isTabletUp(context);
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: EdgeInsets.all(isTabletUp ? 16 : 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: item.colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.colors.first.withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(item.icon, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: _Responsive.scale(context, 14),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Center(
              child: Text(
                item.sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
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
// Subjects row — same "first 4 subjects" behaviour as before,
// same empty-state, just laid out responsively (Row on normal
// widths, 2x2 wrap on very narrow phones).
// ------------------------------------------------------------
class _SubjectsRow extends StatelessWidget {
  final List<Subject> subjects;
  final VoidCallback onSubjectTap;

  const _SubjectsRow({required this.subjects, required this.onSubjectTap});

  @override
  Widget build(BuildContext context) {
    // Debug: Print subjects count and data
    debugPrint("========== SUBJECTS ROW ==========");
    debugPrint("Subjects count: ${subjects.length}");
    for (var subject in subjects) {
      debugPrint(
        "Subject: ${subject.name}, ID: ${subject.id}, Color: ${subject.color}",
      );
    }
    debugPrint("====================================");

    // Check if subjects list is empty
    if (subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _Palette.card(radius: 18),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 40,
              color: _Palette.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'No Subjects Available',
              style: TextStyle(
                color: _Palette.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please check back later',
              style: TextStyle(color: _Palette.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Take only first 4 subjects (unchanged)
    final displayed = subjects.take(4).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;

        if (compact) {
          final tileWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: displayed
                .map(
                  (s) => SizedBox(
                    width: tileWidth,
                    child: _SubjectTile(subject: s, onTap: onSubjectTap),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: List.generate(displayed.length, (i) {
            final isLast = i == displayed.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 10),
                child: _SubjectTile(subject: displayed[i], onTap: onSubjectTap),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;

  const _SubjectTile({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = subject.flutterColor;
    final isTabletUp = _Responsive.isTabletUp(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTabletUp ? 20 : 16,
          horizontal: 8,
        ),
        decoration: _Palette.card(radius: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.school_rounded, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _Responsive.scale(context, 12),
                fontWeight: FontWeight.w700,
                color: _Palette.textPrimary,
              ),
            ),
            if (subject.questionsCount != null)
              Text(
                '${subject.questionsCount} Qs',
                style: const TextStyle(
                  fontSize: 10,
                  color: _Palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveQuizBattleCard extends StatelessWidget {
  final User user;
  final int userXp;
  final VoidCallback onStartBattle;

  const _LiveQuizBattleCard({
    required this.user,
    required this.userXp,
    required this.onStartBattle,
  });

  @override
  Widget build(BuildContext context) {
    final isTabletUp = _Responsive.isTabletUp(context);
    return Container(
      padding: EdgeInsets.all(isTabletUp ? 24 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _Palette.battleGradient,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _Palette.violet.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Live Quiz Battle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _Responsive.scale(context, 16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Challenge students in real time and earn XP',
            style: TextStyle(color: _Palette.textOnPhotoMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _BattleAvatar(
                      initial: user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      avatarUrl: user.avatarUrl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$userXp XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const _BattleAvatar(initial: '?', avatarUrl: null),
                    const SizedBox(height: 8),
                    const Text(
                      'Find opponent',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _Palette.textOnPhotoMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Matching…',
                        style: TextStyle(
                          color: _Palette.textOnPhotoMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onStartBattle,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start Battle',
                    style: TextStyle(
                      color: _Palette.violetDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.bolt_rounded,
                    color: _Palette.violetDeep,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleAvatar extends StatelessWidget {
  final String initial;
  final String? avatarUrl;

  const _BattleAvatar({required this.initial, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: CircleAvatar(
        radius: _Responsive.avatarRadius(context, 26),
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
            ? NetworkImage(avatarUrl!)
            : null,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}

class _PersonalLeaderboardCard extends StatelessWidget {
  final User user;
  final Stats stats;
  final List<RecentQuiz> recentQuizzes;
  final VoidCallback onViewAll;

  const _PersonalLeaderboardCard({
    required this.user,
    required this.stats,
    required this.recentQuizzes,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final rows = recentQuizzes.take(5).toList();
    final isTabletUp = _Responsive.isTabletUp(context);

    return Container(
      decoration: _Palette.card(radius: 22),
      padding: EdgeInsets.all(isTabletUp ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: _Responsive.avatarRadius(context, 18),
                backgroundColor: _Palette.violet.withValues(alpha: 0.12),
                backgroundImage:
                    (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _Palette.violet,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _Palette.textPrimary,
                      ),
                    ),
                    Text(
                      user.school,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _Palette.textSecondary,
                      ),
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
                  color: _Palette.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stats.xpPoints ?? 0} XP',
                  style: const TextStyle(
                    color: _Palette.gold,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: _Palette.border),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No quiz history yet',
                style: TextStyle(color: _Palette.textSecondary, fontSize: 13),
              ),
            )
          else
            ...List.generate(
              rows.length,
              (i) => _RecentQuizRow(rank: i + 1, quiz: rows[i]),
            ),
          const SizedBox(height: 6),
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
  final int rank;
  final RecentQuiz quiz;

  const _RecentQuizRow({required this.rank, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final color = quiz.subject.flutterColor;
    final percentage = quiz.percentage;
    final isGood = percentage >= 50;
    final badgeColor = isGood ? _Palette.success : _Palette.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _Palette.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    strokeWidth: 3,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(badgeColor),
                  ),
                ),
                Text(
                  quiz.subject.name.isNotEmpty
                      ? quiz.subject.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _Palette.textPrimary,
                  ),
                ),
                Text(
                  quiz.quizType,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _Palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: _Responsive.scale(context, 16),
        fontWeight: FontWeight.w800,
        color: _Palette.textPrimary,
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'View All',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _Palette.violet,
        ),
      ),
    );
  }
}
