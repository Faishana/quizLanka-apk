// past_paper_subject_selection_screen.dart
// ============================================================
// QuizLanka AI — Past Paper Subject Selection
// Dedicated subject selection for Grade 5 / O/L / A/L / GOV
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';

import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/past_paper_language_selection_screen.dart';

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
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      description: json['description'] as String?,
      pastPapersCount: (json['past_papers_count'] as num?)?.toInt() ?? 0,
    );
  }

  Color get flutterColor {
    try {
      final value = (color ?? '').replaceAll('#', '');

      if (value.length == 6) {
        return Color(int.parse('FF$value', radix: 16));
      }
    } catch (_) {}

    return const Color(0xFF6D28D9);
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
      throw Exception('Authentication token not found.');
    }

    http.Response response;

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pastPaperSubjects}'
        '?category=${Uri.encodeQueryComponent(category)}',
      );

      debugPrint('Past Paper Subjects URL: $uri');

      response = await _client
          .get(uri, headers: ApiConfig.getHeaders(token))
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

    debugPrint('Past Paper Subjects Status: ${response.statusCode}');

    debugPrint('Past Paper Subjects Response: ${response.body}');

    // ========================================================
    // SUCCESS
    // ========================================================

    if (response.statusCode == 200 && data['success'] == true) {
      final subjectsList = data['data'];

      if (subjectsList == null || subjectsList is! List) {
        throw Exception('Invalid past paper subjects data received.');
      }

      return subjectsList
          .map(
            (item) => PastPaperSubject.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    // ========================================================
    // UNAUTHORIZED
    // ========================================================

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();

      throw Exception('Session expired. Please login again.');
    }

    // ========================================================
    // SERVER ERROR
    // ========================================================

    if (response.statusCode >= 500) {
      throw Exception('Server error. Please try again later.');
    }

    throw Exception(data['message'] ?? 'Failed to load past paper subjects.');
  }

  void dispose() {
    _client.close();
  }
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
    with TickerProviderStateMixin {
  final PastPaperSubjectService _service = PastPaperSubjectService();

  late Future<List<PastPaperSubject>> _subjectsFuture;

  late final AnimationController _entryController;

  bool _searchOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();

    _subjectsFuture = _service.getSubjects(category: widget.category);

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

  // ==========================================================
  // REFRESH
  // ==========================================================

  void _refresh() {
    setState(() {
      _subjectsFuture = _service.getSubjects(category: widget.category);
    });
  }

  // ==========================================================
  // FILTER
  // ==========================================================

  List<PastPaperSubject> _applyFilter(List<PastPaperSubject> subjects) {
    if (_query.trim().isEmpty) {
      return subjects;
    }

    final query = _query.trim().toLowerCase();

    return subjects
        .where((subject) => subject.name.toLowerCase().contains(query))
        .toList();
  }

  // ==========================================================
  // OPEN SUBJECT
  // ==========================================================

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
      backgroundColor: const Color(0xFFF9F9FD),
      body: Stack(
        children: [
          // ====================================================
          // BACKGROUND
          // ====================================================
          Positioned.fill(
            child: Image.asset(
              _Palette.backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stack) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _Palette.pageGradientFallback,
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ==================================================
                // TOP BAR
                // ==================================================
                _TopBar(
                  title: widget.title,
                  searchOpen: _searchOpen,
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  onToggleSearch: () {
                    setState(() {
                      _searchOpen = !_searchOpen;

                      if (!_searchOpen) {
                        _query = '';
                      }
                    });
                  },
                ),

                // ==================================================
                // SEARCH
                // ==================================================
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 240),
                  crossFadeState: _searchOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: _SearchField(
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),

                // ==================================================
                // CONTENT
                // ==================================================
                Expanded(
                  child: FutureBuilder<List<PastPaperSubject>>(
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

                      final allSubjects = snapshot.data ?? [];

                      final subjects = _applyFilter(allSubjects);

                      final totalPapers = allSubjects.fold<int>(
                        0,
                        (total, subject) => total + subject.pastPapersCount,
                      );

                      if (allSubjects.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            _refresh();
                          },
                          color: _Palette.violet,
                          child: const CustomScrollView(
                            physics: AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [SliverFillRemaining(child: _EmptyView())],
                          ),
                        );
                      }

                      if (subjects.isEmpty) {
                        return _NoResultsView(query: _query);
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          _refresh();
                        },
                        color: _Palette.violet,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            // ======================================
                            // HERO
                            // ======================================
                            SliverToBoxAdapter(
                              child: _HeroStatsBanner(
                                subjectCount: allSubjects.length,
                                totalPapers: totalPapers,
                              ),
                            ),

                            // ======================================
                            // SECTION LABEL
                            // ======================================
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                              sliver: SliverToBoxAdapter(
                                child: _SectionLabel(count: subjects.length),
                              ),
                            ),

                            // ======================================
                            // SUBJECT GRID
                            // ======================================
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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
                                    onTap: () => _openSubject(subject),
                                  );
                                }, childCount: subjects.length),
                              ),
                            ),

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
// 4. DESIGN TOKENS
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
// 5. TOP BAR
// ============================================================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.searchOpen,
    required this.onToggleSearch,
  });

  final String title;
  final VoidCallback onBack;
  final bool searchOpen;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
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
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
                  'Choose a subject to view past papers',
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
            icon: _searchOpenIcon(searchOpen),
            onTap: onToggleSearch,
            active: searchOpen,
          ),
        ],
      ),
    );
  }

  IconData _searchOpenIcon(bool open) {
    return open ? Icons.close_rounded : Icons.search_rounded;
  }
}

