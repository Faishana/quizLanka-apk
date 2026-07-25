// dashboard_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/ProfileScreen.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/quiz_history_screen.dart';
import 'package:quiz_lanka/subjects_screen.dart';

// ============================================================
// 2. MODELS — UNCHANGED (do not modify)
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

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    school: json['school'] as String,
    district: json['district'] as String,
    grade: Grade.fromJson(json['grade'] as Map<String, dynamic>),
    avatarUrl: json['avatar_url'] as String?,
  );
}

class Stats {
  final int selectedSubjects;
  final int completedQuizzes;
  final double averageScore;
  final int? xpPoints;

  Stats({
    required this.selectedSubjects,
    required this.completedQuizzes,
    required this.averageScore,
    this.xpPoints,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    selectedSubjects: json['selected_subjects'] as int,
    completedQuizzes: json['completed_quizzes'] as int,
    averageScore: (json['average_score'] as num).toDouble(),
    xpPoints: json['xp_points'] as int?,
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

  ContinueLearning({
    required this.quizId,
    required this.subject,
    required this.lastScore,
    required this.lastPercentage,
    required this.completedAt,
  });

  factory ContinueLearning.fromJson(Map<String, dynamic> json) =>
      ContinueLearning(
        quizId: json['quiz_id'] as int,
        subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
        lastScore: json['last_score'] as int,
        lastPercentage: (json['last_percentage'] as num).toDouble(),
        completedAt: json['completed_at'] as String,
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
    return DashboardModel(
      success: json['success'] as bool,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      stats: Stats.fromJson(json['stats'] as Map<String, dynamic>),
      continueLearning: json['continue_learning'] != null
          ? ContinueLearning.fromJson(
              json['continue_learning'] as Map<String, dynamic>,
            )
          : null,
      subjects: (json['subjects'] as List<dynamic>)
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentQuizzes: (json['recent_quizzes'] as List<dynamic>)
          .map((e) => RecentQuiz.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================
// 3. SERVICE — UNCHANGED (do not modify)
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

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 4. DESIGN TOKENS — "Moonlit Aurora"
// ------------------------------------------------------------
// Self-contained palette for this screen only (does not touch or
// replace AppTheme, so bottombar.dart / other screens are
// unaffected). Pulled from the night skyline background: deep
// indigo/violet sky, warm gold building light, cool cyan moon-glow.
// ============================================================

class _Palette {
  _Palette._();

  /// Background photo — the moonlit clocktower skyline.
  /// Add this asset in pubspec.yaml, e.g.:
  ///   flutter:
  ///     assets:
  ///       - assets/images/dashboard_bg.jpg
  static const String backgroundAsset = 'assets/appHeader.png';

  // Brand gradient (indigo → violet → gold), matching the skyline.
  static const Color indigo = Color(0xFF120B2E);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDeep = Color(0xFF4C2E8F);
  static const Color blue = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF5EEAD4);
  static const Color gold = Color(0xFFF4B740);
  static const Color goldDeep = Color(0xFFE08A2B);

  static const List<Color> ctaGradient = [violet, blue];
  static const List<Color> goldGradient = [gold, goldDeep];

  // Text (light, for use over the dark photographic background)
  static const Color textPrimary = Color(0xFFF6F4FF);
  static const Color textSecondary = Color(0xFFC9C3E8);
  static const Color textMuted = Color(0xFF9B93C4);

  // Status accents
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color amber = gold;

  /// True frosted-glass card: blurs whatever sits behind it (the
  /// skyline photo) and tints it, so the background stays visible
  /// through every surface — the core of the "wow" look.
  static Widget glassCard({
    required Widget child,
    double radius = 24,
    double blur = 18,
    double borderOpacity = 0.16,
    Color tint = Colors.white,
    double tintOpacity = 0.08,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  static const List<Color> accentCycle = [violet, blue, gold, cyan];
}

// ============================================================
// 5. DASHBOARD SCREEN
// ------------------------------------------------------------
// FutureBuilder, state management, navigation calls and business
// logic are unchanged. The app already provides its own bottom
// navigation (see bottombar.dart / AppBottomNav) via
// MainNavigation, so this screen no longer renders its own —
// it only fills the content area above that bar.
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

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _service.getDashboard();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = _service.getDashboard();
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _Palette.indigo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fixed skyline backdrop — stays put while content
          // scrolls over it, so glass cards always show real sky.
          Image.asset(_Palette.backgroundAsset, fit: BoxFit.cover),
          // Legibility scrim: lighter near the top where the hero
          // text sits, deepening toward the bottom of the screen.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66120B2E),
                  Color(0xB3120B2E),
                  Color(0xF2120B2E),
                ],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),
          FutureBuilder<DashboardModel>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _Palette.gold,
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
              return SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: _Palette.gold,
                  backgroundColor: _Palette.indigo,
                  child: _FadeInOnLoad(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        _HeroHeader(
                          user: data.user,
                          greeting: _greeting(),
                          xp: data.stats.xpPoints,
                          recentCount: data.recentQuizzes.length,
                          onAvatarTap: () => _navigateToProfile(data.user),
                        ),
                        const SizedBox(height: 22),
                        if (data.continueLearning != null)
                          _ContinueLearningCard(
                            data: data.continueLearning!,
                            onResume: _navigateToSubjects,
                          )
                        else
                          _StatsSummaryCard(stats: data.stats),
                        const SizedBox(height: 26),
                        const _SectionTitle('Quick Access'),
                        const SizedBox(height: 12),
                        _QuickAccessGrid(
                          stats: data.stats,
                          onSubjects: _navigateToSubjects,
                          onHistory: _navigateToHistory,
                          onProfile: () => _navigateToProfile(data.user),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _SectionTitle('Subjects'),
                            _ViewAllButton(onTap: _navigateToSubjects),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SubjectsGrid(
                          subjects: data.subjects,
                          onSubjectTap: _navigateToSubjects,
                        ),
                        const SizedBox(height: 18),
                        _AiQuizGeneratorCard(onTap: _navigateToSubjects),
                        const SizedBox(height: 26),
                        _LiveQuizBattleCard(
                          userName: data.user.name,
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
                            color: _Palette.textMuted,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 6. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 6.0 Simple entrance animation — fade + rise, no controller
// lifecycle to manage since it's a one-shot TweenAnimationBuilder.
// ------------------------------------------------------------
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

// ------------------------------------------------------------
// 6.1 Error View
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: _Palette.glassCard(
          radius: 26,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _Palette.danger.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: _Palette.danger,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load dashboard',
                style: TextStyle(
                  fontSize: 17,
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
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _Palette.goldGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _Palette.gold.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: _Palette.indigo,
                      fontWeight: FontWeight.w800,
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

// ------------------------------------------------------------
// 6.2 Hero Header — sits directly on the skyline, no solid block,
// so the moonlit clocktower reads clearly behind the greeting.
// ------------------------------------------------------------
class _HeroHeader extends StatelessWidget {
  final User user;
  final String greeting;
  final int? xp;
  final int recentCount;
  final VoidCallback onAvatarTap;

  const _HeroHeader({
    required this.user,
    required this.greeting,
    required this.xp,
    required this.recentCount,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: _Palette.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: _Palette.textPrimary,
                      letterSpacing: -0.6,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Keep learning, keep winning ✨',
                    style: TextStyle(
                      color: _Palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_Palette.gold, _Palette.violet],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.gold.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: _Palette.indigo,
                  backgroundImage:
                      (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
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
                iconColor: const Color(0xFFFF8A5C),
                value: '$recentCount',
                label: 'Recent Quizzes',
              ),
            ),
          ],
        ),
      ],
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
    return _Palette.glassCard(
      radius: 16,
      blur: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _Palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _Palette.textSecondary,
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

// ------------------------------------------------------------
// 6.3 Continue Learning Card
// ------------------------------------------------------------
class _ContinueLearningCard extends StatelessWidget {
  final ContinueLearning data;
  final VoidCallback onResume;

  const _ContinueLearningCard({required this.data, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final color = data.subject.flutterColor;
    final progress = (data.lastPercentage / 100).clamp(0.0, 1.0);

    return _Palette.glassCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: color.withValues(alpha: 0.4),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: _Palette.goldGradient,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _Palette.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Continue Learning',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _Palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subject.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _Palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.lastPercentage.toStringAsFixed(0)}% complete · last score ${data.lastScore}',
            style: const TextStyle(
              fontSize: 11.5,
              color: _Palette.textSecondary,
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
                    color: _Palette.violet.withValues(alpha: 0.4),
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

// ------------------------------------------------------------
// 6.3b Fallback summary card when there's nothing to continue yet
// ------------------------------------------------------------
class _StatsSummaryCard extends StatelessWidget {
  final Stats stats;

  const _StatsSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Palette.glassCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
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
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
// 6.4 Quick Access grid
// ------------------------------------------------------------
class _QuickAccessGrid extends StatelessWidget {
  final Stats stats;
  final VoidCallback onSubjects;
  final VoidCallback onHistory;
  final VoidCallback onProfile;

  const _QuickAccessGrid({
    required this.stats,
    required this.onSubjects,
    required this.onHistory,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: Icons.category_rounded,
        label: 'Subjects',
        sub: '${stats.selectedSubjects} selected',
        color: _Palette.violet,
        onTap: onSubjects,
      ),
      (
        icon: Icons.history_rounded,
        label: 'History',
        sub: '${stats.completedQuizzes} quizzes',
        color: _Palette.blue,
        onTap: onHistory,
      ),
      (
        icon: Icons.emoji_events_rounded,
        label: 'Avg Score',
        sub: '${stats.averageScore.toStringAsFixed(0)}%',
        color: _Palette.gold,
        onTap: onHistory,
      ),
      (
        icon: Icons.person_rounded,
        label: 'Profile',
        sub: 'View & edit',
        color: _Palette.cyan,
        onTap: onProfile,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: item.onTap,
          child: _Palette.glassCard(
            radius: 18,
            blur: 14,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(item.icon, color: item.color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _Palette.textPrimary,
                        ),
                      ),
                      Text(
                        item.sub,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _Palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 6.5 Subjects grid
// ------------------------------------------------------------
class _SubjectsGrid extends StatelessWidget {
  final List<Subject> subjects;
  final VoidCallback onSubjectTap;

  const _SubjectsGrid({required this.subjects, required this.onSubjectTap});

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return _Palette.glassCard(
        radius: 18,
        padding: const EdgeInsets.all(20),
        child: const Text(
          'No subjects yet',
          style: TextStyle(color: _Palette.textSecondary, fontSize: 13),
        ),
      );
    }

    final displayed = subjects.take(8).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayed.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final subject = displayed[index];
        final color = subject.flutterColor;
        return GestureDetector(
          onTap: onSubjectTap,
          child: _Palette.glassCard(
            radius: 18,
            blur: 12,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.school_rounded, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _Palette.textPrimary,
                  ),
                ),
                if (subject.questionsCount != null)
                  Text(
                    '${subject.questionsCount} Qs',
                    style: const TextStyle(
                      fontSize: 9,
                      color: _Palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 6.6 AI Quiz Generator card
// ------------------------------------------------------------
class _AiQuizGeneratorCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AiQuizGeneratorCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Palette.glassCard(
        radius: 22,
        padding: const EdgeInsets.all(18),
        tint: _Palette.violet,
        tintOpacity: 0.16,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _Palette.goldGradient),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _Palette.gold.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _Palette.indigo,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Quiz Generator',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _Palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Practice your weak subjects with fresh questions',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _Palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _Palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.7 Live Quiz Battle card
// ------------------------------------------------------------
// NOTE: There is no live-presence / opponent-matching endpoint in
// DashboardModel. This card is a visual entry point only — it uses
// the current user's own real XP and routes into subject selection
// (the closest existing flow) rather than inventing a battle result.
// Swap onStartBattle for a real matchmaking call once that API exists.
class _LiveQuizBattleCard extends StatelessWidget {
  final String userName;
  final int userXp;
  final VoidCallback onStartBattle;

  const _LiveQuizBattleCard({
    required this.userName,
    required this.userXp,
    required this.onStartBattle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_Palette.violetDeep, _Palette.violet, _Palette.blue],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: _Palette.violet.withValues(alpha: 0.4),
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
                  child: const Icon(Icons.bolt_rounded, color: _Palette.gold),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Live Quiz Battle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Challenge students in real time and earn XP',
              style: TextStyle(color: _Palette.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _Palette.gold.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$userXp XP',
                          style: const TextStyle(
                            color: _Palette.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    color: _Palette.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Find opponent',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _Palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onStartBattle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _Palette.goldGradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.gold.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start Battle',
                      style: TextStyle(
                        color: _Palette.indigo,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.bolt_rounded, color: _Palette.indigo, size: 18),
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
// 6.8 Personal "leaderboard" card — real recent-quiz data only
// ------------------------------------------------------------
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

    return _Palette.glassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _Palette.violet.withValues(alpha: 0.28),
                backgroundImage:
                    (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
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
                  color: _Palette.gold.withValues(alpha: 0.2),
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
          Divider(height: 22, color: Colors.white.withValues(alpha: 0.12)),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No quiz history yet',
                style: TextStyle(color: _Palette.textSecondary, fontSize: 13),
              ),
            )
          else
            ...rows.map((quiz) => _RecentQuizRow(quiz: quiz)),
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
  final RecentQuiz quiz;

  const _RecentQuizRow({required this.quiz});

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
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
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
              color: badgeColor.withValues(alpha: 0.18),
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

// ------------------------------------------------------------
// 6.9 Small shared bits
// ------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
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
          color: _Palette.gold,
        ),
      ),
    );
  }
}
