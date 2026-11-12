// past_paper_subject_selection_screen.dart
// ============================================================
// QuizLanka AI — Past Paper Subject Selection
// Dedicated subject selection for Grade 5 / O/L / A/L / GOV
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart' show TokenStorage, LoginScreen;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/past_paper_language_selection_screen.dart';

const Color _pageBg = Color(0xFFF1F5FC);

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// ============================================================
// 1. MODEL
// ============================================================

class PastPaperSubject {
  final int id;
  final String name;
  final String? slug;
  final String? icon;
  final String? color;
  final String? description;
  final int pastPapersCount;

  PastPaperSubject({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.color,
    this.description,
    required this.pastPapersCount,
  });

  factory PastPaperSubject.fromJson(Map<String, dynamic> json) {
    return PastPaperSubject(
      id: _toInt(json['id']),
      name: (json['name'] ?? 'Subject').toString(),
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      description: json['description'] as String?,
      pastPapersCount: _toInt(json['past_papers_count']),
    );
  }

  Color get flutterColor {
    try {
      final value = (color ?? '').replaceAll('#', '');
      if (value.length == 6) return Color(int.parse('FF$value', radix: 16));
    } catch (_) {}
    return const Color(0xFF1E4FD8);
  }
}

// ============================================================
// 2. SERVICE
// ============================================================

class PastPaperSubjectService {
  final http.Client _client = http.Client();

  Future<List<PastPaperSubject>> getSubjects({required String category}) async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    http.Response response;

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pastPaperSubjects}'
        '?category=${Uri.encodeQueryComponent(category)}',
      );

      response = await _client
          .get(uri, headers: ApiConfig.getHeaders(token))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Could not reach the server. Please try again.');
    }

    debugPrint('Past Paper Subjects status: ${response.statusCode}');

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
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

    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'];
      if (list is! List) {
        throw Exception('Invalid past paper subjects data received.');
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(PastPaperSubject.fromJson)
          .toList();
    }

    throw Exception(data['message'] ?? 'Failed to load past paper subjects.');
  }

  void dispose() => _client.close();
}

// ============================================================
// 3. SCREEN
// ============================================================

class PastPaperSubjectSelectionScreen extends StatefulWidget {
  final String category;
  final String title;

  const PastPaperSubjectSelectionScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<PastPaperSubjectSelectionScreen> createState() =>
      _PastPaperSubjectSelectionScreenState();
}

class _PastPaperSubjectSelectionScreenState
    extends State<PastPaperSubjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  final PastPaperSubjectService _service = PastPaperSubjectService();
  late final AnimationController _entry;

  List<PastPaperSubject>? _subjects;
  String? _error;
  bool _loading = true;

  bool _searchOpen = false;
  String _query = '';

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

  Future<void> _load() async {
    if (_subjects == null) setState(() => _loading = true);

    try {
      final list = await _service.getSubjects(category: widget.category);
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _error = null;
        _loading = false;
      });
      _entry
        ..reset()
        ..forward();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (_subjects == null) {
        setState(() {
          _error = msg;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: QL.danger,
            content: Text(msg),
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

  List<PastPaperSubject> _applyFilter(List<PastPaperSubject> subjects) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return subjects;
    return subjects.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  void _openSubject(PastPaperSubject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PastPaperLanguageSelectionScreen(
          subjectId: subject.id,
          subjectName: subject.name,
          category: widget.category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        _HeaderButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Back',
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Choose a subject to view past papers',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: QL.ice, fontSize: 13),
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
    if (_loading && _subjects == null) {
      return const Center(
        child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
      );
    }

    final all = _subjects;
    if (all == null) {
      final msg = _error ?? 'Something went wrong.';
      return _ErrorView(
        message: msg,
        sessionExpired: msg.toLowerCase().contains('session expired'),
        onRetry: _load,
        onLogin: _goToLogin,
      );
    }

    final subjects = _applyFilter(all);
    final totalPapers = all.fold<int>(0, (sum, s) => sum + s.pastPapersCount);

    return RefreshIndicator(
      onRefresh: _load,
      color: QL.blue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (all.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyView())
          else ...[
            SliverToBoxAdapter(
              child: _StatsBanner(
                subjectCount: all.length,
                totalPapers: totalPapers,
              ),
            ),
            if (subjects.isEmpty)
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
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 178,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final subject = subjects[index];
                    return _SubjectTile(
                      subject: subject,
                      index: index,
                      controller: _entry,
                      onTap: () => _openSubject(subject),
                    );
                  }, childCount: subjects.length),
                ),
              ),
            ],
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
  const _StatsBanner({required this.subjectCount, required this.totalPapers});

  final int subjectCount;
  final int totalPapers;

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
                icon: Icons.description_rounded,
                value: '$totalPapers',
                label: 'Past papers',
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
          'Available subjects',
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
              sessionExpired ? 'Session expired' : 'Unable to load past papers',
              textAlign: TextAlign.center,
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
  const _EmptyView();

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
                color: QL.navy,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 40,
                color: QL.gold,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No past papers available',
              style: TextStyle(
                color: QL.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Past paper subjects will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: QL.muted, fontSize: 14),
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
          Icon(Icons.verified_outlined, size: 14, color: QL.muted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Practise with previous exam papers',
              style: TextStyle(fontSize: 12, color: QL.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatefulWidget {
  final PastPaperSubject subject;
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

  IconData _fallbackIcon(String name) {
    final v = name.toLowerCase();
    if (v.contains('math')) return Icons.calculate_outlined;
    if (v.contains('science')) return Icons.science_outlined;
    if (v.contains('english')) return Icons.menu_book_outlined;
    if (v.contains('sinhala') || v.contains('tamil')) {
      return Icons.translate_rounded;
    }
    if (v.contains('ict') || v.contains('computer')) {
      return Icons.computer_outlined;
    }
    if (v.contains('history')) return Icons.account_balance_outlined;
    if (v.contains('commerce')) return Icons.bar_chart_rounded;
    if (v.contains('bio')) return Icons.eco_outlined;
    if (v.contains('physic')) return Icons.bolt_outlined;
    if (v.contains('chem')) return Icons.science_rounded;
    if (v.contains('geo')) return Icons.public_outlined;
    if (v.contains('art')) return Icons.palette_outlined;
    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final color = subject.flutterColor;
    final hasIcon = subject.icon != null && subject.icon!.isNotEmpty;

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
        label: '${subject.name}, ${subject.pastPapersCount} past papers',
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
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDCE4F4)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12123066),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        padding: EdgeInsets.all(hasIcon ? 9 : 0),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: hasIcon
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  subject.icon!,
                                  fit: BoxFit.contain,
                                  headers: const {'Accept': 'image/*'},
                                  errorBuilder: (context, error, stack) => Icon(
                                    _fallbackIcon(subject.name),
                                    color: color,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Icon(
                                _fallbackIcon(subject.name),
                                color: color,
                                size: 28,
                              ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF0FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: QL.blue,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    subject.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: QL.ink,
                      fontSize: 16,
                      height: 1.2,
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
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 13,
                          color: QL.blue,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${subject.pastPapersCount} papers',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: QL.blue,
                            ),
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
    );
  }
}
