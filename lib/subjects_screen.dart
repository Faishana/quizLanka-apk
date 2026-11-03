// subjects_screen.dart
// ============================================================
// PREMIUM SUBJECTS SCREEN — aligned with StudentSubjectController
//
// Backend contract (GET /api/subjects):
//  200 { success:true,  grade:{id,name}, al_stream, subjects:[...] }
//  200 { success:true,  subjects:[], message:"Please select your grade first." }
//  401 { success:false, message, subjects:[] }
//  422 { success:false, message:"Please select a valid A/L stream." }
//  500 { success:false, message:"Failed to load subjects." }
//
// Each subject: { id, name, slug, icon|null, color, questions_count, description }
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/difficulty_screen.dart';
import 'package:quiz_lanka/Login.dart';

// ============================================================
// 1. MODELS
// ============================================================

class Subject {
  final int id;
  final String name;
  final String? slug;
  final String? icon; // full network URL or null
  final String color;
  final int? questionsCount;
  final String? description;

  Subject({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    required this.color,
    this.questionsCount,
    this.description,
  });

  /// Robust parsing — backend sends `questions_count` as int,
  /// but we accept string too in case of count() serialization.
  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: _asInt(json['id'], fallback: 0),
      name: (json['name'] as String?) ?? 'Unknown Subject',
      slug: _asNullableString(json['slug']),
      icon: _asNullableString(json['icon']),
      color: _asNullableString(json['color']) ?? '#4E3AE8',
      questionsCount: json['questions_count'] == null
          ? null
          : _asInt(json['questions_count'], fallback: 0),
      description: _asNullableString(json['description']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'icon': icon,
    'color': color,
    'questions_count': questionsCount,
    'description': description,
  };

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  /// Supports `#RRGGBB`, `RRGGBB`, `#RGB`, `RGB`, `AARRGGBB`.
  Color get flutterColor {
    try {
      final cleaned = color.replaceAll('#', '').trim();
      String hex;
      if (cleaned.length == 3) {
        hex = cleaned.split('').map((c) => '$c$c').join();
      } else if (cleaned.length == 6) {
        hex = cleaned;
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      } else {
        return const Color(0xFF4E3AE8);
      }
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4E3AE8);
    }
  }
}

/// Result of GET /api/subjects — distinguishes empty-state causes.
class SubjectsResult {
  final List<Subject> subjects;
  final int? gradeId;
  final String? gradeName;
  final String? alStream;
  final String? message; // backend-provided hint when empty
  final bool success;

  SubjectsResult({
    required this.subjects,
    this.gradeId,
    this.gradeName,
    this.alStream,
    this.message,
    required this.success,
  });

  bool get hasGrade => gradeId != null;
}

// ============================================================
// 2. SUBJECT SERVICE
// ============================================================

class SubjectService {
  final http.Client _client = http.Client();

  /// Fetches subjects. Throws [Exception] only on auth / server /
  /// network failures. An empty (but successful) response is a
  /// valid result so the UI can show the correct empty-state.
  Future<SubjectsResult> getSubjects() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please login again.');
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

    debugPrint('Subjects API ${response.statusCode}: ${response.body}');

    // Parse body once, tolerate empty body.
    Map<String, dynamic> data;
    try {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw Exception('Received an invalid response from the server.');
    }

    final serverMessage = data['message'] as String?;

    // ---- 200: success (may be empty but valid) ----
    if (response.statusCode == 200 && data['success'] == true) {
      final rawList = data['subjects'];
      if (rawList != null && rawList is! List) {
        throw Exception('Invalid subjects data received from server.');
      }

      final subjects = (rawList as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Subject.fromJson)
          .toList();

      int? gradeId;
      String? gradeName;
      final grade = data['grade'];
      if (grade is Map<String, dynamic>) {
        final id = grade['id'];
        if (id is int) gradeId = id;
        if (id is String) gradeId = int.tryParse(id);
        gradeName = grade['name'] as String?;
      }

      final alStream = data['al_stream'] as String?;

      return SubjectsResult(
        subjects: subjects,
        gradeId: gradeId,
        gradeName: gradeName,
        alStream: (alStream != null && alStream.isNotEmpty) ? alStream : null,
        message: serverMessage,
        success: true,
      );
    }

    // ---- 401: unauthorized ----
    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception(serverMessage ?? 'Session expired. Please login again.');
    }

    // ---- 403: forbidden (no grade / not configured) ----
    if (response.statusCode == 403) {
      throw Exception(
        serverMessage ?? 'You do not have access to these subjects.',
      );
    }

    // ---- 422: invalid A/L stream ----
    if (response.statusCode == 422) {
      throw Exception(serverMessage ?? 'Please select a valid A/L stream.');
    }

    // ---- 5xx ----
    if (response.statusCode >= 500) {
      throw Exception(serverMessage ?? 'Server error. Please try again later.');
    }

    // ---- other 4xx ----
    throw Exception(serverMessage ?? 'Failed to load subjects.');
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 3. DESIGN TOKENS
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
// 4. SUBJECTS SCREEN
// ============================================================

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final SubjectService _service = SubjectService();
  late Future<SubjectsResult> _subjectsFuture;
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
      _query = '';
      _entryController
        ..reset()
        ..forward();
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
                  child: FutureBuilder<SubjectsResult>(
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

                      final result = snapshot.data;
                      final allSubjects = result?.subjects ?? const <Subject>[];
                      final subjects = _applyFilter(allSubjects);

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
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyView(
                                  message: result?.message,
                                  hasGrade: result?.hasGrade ?? false,
                                  gradeName: result?.gradeName,
                                ),
                              )
                            else if (subjects.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
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
// 5. WIDGETS
// ============================================================

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
                    const _HeroDivider(),
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
                    SizedBox(width: 8),
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

/// Empty-state that adapts to *why* the list is empty:
///   • No grade selected (backend `message` present, no grade object)
///   • Grade configured but no subjects → generic "no subjects" copy.
class _EmptyView extends StatelessWidget {
  const _EmptyView({this.message, this.hasGrade = false, this.gradeName});

  final String? message;
  final bool hasGrade;
  final String? gradeName;

  @override
  Widget build(BuildContext context) {
    final bool noGrade = !hasGrade && (message != null && message!.isNotEmpty);
    final String title = noGrade
        ? 'Set up your grade'
        : 'No subjects available';
    final String subtitle = noGrade
        ? (message ?? 'Please select your grade first.')
        : (gradeName != null
              ? 'No active subjects for $gradeName yet.'
              : 'Subjects for your grade will appear here.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: Icon(
                noGrade ? Icons.school_outlined : Icons.menu_book_outlined,
                size: 40,
                color: _Palette.violet,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Palette.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (name.contains('qa') || name.contains('aptitude')) {
      return Icons.psychology_outlined;
    }
    if (name.contains('language')) return Icons.translate_rounded;
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
                  debugPrint("❌ Subject icon failed: $error");
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
                  style: const TextStyle(
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
