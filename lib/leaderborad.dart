// leaderboard_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/config/api_config.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 1b. LIGHT THEME PALETTE (local to this screen)
// ------------------------------------------------------------
// This screen previously relied on AppTheme's dark palette
// (AppTheme.backgroundGradient, AppTheme.violet, AppTheme.cyan,
// AppTheme.textPrimary/Secondary, AppTheme.glassCard). Since
// appTheam.dart isn't part of this file, the light-theme colors
// and shadows are defined here so the screen is self-contained.
// If you want this to apply app-wide, mirror these values into
// AppTheme itself.
// ============================================================
class _LightTheme {
  // Background: soft white -> pale blue gradient
  static const List<Color> backgroundGradient = [
    Color(0xFFFAFBFF),
    Color(0xFFEAF0FF),
  ];

  // Accent colors (kept blue/violet family, tuned for light bg)
  static const Color primaryBlue = Color(0xFF3D5CFF);
  static const Color accentCyan = Color(0xFF2FB6C9);
  static const Color danger = Color(0xFFE05A5A);

  // Text
  static const Color textPrimary = Color(0xFF1B2440);
  static const Color textSecondary = Color(0xFF6B7A99);

  // Surfaces
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3F6FF);
  static const Color border = Color(0xFFDCE4FF);

  // The signature "blue shadow" used across cards
  static List<BoxShadow> blueShadow({
    double blur = 24,
    double spread = 0,
    Offset offset = const Offset(0, 10),
    double opacity = 0.18,
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

  static BoxDecoration card({double radius = 20}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: blueShadow(),
    );
  }
}

// ============================================================
// 2. MODELS — with debug prints
// ============================================================
class LeaderboardResponse {
  final bool success;
  final MyRank? myRank;
  final List<LeaderboardPlayer> topThree;
  final List<LeaderboardPlayer> national;
  final List<LeaderboardPlayer> school;
  final List<LeaderboardPlayer> district;
  final List<SubjectStat> subjects;

