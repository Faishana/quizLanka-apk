// subjects_screen.dart
// ============================================================
// PREMIUM REDESIGN — same data flow, same background asset,
// upgraded visual language: refined typography, soft glass
// surfaces, layered shadows, gradient accents, subtle motion.
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/difficulty_screen.dart';

// ============================================================
// 2. MODELS — UNCHANGED (do not modify)
// ============================================================

class Subject {
  final int id;
  final String name;
  final String? icon; // full network URL (asset('storage/...'))
  final String color;
  final int? questionsCount;
  final String? description;

  Subject({
    required this.id,
    required this.name,
    this.icon,
    required this.color,
    this.questionsCount,
    this.description,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    debugPrint("Subject: ${json['name']}");
    debugPrint("Icon: ${json['icon']}");

    return Subject(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String,
      questionsCount: json['questions_count'] as int?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'questions_count': questionsCount,
    'description': description,
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
// 3. SUBJECT SERVICE — UNCHANGED (do not modify)
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

    debugPrint('Subjects API Status: ${response.statusCode}');
    debugPrint('Subjects API Response: ${response.body}');

    /*
  |--------------------------------------------------------------------------
  | SUCCESS
  |--------------------------------------------------------------------------
  */

    if (response.statusCode == 200 && data['success'] == true) {
      final subjectsList = data['subjects'];

      if (subjectsList == null || subjectsList is! List) {
        throw Exception('Invalid subjects data received from server.');
      }

      return subjectsList
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    /*
  |--------------------------------------------------------------------------
  | UNAUTHORIZED
  |--------------------------------------------------------------------------
  */

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();

      throw Exception('Session expired. Please login again.');
    }

    /*
  |--------------------------------------------------------------------------
  | SERVER ERROR
  |--------------------------------------------------------------------------
  */

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
// 4. DESIGN TOKENS — premium palette: deep ink text, richer
// violet/indigo gradient, softer glass-white surfaces, more
// deliberate elevation and spacing.
// ============================================================

class _Palette {
  _Palette._();

  static const Color violet = Color(0xFF6D28D9);
  static const Color violetDeep = Color(0xFF4C1D95);
  static const Color gold = Color(0xFFF5B942);
  static const List<Color> ctaGradient = [Color(0xFF7C3AED), Color(0xFF2563EB)];
  static const List<Color> heroGradient = [
    Color(0xFF6D28D9),
    Color(0xFF4338CA),
    Color(0xFF2563EB),
  ];

  // Same background asset as before.
  static const String backgroundAsset = 'assets/sub_bg.png';

  static const List<Color> pageGradientFallback = [
    Color(0xFFEDE9FE),
    Color(0xFFF1EEFB),
    Color(0xFFF9F9FD),
  ];

  static const Color cardWhite = Colors.white;
  static const Color border = Color(0xFFECE9F6);
  static const Color borderSoft = Color(0xFFF1EFFA);

  static const Color textPrimary = Color(0xFF15142B);
  static const Color textSecondary = Color(0xFF6E7188);
  static const Color textMuted = Color(0xFF9A9CB0);

  static const Color danger = Color(0xFFEF4444);

  static BoxDecoration glass({double radius = 18}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A232B6B),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}

// ============================================================
// 5. SUBJECTS SCREEN
// ------------------------------------------------------------
// FutureBuilder, state management and navigation
// (_openDifficultyScreen → DifficultyScreen) are unchanged — a
// single tap on any subject card still goes straight to the
// difficulty screen for that subject.
// ============================================================

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final SubjectService _service = SubjectService();
  late Future<List<Subject>> _subjectsFuture;
  late final AnimationController _entryController;

  bool _searchOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _service.getSubjects();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _service.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _subjectsFuture = _service.getSubjects();
    });
  }

