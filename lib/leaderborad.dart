// leaderboard_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 2. MODELS — unchanged
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
    return LeaderboardPlayer(
      rank: json['rank'] ?? 0,
      id: json['id'] ?? '',
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
// 3. API SERVICE — unchanged
// ============================================================
class LeaderboardService {
  Future<LeaderboardResponse> fetchLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboard}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LeaderboardResponse.fromJson(data);
      } else {
        throw Exception('Failed to load leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching leaderboard: $e');
    }
  }
}

// ============================================================
// 4. LEADERBOARD SCREEN — updated with KeepAlive, removed bottom bar
// ============================================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

// ✅ Step 5: Added AutomaticKeepAliveClientMixin
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

  // ✅ Step 3: Removed _handleBack() method completely

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
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -60,
              child: _GlowBlob(color: AppTheme.violet, size: 240),
            ),
            Positioned(
              top: 140,
              left: -70,
              child: _GlowBlob(color: AppTheme.cyan, size: 200),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // ✅ Step 4: Updated Header with inline back logic
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
                              color: AppTheme.violet,
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
// 5. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 5.0 Ambient glow blob
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
          color: color.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.1 Header — simplified, only checks canPop
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
              color: AppTheme.textPrimary,
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
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.1b Error Widget
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
                color: AppTheme.danger.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 36,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load leaderboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
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
                    colors: [AppTheme.violet, AppTheme.cyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
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
// 5.2 My Rank — hero gradient banner (was a flat glass card)
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
            AppTheme.violet.withValues(alpha: 0.32),
            AppTheme.cyan.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                  color: Colors.white.withValues(alpha: 0.14),
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
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
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 5.3 Podium — staggered bars instead of three equal columns
// ------------------------------------------------------------
class _Podium extends StatelessWidget {
  final List<LeaderboardPlayer> players;

  const _Podium({required this.players});

  static const _gold = Color(0xFFFFD24C);
  static const _silver = Color(0xFFC7CCD8);
  static const _bronze = Color(0xFFE0985B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: AppTheme.glassCard(radius: 24),
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
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: medalColor, width: 2.5),
            color: medalColor.withValues(alpha: 0.18),
            image: player.avatar.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(player.avatar),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: player.avatar.isEmpty
              ? Icon(Icons.person, color: medalColor, size: avatarSize * 0.5)
              : null,
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
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          '${player.xp} XP',
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
                medalColor.withValues(alpha: 0.5),
                medalColor.withValues(alpha: 0.14),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: medalColor.withValues(alpha: 0.5)),
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
// 5.4 Category Tabs
// ------------------------------------------------------------
class _CategoryTabs extends StatelessWidget {
  final TabController tabController;

  const _CategoryTabs({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(radius: 22),
      child: TabBar(
        controller: tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.violet, AppTheme.cyan],
          ),
          borderRadius: BorderRadius.circular(14),
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
// 5.5 Leaderboard List
// ------------------------------------------------------------
class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardPlayer> players;

  const _LeaderboardList({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text(
          'No players found',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
// 5.6 Player Tile
// ------------------------------------------------------------
class _PlayerTile extends StatelessWidget {
  final LeaderboardPlayer player;

  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final isTopThree = player.rank <= 3;

    return Hero(
      tag: 'player_${player.id}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTopThree
              ? AppTheme.violet.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopThree
                ? AppTheme.violet.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.1),
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
                  color: isTopThree ? AppTheme.violet : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                image: player.avatar.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(player.avatar),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: player.avatar.isEmpty
                  ? const Icon(Icons.person, color: AppTheme.violet, size: 20)
                  : null,
            ),
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
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    player.school,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
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
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Level ${player.level}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
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