  LeaderboardResponse({
    required this.success,
    this.myRank,
    required this.topThree,
    required this.national,
    required this.school,
    required this.district,
    required this.subjects,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    debugPrint("========== LEADERBOARD RESPONSE ==========");
    debugPrint("Full Response: ${jsonEncode(json)}");
    debugPrint("==========================================");

    return LeaderboardResponse(
      success: json['success'] ?? false,
      myRank: json['my_rank'] != null && json['my_rank'].isNotEmpty
          ? MyRank.fromJson(json['my_rank'])
          : null,
      topThree:
          (json['top_three'] as List?)
              ?.map((e) => LeaderboardPlayer.fromJson(e))
              .toList() ??
          [],
      national:
          (json['national'] as List?)
              ?.map((e) => LeaderboardPlayer.fromJson(e))
              .toList() ??
          [],
      school:
          (json['school'] as List?)
              ?.map((e) => LeaderboardPlayer.fromJson(e))
              .toList() ??
          [],
      district:
          (json['district'] as List?)
              ?.map((e) => LeaderboardPlayer.fromJson(e))
              .toList() ??
          [],
      subjects:
          (json['subjects'] as List?)
              ?.map((e) => SubjectStat.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MyRank {
  final int rank;
  final int xp;
  final int level;
  final String school;
  final int completedQuizzes;
  final int currentStreak;

  MyRank({
    required this.rank,
    required this.xp,
    required this.level,
    required this.school,
    required this.completedQuizzes,
    required this.currentStreak,
  });

  factory MyRank.fromJson(Map<String, dynamic> json) {
    return MyRank(
      rank: json['rank'] ?? 0,
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 0,
      school: json['school'] ?? '',
      completedQuizzes: json['completed_quizzes'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
    );
  }
}

class LeaderboardPlayer {
  final int rank;
  final String id;
  final String name;
  final String avatar;
  final int xp;
  final int level;
  final String school;

  LeaderboardPlayer({
    required this.rank,
    required this.id,
    required this.name,
    required this.avatar,
    required this.xp,
    required this.level,
    required this.school,
  });

  factory LeaderboardPlayer.fromJson(Map<String, dynamic> json) {
    // Debug print for avatar
    debugPrint("Leaderboard Player Avatar: ${json['avatar']}");
    debugPrint("Leaderboard Player Name: ${json['name']}");

    return LeaderboardPlayer(
      rank: json['rank'] ?? 0,
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 0,
      school: json['school'] ?? '',
    );
  }
}

class SubjectStat {
  final String subject;
  final int score;

  SubjectStat({required this.subject, required this.score});

  factory SubjectStat.fromJson(Map<String, dynamic> json) {
    return SubjectStat(
      subject: json['subject'] ?? '',
      score: json['score'] ?? 0,
    );
  }
}

// ============================================================
// 3. API SERVICE
// ============================================================
class LeaderboardService {
  Future<LeaderboardResponse> fetchLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      debugPrint("========== FETCHING LEADERBOARD ==========");
      debugPrint("URL: ${ApiConfig.baseUrl}${ApiConfig.leaderboard}");
      debugPrint("Token: ${token != null ? 'Present' : 'Missing'}");

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboard}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint("Response Status: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("==========================================");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LeaderboardResponse.fromJson(data);
      } else {
        throw Exception('Failed to load leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching leaderboard: $e");
      throw Exception('Error fetching leaderboard: $e');
    }
  }
}

// ============================================================
// 4. CUSTOM AVATAR WIDGET — Reusable with error handling
// ============================================================
class _AvatarWidget extends StatelessWidget {
  final String avatarUrl;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const _AvatarWidget({
    required this.avatarUrl,
    this.size = 40,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidAvatar = avatarUrl.trim().isNotEmpty;

    debugPrint("AvatarWidget - URL: '$avatarUrl'");
    debugPrint("AvatarWidget - Has Valid Avatar: $hasValidAvatar");

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _LightTheme.primaryBlue.withValues(alpha: 0.10),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : Border.all(color: _LightTheme.border, width: 1),
        boxShadow: _LightTheme.blueShadow(
          blur: 12,
          offset: const Offset(0, 4),
          opacity: 0.12,
        ),
      ),
      child: hasValidAvatar
          ? ClipOval(
              child: Image.network(
                avatarUrl.trim(),
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint("Error loading avatar: $error");
                  return Icon(
                    Icons.person,
                    color: _LightTheme.primaryBlue,
                    size: size * 0.5,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.4,
                      height: size * 0.4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _LightTheme.primaryBlue,
                      ),
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.person,
              color: _LightTheme.primaryBlue,
              size: size * 0.5,
            ),
    );
  }
}

// ============================================================
// 5. LEADERBOARD SCREEN
// ============================================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final LeaderboardService _service = LeaderboardService();
  LeaderboardResponse? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _service.fetchLeaderboard();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -60,
              child: _GlowBlob(color: _LightTheme.primaryBlue, size: 240),
            ),
            Positioned(
              top: 140,
              left: -70,
              child: _GlowBlob(color: _LightTheme.accentCyan, size: 200),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(
                    onBack: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    onRefresh: _fetchLeaderboard,
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _LightTheme.primaryBlue,
                            ),
                          )
                        : _error != null
                        ? _ErrorWidget(
                            error: _error,
                            onRetry: _fetchLeaderboard,
                          )
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) return const SizedBox();

    debugPrint("========== BUILDING CONTENT ==========");
    debugPrint("Top Three Count: ${_data!.topThree.length}");
    debugPrint("National Count: ${_data!.national.length}");
    debugPrint("School Count: ${_data!.school.length}");
    debugPrint("District Count: ${_data!.district.length}");
    debugPrint("======================================");

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_data!.myRank != null) _MyRankHero(rank: _data!.myRank!),
        const SizedBox(height: 18),
        if (_data!.topThree.isNotEmpty) _Podium(players: _data!.topThree),
        const SizedBox(height: 18),
        _CategoryTabs(tabController: _tabController),
        const SizedBox(height: 16),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: TabBarView(
            controller: _tabController,
            children: [
              _LeaderboardList(players: _data!.national),
              _LeaderboardList(players: _data!.school),
              _LeaderboardList(players: _data!.district),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 6. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 6.0 Ambient glow blob (softened for light bg)
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
          color: color.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.1 Header
// ------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CircleIconButton(
            icon: canPop
                ? Icons.arrow_back_ios_new_rounded
                : Icons.home_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 14),
          const Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _LightTheme.textPrimary,
            ),
          ),
          const Spacer(),
          _CircleIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _LightTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _LightTheme.border),
          boxShadow: _LightTheme.blueShadow(
            blur: 10,
            offset: const Offset(0, 3),
            opacity: 0.12,
          ),
        ),
        child: Icon(icon, color: _LightTheme.primaryBlue, size: 18),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.1b Error Widget
// ------------------------------------------------------------
class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _LightTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 36,
                color: _LightTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load leaderboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _LightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _LightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_LightTheme.primaryBlue, _LightTheme.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _LightTheme.blueShadow(
                    blur: 16,
                    offset: const Offset(0, 6),
                    opacity: 0.30,
                  ),
                ),
                child: const Text(
                  'Try Again',
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
    );
  }
}

// ------------------------------------------------------------
// 6.2 My Rank
// ------------------------------------------------------------
class _MyRankHero extends StatelessWidget {
  final MyRank rank;