  void _openDifficultyScreen(Subject subject) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => DifficultyScreen(subject: subject),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  List<Subject> _applyFilter(List<Subject> subjects) {
    if (_query.trim().isEmpty) return subjects;
    final q = _query.trim().toLowerCase();
    return subjects.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FD),
      body: Stack(
        children: [
          // Same background artwork asset, unchanged path.
          Positioned.fill(
            child: Image.asset(
              _Palette.backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _Palette.pageGradientFallback,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  searchOpen: _searchOpen,
                  onToggleSearch: () {
                    setState(() {
                      _searchOpen = !_searchOpen;
                      if (!_searchOpen) _query = '';
                    });
                  },
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 240),
                  crossFadeState: _searchOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: _SearchField(
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
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

                      final allSubjects = snapshot.data!;
                      final subjects = _applyFilter(allSubjects);

                      // Calculate total quizzes from all subjects
                      final totalQuizzes = allSubjects.fold<int>(
                        0,
                        (sum, s) => sum + (s.questionsCount ?? 0),
                      );

                      return RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        color: _Palette.violet,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            if (allSubjects.isNotEmpty)
                              SliverToBoxAdapter(
                                child: _HeroStatsBanner(
                                  subjectCount: allSubjects.length,
                                  totalQuizzes: totalQuizzes,
                                ),
                              ),
                            if (allSubjects.isEmpty)
                              const SliverFillRemaining(child: _EmptyView())
                            else if (subjects.isEmpty)
                              SliverFillRemaining(
                                child: _NoResultsView(query: _query),
                              )
                            else ...[
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  6,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _SectionLabel(count: subjects.length),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  28,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        childAspectRatio: 0.88,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final subject = subjects[index];
                                    return _SubjectTile(
                                      subject: subject,
                                      index: index,
                                      controller: _entryController,
                                      onTap: () =>
                                          _openDifficultyScreen(subject),
                                    );
                                  }, childCount: subjects.length),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(child: _FooterNote()),
                          ],
                        ),
                      );
                    },
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

// ============================================================
// 6. WIDGETS
// ============================================================

