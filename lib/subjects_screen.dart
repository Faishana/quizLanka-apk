// subjects_screen.dart
// ============================================================
// SUBJECTS SCREEN — aligned with StudentSubjectController
//
// Backend contract (GET /api/subjects):
//  200 { success:true,  grade_category:'gov', grade:null, subjects:[...] }
//  200 { success:true,  grade:{id,name}, grade_category, al_stream, subjects:[...] }
//  200 { success:true,  subjects:[], message:"Please select your grade first." }
//  401 { success:false, message, subjects:[] }
//  422 { success:false, message:"Please select a valid A/L stream." }
//  500 { success:false, message:"Failed to load subjects." }
//
// Each subject: { id, name, slug, grade_category, icon|null, color,
//                 questions_count, description }
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart' show TokenStorage, LoginScreen;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/difficulty_screen.dart';

const Color _pageBg = Color(0xFFF1F5FC);

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

// ============================================================
// 1. MODELS
// ============================================================

class Subject {
  final int id;
  final String name;
  final String? slug;
  final String? gradeCategory;
  final String? icon; // full network URL or null
  final String color;
  final int? questionsCount;
  final String? description;

  Subject({
    required this.id,
    required this.name,
    this.slug,
    this.gradeCategory,
    this.icon,
    required this.color,
    this.questionsCount,
    this.description,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: _asInt(json['id'], fallback: 0),
      name: (json['name'] as String?) ?? 'Unknown Subject',
      slug: _asNullableString(json['slug']),
      gradeCategory: _asNullableString(json['grade_category']),
      icon: _asNullableString(json['icon']),
      color: _asNullableString(json['color']) ?? '#1E4FD8',
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
    'grade_category': gradeCategory,
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
        return const Color(0xFF1E4FD8);
      }
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1E4FD8);
    }
  }
}

class SubjectsResult {
  final List<Subject> subjects;
  final int? gradeId;
  final String? gradeName;
  final String? alStream;
  final String? gradeCategory;
  final String? message;
  final bool success;

  SubjectsResult({
    required this.subjects,
    this.gradeId,
    this.gradeName,
    this.alStream,
    this.gradeCategory,
    this.message,
    required this.success,
  });

  bool get hasGrade => gradeId != null;

  bool get isGovernmentExam => gradeCategory == 'gov';
}

// ============================================================
// 2. SUBJECT SERVICE
// ============================================================

class SubjectService {
  final http.Client _client = http.Client();

  Future<SubjectsResult> getSubjects() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
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
    } on http.ClientException {
      throw Exception('Could not reach the server. Please try again.');
    }

    debugPrint('Subjects API status: ${response.statusCode}');

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }

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
      final gradeCategory = data['grade_category'] as String?;

      return SubjectsResult(
        subjects: subjects,
        gradeId: gradeId,
        gradeName: gradeName,
        alStream: (alStream != null && alStream.isNotEmpty) ? alStream : null,
        gradeCategory: gradeCategory,
        message: serverMessage,
        success: true,
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        serverMessage ?? 'You do not have access to these subjects.',
      );
    }
    if (response.statusCode == 422) {
      throw Exception(serverMessage ?? 'Please select a valid A/L stream.');
    }
    if (response.statusCode >= 500) {
      throw Exception(serverMessage ?? 'Server error. Please try again later.');
    }

    throw Exception(serverMessage ?? 'Failed to load subjects.');
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 3. SUBJECTS SCREEN
// ============================================================

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final SubjectService _service = SubjectService();
  late final AnimationController _entry;

  SubjectsResult? _result;
  String? _error;
  bool _loading = true;

  bool _searchOpen = false;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _entry.dispose();
    super.dispose();
  }

  /// Loads subjects. Existing content stays visible while refreshing.
  Future<void> _load() async {
    if (_result == null) setState(() => _loading = true);

    try {
      final r = await _service.getSubjects();
      if (!mounted) return;
      setState(() {
        _result = r;
        _error = null;
        _loading = false;
      });
      _entry
        ..reset()
        ..forward();
    } catch (e) {
      if (!mounted) return;
      if (_result == null) {
        setState(() {
          _error = _clean(e);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: QL.danger,
            content: Text(_clean(e)),
          ),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openDifficultyScreen(Subject subject) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => DifficultyScreen(subject: subject),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
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
        ),
      ),
    );
  }

  List<Subject> _applyFilter(List<Subject> subjects) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return subjects;
    return subjects.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    final gradeName = _result?.gradeName;
    final stream = _result?.alStream;

    String subtitle = 'Select a subject to start learning';

    if (_result?.isGovernmentExam == true) {
      subtitle = 'Government Exams';
    } else if (gradeName != null && gradeName.isNotEmpty) {
      subtitle = stream != null ? '$gradeName · $stream' : gradeName;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [QL.navy, QL.navyDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(
                  color: QL.navyLight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (canPop) ...[
                          _HeaderButton(
                            icon: Icons.arrow_back_rounded,
                            label: 'Back',
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                        ] else
                          const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose subjects',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: QL.ice,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _HeaderButton(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          label: _searchOpen ? 'Close search' : 'Search',
                          active: _searchOpen,
                          onTap: () => setState(() {
                            _searchOpen = !_searchOpen;
                            if (!_searchOpen) _query = '';
                          }),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _searchOpen
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: TextField(
                                autofocus: true,
                                onChanged: (v) => setState(() => _query = v),
                                style: qlInputStyle,
                                cursorColor: QL.blue,
                                decoration: qlFieldDecoration(
                                  hint: 'Search subjects',
                                  icon: Icons.search_rounded,
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
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

  // ── Body ────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_loading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
      );
    }

    final result = _result;
    if (result == null) {
      final msg = _error ?? 'Something went wrong.';
      return _ErrorView(
        message: msg,
        sessionExpired: msg.toLowerCase().contains('session expired'),
        onRetry: _load,
        onLogin: _goToLogin,
      );
    }

    final all = result.subjects;
    final subjects = _applyFilter(all);
    final totalQuestions = all.fold<int>(
      0,
      (sum, s) => sum + (s.questionsCount ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: QL.blue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: _StatsBanner(
                subjectCount: all.length,
                totalQuestions: totalQuestions,
              ),
            ),
          if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyView(
                message: result.message,
                hasGrade: result.hasGrade,
                gradeName: result.gradeName,
                isGovernmentExam: result.isGovernmentExam,
              ),
            )
          else if (subjects.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NoResultsView(query: _query),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: _SectionLabel(count: subjects.length),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final subject = subjects[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubjectTile(
                      subject: subject,
                      index: index,
                      controller: _entry,
                      onTap: () => _openDifficultyScreen(subject),
                    ),
                  );
                }, childCount: subjects.length),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: _FooterNote()),
        ],
      ),
    );
  }
}