  const _MyRankHero({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LightTheme.primaryBlue.withValues(alpha: 0.10),
            _LightTheme.accentCyan.withValues(alpha: 0.06),
          ],
        ),
        color: _LightTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _LightTheme.border),
        boxShadow: _LightTheme.blueShadow(
          blur: 28,
          offset: const Offset(0, 12),
          opacity: 0.16,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _LightTheme.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'My Rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _LightTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_LightTheme.primaryBlue, _LightTheme.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _LightTheme.blueShadow(
                    blur: 12,
                    offset: const Offset(0, 4),
                    opacity: 0.28,
                  ),
                ),
                child: Text(
                  '#${rank.rank}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _rankStat('XP', '${rank.xp}'),
              const SizedBox(width: 28),
              _rankStat('Level', '${rank.level}'),
              const SizedBox(width: 28),
              Expanded(child: _rankStat('School', rank.school)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStatChip(
                icon: '📝',
                label: 'Completed',
                value: '${rank.completedQuizzes}',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: '🔥',
                label: 'Streak',
                value: '${rank.currentStreak}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _LightTheme.textSecondary,
          ),
        ),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _LightTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _LightTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LightTheme.border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _LightTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _LightTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.3 Podium — with updated avatar
// ------------------------------------------------------------
class _Podium extends StatelessWidget {
  final List<LeaderboardPlayer> players;

  const _Podium({required this.players});

  static const _gold = Color(0xFFE8A93B);
  static const _silver = Color(0xFF9AA6C4);
  static const _bronze = Color(0xFFC97B45);

  @override
  Widget build(BuildContext context) {
    debugPrint("========== PODIUM BUILD ==========");
    debugPrint("Players count: ${players.length}");
    players.forEach((p) {
      debugPrint(
        "Player: ${p.name}, Avatar: '${p.avatar}', Avatar Empty: ${p.avatar.isEmpty}",
      );
    });
    debugPrint("==================================");

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: _LightTheme.card(radius: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (players.length >= 2)
            _podiumColumn(
              players[1],
              rank: 2,
              barHeight: 76,
              medalColor: _silver,
              medal: '🥈',
            ),
          if (players.isNotEmpty)
            _podiumColumn(
              players[0],
              rank: 1,
              barHeight: 104,
              medalColor: _gold,
              medal: '🥇',
            ),
          if (players.length >= 3)
            _podiumColumn(
              players[2],
              rank: 3,
              barHeight: 58,
              medalColor: _bronze,
              medal: '🥉',
            ),
        ],
      ),
    );
  }

  Widget _podiumColumn(
    LeaderboardPlayer player, {
    required int rank,
    required double barHeight,
    required Color medalColor,
    required String medal,
  }) {
    final avatarSize = rank == 1 ? 64.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        _AvatarWidget(
          avatarUrl: player.avatar,
          size: avatarSize,
          borderColor: medalColor,
          borderWidth: 2.5,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 76,
          child: Text(
            player.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _LightTheme.textPrimary,
            ),
          ),
        ),
        Text(
          '${player.xp} XP',
          style: const TextStyle(
            fontSize: 10,
            color: _LightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 76,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                medalColor.withValues(alpha: 0.35),
                medalColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: medalColor.withValues(alpha: 0.55)),
            boxShadow: _LightTheme.blueShadow(
              blur: 14,
              offset: const Offset(0, 6),
              opacity: 0.10,
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '#$rank',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: medalColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 6.4 Category Tabs
// ------------------------------------------------------------
class _CategoryTabs extends StatelessWidget {
  final TabController tabController;

  const _CategoryTabs({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _LightTheme.card(radius: 22),
      child: TabBar(
        controller: tabController,
        labelColor: Colors.white,
        unselectedLabelColor: _LightTheme.textSecondary,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_LightTheme.primaryBlue, _LightTheme.accentCyan],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _LightTheme.blueShadow(
            blur: 14,
            offset: const Offset(0, 5),
            opacity: 0.28,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'National'),
          Tab(text: 'School'),
          Tab(text: 'District'),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.5 Leaderboard List
// ------------------------------------------------------------
class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardPlayer> players;

  const _LeaderboardList({required this.players});

  @override
  Widget build(BuildContext context) {
    debugPrint("========== LEADERBOARD LIST ==========");
    debugPrint("Players count: ${players.length}");
    if (players.isNotEmpty) {
      debugPrint("First player avatar: '${players.first.avatar}'");
      debugPrint("First player avatar empty: ${players.first.avatar.isEmpty}");
    }
    debugPrint("======================================");

    if (players.isEmpty) {
      return const Center(
        child: Text(
          'No players found',
          style: TextStyle(color: _LightTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) => _PlayerTile(player: players[index]),
    );
  }
}

// ------------------------------------------------------------
// 6.6 Player Tile — with updated avatar
// ------------------------------------------------------------
class _PlayerTile extends StatelessWidget {
  final LeaderboardPlayer player;

  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final isTopThree = player.rank <= 3;

    debugPrint("Player Tile - ${player.name}: Avatar '${player.avatar}'");

    return Hero(
      tag: 'player_${player.id}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTopThree
              ? _LightTheme.primaryBlue.withValues(alpha: 0.06)
              : _LightTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopThree
                ? _LightTheme.primaryBlue.withValues(alpha: 0.30)
                : _LightTheme.border,
          ),
          boxShadow: _LightTheme.blueShadow(
            blur: 16,
            offset: const Offset(0, 6),
            opacity: isTopThree ? 0.14 : 0.08,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                '#${player.rank}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isTopThree
                      ? _LightTheme.primaryBlue
                      : _LightTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _AvatarWidget(avatarUrl: player.avatar, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _LightTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    player.school,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _LightTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.xp} XP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _LightTheme.textPrimary,
                  ),
                ),
                Text(
                  'Level ${player.level}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _LightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