// ------------------------------------------------------------
// 6.1 Top Bar — glass surface buttons, tighter premium type.
// ------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.searchOpen,
    required this.onToggleSearch,
  });

  final VoidCallback onBack;
  final bool searchOpen;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          _CircleIconButton(
            icon: canPop
                ? Icons.arrow_back_ios_new_rounded
                : Icons.home_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: _Palette.ctaGradient,
                  ).createShader(bounds),
                  child: const Text(
                    'Choose Subjects',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Select a subject to start learning',
                  style: TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CircleIconButton(
            icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
            onTap: onToggleSearch,
            active: searchOpen,
          ),
          const SizedBox(width: 10),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _Palette.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: const Text('Notifications are coming soon'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(colors: _Palette.ctaGradient)
                  : null,
              color: active ? null : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? _Palette.violet.withValues(alpha: 0.35)
                      : const Color(0x14232B6B),
                  blurRadius: active ? 16 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : _Palette.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.2 Search field
// ------------------------------------------------------------
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _Palette.glass(radius: 16),
      child: TextField(
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(
          color: _Palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          hintText: 'Search subjects…',
          hintStyle: TextStyle(color: _Palette.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _Palette.violet,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.3 Hero stats banner — premium gradient card with only
// Subjects and Total Quizzes (Ready Now removed)
// ------------------------------------------------------------
class _HeroStatsBanner extends StatelessWidget {
  const _HeroStatsBanner({
    required this.subjectCount,
    required this.totalQuizzes,
  });

  final int subjectCount;
  final int totalQuizzes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _Palette.heroGradient,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _Palette.violetDeep.withValues(alpha: 0.32),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -22,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 96,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: _Palette.gold,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Your Learning Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                        value: '$subjectCount',
                        label: 'Total Subjects',
                        icon: Icons.menu_book_rounded,
                      ),
                    ),
                    _HeroDivider(),
                    Expanded(
                      child: _HeroStat(
                        value: '$totalQuizzes',
                        label: 'Total Quizzes',
                        icon: Icons.quiz_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.18),
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 17),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 6.3b Section label above the grid.
// ------------------------------------------------------------
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'All Subjects',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _Palette.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _Palette.violet.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _Palette.violet,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// 6.4 Loading View
// ------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _Palette.ctaGradient),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _Palette.violet.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Loading subjects…',
            style: TextStyle(
              color: _Palette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.5 Error View
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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _Palette.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: _Palette.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load subjects',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Palette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _Palette.ctaGradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.violet.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
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
// 6.6 Empty View
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _Palette.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _Palette.border),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: _Palette.violet,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No subjects available',
            style: TextStyle(
              color: _Palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Subjects for your grade will appear here',
            style: TextStyle(color: _Palette.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.7 No Results View
// ------------------------------------------------------------
class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _Palette.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _Palette.border),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 38,
              color: _Palette.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No subjects match "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.8 Footer note
// ------------------------------------------------------------
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Palette.borderSoft),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: _Palette.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                'You can change subjects anytime from settings',
                style: TextStyle(fontSize: 11.5, color: _Palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 6.9 Subject Icon — same network image behaviour, refined
// container proportions and a subtle inner glow for a premium
// feel. Public (not prefixed with _) so difficulty_screen.dart
// can reuse it there too.
// ------------------------------------------------------------
class SubjectIcon extends StatelessWidget {
  final Subject subject;
  final Color color;
  final double size;
  final bool onTintedBg;

  const SubjectIcon({
    super.key,
    required this.subject,
    required this.color,
    this.size = 56,
    this.onTintedBg = false,
  });

  IconData _fallbackIcon() {
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
    if (name.contains('bio')) return Icons.eco_outlined;
    if (name.contains('physic')) return Icons.bolt_outlined;
    if (name.contains('chem')) return Icons.science_rounded;
    if (name.contains('geo')) return Icons.public_outlined;
    if (name.contains('art')) return Icons.palette_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final hasIcon = subject.icon != null && subject.icon!.isNotEmpty;
    final iconColor = onTintedBg ? Colors.white : color;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(hasIcon ? size * 0.15 : 0),
      decoration: BoxDecoration(
        gradient: onTintedBg
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.06),
                ],
              ),
        color: onTintedBg ? Colors.white.withValues(alpha: 0.24) : null,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: onTintedBg
            ? null
            : Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: hasIcon
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.2),
              child: Image.network(
                subject.icon!,
                fit: BoxFit.contain,
                headers: const {"Accept": "image/*"},
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    debugPrint("✅ Image Loaded: ${subject.icon}");
                    return child;
                  }

                  return Center(
                    child: SizedBox(
                      width: size * 0.3,
                      height: size * 0.3,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint("❌ Image Error: $error");
                  debugPrint("❌ URL: ${subject.icon}");

                  return Icon(
                    _fallbackIcon(),
                    color: iconColor,
                    size: size * 0.5,
                  );
                },
              ),
            )
          : Icon(_fallbackIcon(), color: iconColor, size: size * 0.5),
    );
  }
}

// ------------------------------------------------------------
// 6.10 Subject Tile — premium card: staggered fade/slide entry,
// gradient icon backdrop, refined type scale, tactile tap scale,
// and a soft colored glow keyed to the subject's own color.
// Layout still icon → name → quiz-count line only, no fabricated
// progress/XP/rank data.
// "Coming soon" removed — always shows question count
// ------------------------------------------------------------
class _SubjectTile extends StatefulWidget {
  final Subject subject;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.subject,
    required this.index,
    required this.controller,
    required this.onTap,
  });

  @override
  State<_SubjectTile> createState() => _SubjectTileState();
}

class _SubjectTileState extends State<_SubjectTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final color = subject.flutterColor;
    final questionCount = subject.questionsCount ?? 0;

    final start = (0.04 * widget.index).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 18),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: _Palette.cardWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SubjectIcon(subject: subject, color: color, size: 60),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_rounded, size: 12, color: color),
                      const SizedBox(width: 5),
                      Text(
                        '$questionCount Quizzes',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: color,
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
    );
  }
}