// ============================================================
// 4. WIDGETS
// ============================================================

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? QL.gold : QL.navyDeep,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: active ? QL.navy : Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.subjectCount,
    required this.totalQuestions,
  });

  final int subjectCount;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE4F4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14123066),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _BannerStat(
                icon: Icons.menu_book_rounded,
                value: '$subjectCount',
                label: 'Subjects',
              ),
            ),
            Container(width: 1, height: 44, color: const Color(0xFFE3E9F5)),
            Expanded(
              child: _BannerStat(
                icon: Icons.quiz_rounded,
                value: '$totalQuestions',
                label: 'Questions',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: QL.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: QL.gold, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: QL.ink,
                letterSpacing: -0.3,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: QL.muted)),
          ],
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
          'All subjects',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: QL.ink,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: QL.blue,
            ),
          ),
        ),
      ],
    );
  }
}

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
              sessionExpired ? 'Session expired' : 'Unable to load subjects',
              style: const TextStyle(
                color: QL.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QL.muted,
                fontSize: 14,
                height: 1.5,
              ),
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
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    this.message,
    this.hasGrade = false,
    this.gradeName,
    this.isGovernmentExam = false,
  });

  final String? message;
  final bool hasGrade;
  final String? gradeName;
  final bool isGovernmentExam;

  @override
  Widget build(BuildContext context) {
    final bool noGrade =
        !hasGrade &&
        !isGovernmentExam &&
        (message != null && message!.isNotEmpty);

    final String title = noGrade
        ? 'Set up your grade'
        : 'No subjects available';

    final String subtitle = noGrade
        ? (message ?? 'Please select your grade first.')
        : isGovernmentExam
        ? (message ?? 'Government examination subjects will appear here.')
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
                color: QL.navy,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                noGrade ? Icons.school_outlined : Icons.menu_book_outlined,
                size: 40,
                color: QL.gold,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QL.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QL.muted,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 38,
                color: QL.blue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No subjects match "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QL.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: QL.muted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'You can change subjects anytime from settings',
              style: TextStyle(fontSize: 12, color: QL.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Public: also used by other screens (e.g. DifficultyScreen).
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
    if (name.contains('sinhala') ||
        name.contains('tamil') ||
        name.contains('language')) {
      return Icons.translate_rounded;
    }
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
    if (name.contains('general knowledge') || name.contains('current')) {
      return Icons.public_rounded;
    }
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
        color: onTintedBg
            ? Colors.white.withValues(alpha: 0.24)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: hasIcon
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.2),
              child: Image.network(
                subject.icon!,
                fit: BoxFit.contain,
                headers: const {'Accept': 'image/*'},
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
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
                  debugPrint('Subject icon failed: ${subject.icon}');
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
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 18),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label: '${subject.name}, $questionCount questions',
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDCE4F4)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12123066),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SubjectIcon(subject: subject, color: color, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: QL.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.quiz_rounded,
                              size: 14,
                              color: QL.muted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$questionCount questions',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: QL.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF0FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: QL.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