// ============================================================
// 6. CIRCLE BUTTON
// ============================================================

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

// ============================================================
// 7. SEARCH FIELD
// ============================================================

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

// ============================================================
// 8. HERO STATS
// ============================================================

class _HeroStatsBanner extends StatelessWidget {
  const _HeroStatsBanner({
    required this.subjectCount,
    required this.totalPapers,
  });

  final int subjectCount;
  final int totalPapers;

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
                Icons.history_edu_rounded,
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
                        Icons.history_edu_rounded,
                        color: _Palette.gold,
                        size: 15,
                      ),
                    ),

                    const SizedBox(width: 8),

                    const Text(
                      'Past Paper Collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
                        label: 'Subjects',
                        icon: Icons.menu_book_rounded,
                      ),
                    ),

                    _HeroDivider(),

                    Expanded(
                      child: _HeroStat(
                        value: '$totalPapers',
                        label: 'Past Papers',
                        icon: Icons.description_outlined,
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

// ============================================================
// 9. SECTION LABEL
// ============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Available Subjects',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _Palette.textPrimary,
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

// ============================================================
// 10. LOADING
// ============================================================

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
            'Loading past paper subjects…',
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

// ============================================================
// 11. ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Unable to load past papers',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
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

// ============================================================
// 12. EMPTY
// ============================================================

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
              Icons.description_outlined,
              size: 40,
              color: _Palette.violet,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'No past papers available',
            style: TextStyle(
              color: _Palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Past paper subjects will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Palette.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 13. NO SEARCH RESULTS
// ============================================================

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

// ============================================================
// 14. FOOTER
// ============================================================

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
                Icons.verified_outlined,
                size: 13,
                color: _Palette.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                'Practice with previous exam papers',
                style: TextStyle(fontSize: 11.5, color: _Palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 15. SUBJECT TILE
// ============================================================

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
    final value = name.toLowerCase();

    if (value.contains('math')) {
      return Icons.calculate_outlined;
    }

    if (value.contains('science')) {
      return Icons.science_outlined;
    }

    if (value.contains('english')) {
      return Icons.menu_book_outlined;
    }

    if (value.contains('sinhala')) {
      return Icons.translate_rounded;
    }

    if (value.contains('tamil')) {
      return Icons.translate_rounded;
    }

    if (value.contains('ict') || value.contains('computer')) {
      return Icons.computer_outlined;
    }

    if (value.contains('history')) {
      return Icons.account_balance_outlined;
    }

    if (value.contains('commerce')) {
      return Icons.bar_chart_rounded;
    }

    if (value.contains('bio')) {
      return Icons.eco_outlined;
    }

    if (value.contains('physic')) {
      return Icons.bolt_outlined;
    }

    if (value.contains('chem')) {
      return Icons.science_rounded;
    }

    if (value.contains('geo')) {
      return Icons.public_outlined;
    }

    if (value.contains('art')) {
      return Icons.palette_outlined;
    }

    return Icons.school_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;

    final color = subject.flutterColor;

    final start = (0.04 * widget.index).clamp(0.0, 0.6);

    final end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    final hasIcon = subject.icon != null && subject.icon!.isNotEmpty;

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
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
        },
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
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.16),
                            color.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: hasIcon
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                subject.icon!,
                                fit: BoxFit.contain,
                                headers: const {'Accept': 'image/*'},
                                errorBuilder: (context, error, stack) {
                                  return Icon(
                                    _fallbackIcon(subject.name),
                                    color: color,
                                    size: 30,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              _fallbackIcon(subject.name),
                              color: color,
                              size: 30,
                            ),
                    ),

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
                      Icon(Icons.description_outlined, size: 12, color: color),
                      const SizedBox(width: 5),
                      Text(
                        '${subject.pastPapersCount} Past Papers',
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
