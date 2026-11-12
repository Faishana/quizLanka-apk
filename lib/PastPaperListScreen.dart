// ============================
// ApiConfig (these must exist)
// ============================
// static const String pastPaperSubjects = '/past-papers/subjects';
// static const String pastPaperList     = '/past-papers/list';
// static String pastPaperDetails(int id) => '/past-papers/$id';
// static String pastPaperSubmit(int id)  => '/past-papers/$id/submit';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart' show TokenStorage, LoginScreen;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/past_paper_quiz_screen.dart';

const Color _pageBg = Color(0xFFF1F5FC);

// ============================================================
// MODEL
// ============================================================

class PastPaper {
  final int id;
  final int gradeId;
  final int subjectId;
  final int year;
  final String medium;
  final String title;
  final int paperNumber;
  final int questionsCount;

  PastPaper({
    required this.id,
    required this.gradeId,
    required this.subjectId,
    required this.year,
    required this.medium,
    required this.title,
    required this.paperNumber,
    required this.questionsCount,
  });

  factory PastPaper.fromJson(Map<String, dynamic> json) {
    return PastPaper(
      id: (json['id'] as num).toInt(),
      gradeId: (json['grade_id'] as num?)?.toInt() ?? 0,
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      medium: json['medium'] as String? ?? 'en',
      title: json['title'] as String? ?? 'Past Paper',
      paperNumber: (json['paper_number'] as num?)?.toInt() ?? 1,
      questionsCount: (json['questions_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================
// SERVICE
// ============================================================

class PastPaperListService {
  final http.Client _client;

  PastPaperListService({http.Client? client})
    : _client = client ?? http.Client();

  /// Backend pagination limit
  static const int _maxPages = 10;

  /// Loads past papers filtered by language, subject and year.
  ///
  /// medium:
  /// en = English
  /// si = Sinhala
  /// ta = Tamil
  ///
  /// subjectId is optional.
  /// If null, all accessible subjects are included.
  Future<List<PastPaper>> getPastPapers({
    int? subjectId,
    required String medium,
    int? year,
  }) async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Validate language
    const supportedLanguages = ['en', 'si', 'ta'];

    if (!supportedLanguages.contains(medium)) {
      throw Exception('Invalid language selected.');
    }

    final papers = <PastPaper>[];

    int page = 1;
    int lastPage = 1;

    do {
      final result = await _fetchPage(
        token: token,
        subjectId: subjectId,
        medium: medium,
        year: year,
        page: page,
      );

      papers.addAll(result.papers);

      lastPage = result.lastPage;
      page++;
    } while (page <= lastPage && page <= _maxPages);

    // Newest year first, then paper number.
    papers.sort((a, b) {
      final byYear = b.year.compareTo(a.year);

      if (byYear != 0) {
        return byYear;
      }

      return (a.paperNumber ?? 0).compareTo(b.paperNumber ?? 0);
    });

    debugPrint('================================');
    debugPrint('Past Papers Loaded: ${papers.length}');
    debugPrint('Selected Language: $medium');
    debugPrint('Selected Subject: $subjectId');
    debugPrint('Selected Year: $year');
    debugPrint('================================');

    return papers;
  }

  // ============================================================
  // FETCH SINGLE PAGE
  // ============================================================

  Future<({List<PastPaper> papers, int lastPage})> _fetchPage({
    required String token,
    int? subjectId,
    required String medium,
    int? year,
    required int page,
  }) async {
    // Build query parameters
    final query = <String, String>{'medium': medium, 'page': page.toString()};

    if (subjectId != null) {
      query['subject_id'] = subjectId.toString();
    }

    if (year != null) {
      query['year'] = year.toString();
    }

    // Build API URL
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.pastPaperList}',
    ).replace(queryParameters: query);

    debugPrint('================================');
    debugPrint('Past Paper API Request');
    debugPrint('URL: $uri');
    debugPrint('Page: $page');
    debugPrint('================================');

    http.Response response;

    try {
      response = await _client
          .get(uri, headers: ApiConfig.getHeaders(token))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on http.ClientException catch (e) {
      debugPrint('HTTP Client Error: $e');

      throw Exception('Could not reach the server. Please try again.');
    }

    // ============================================================
    // RESPONSE STATUS
    // ============================================================

    debugPrint('Past Paper API Status: ${response.statusCode}');

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();

      throw Exception('Session expired. Please login again.');
    }

    // ============================================================
    // DECODE JSON
    // ============================================================

    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON response format.');
      }

      data = decoded;
    } catch (e) {
      debugPrint('JSON Decode Error: $e');
      debugPrint('Response Body: ${response.body}');

      throw Exception('Received an invalid response from the server.');
    }

    // ============================================================
    // ERROR HANDLING
    // ============================================================

    if (response.statusCode == 403) {
      throw Exception(
        data['message'] ?? 'You are not allowed to access past papers.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(data['message'] ?? 'Invalid past paper request.');
    }

    if (response.statusCode >= 500) {
      debugPrint('Server Error: ${response.body}');

      throw Exception('Server error. Please try again later.');
    }

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load past papers.');
    }

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to load past papers.');
    }

    // ============================================================
    // PARSE PAGINATION RESPONSE
    // ============================================================

    final payload = data['data'];

    List<dynamic> list;
    int lastPage = 1;

    if (payload is Map<String, dynamic>) {
      // Laravel paginate(20)
      final rawList = payload['data'];

      if (rawList is! List) {
        throw Exception('Invalid past paper list received from server.');
      }

      list = rawList;

      final lp = payload['last_page'];

      if (lp is num) {
        lastPage = lp.toInt();
      }
    } else if (payload is List) {
      // Non-paginated response
      list = payload;

      lastPage = 1;
    } else {
      throw Exception('Invalid past paper data received from server.');
    }

    // ============================================================
    // CONVERT JSON TO MODEL
    // ============================================================

    final parsedPapers = <PastPaper>[];

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        try {
          parsedPapers.add(PastPaper.fromJson(item));
        } catch (e) {
          debugPrint('Past Paper Parsing Error: $e');

          debugPrint('Invalid Paper JSON: $item');
        }
      }
    }

    debugPrint('Parsed Papers: ${parsedPapers.length}');

    debugPrint('Current Page: ${payload is Map ? payload['current_page'] : 1}');

    debugPrint('Last Page: $lastPage');

    return (papers: parsedPapers, lastPage: lastPage);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}

// ============================================================
// SCREEN
// ============================================================

class PastPaperListScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final String medium;

  /// Kept so existing callers still compile. The backend infers the
  /// category from the logged-in user, so it is not sent.
  final String category;

  const PastPaperListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.medium,
    required this.category,
  });

  @override
  State<PastPaperListScreen> createState() => _PastPaperListScreenState();
}

class _PastPaperListScreenState extends State<PastPaperListScreen> {
  final PastPaperListService _service = PastPaperListService();

  List<PastPaper>? _papers;
  String? _error;
  bool _loading = true;

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

  Future<void> _load() async {
    if (_papers == null) setState(() => _loading = true);

    try {
      final list = await _service.getPastPapers(
        subjectId: widget.subjectId,
        medium: widget.medium,
      );
      if (!mounted) return;
      setState(() {
        _papers = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (_papers == null) {
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

  String get _mediumName {
    switch (widget.medium) {
      case 'si':
        return 'Sinhala medium';
      case 'en':
        return 'English medium';
      case 'ta':
        return 'Tamil medium';
      default:
        return widget.medium.toUpperCase();
    }
  }

  void _openPaper(PastPaper paper) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PastPaperQuizScreen(paperId: paper.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    final count = _papers?.length;

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
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back',
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: QL.navyDeep,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: QL.gold,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.history_edu_rounded,
                            color: QL.navy,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Past papers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        widget.subjectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeaderChip(label: _mediumName),
                          if (count != null)
                            _HeaderChip(
                              label: '$count paper${count == 1 ? '' : 's'}',
                              gold: true,
                            ),
                        ],
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

  // ── Body ────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading && _papers == null) {
      return const Center(
        child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
      );
    }

    final papers = _papers;
    if (papers == null) return _buildError(_error ?? 'Something went wrong.');
    if (papers.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      color: QL.blue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const Text(
            'Available past papers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: QL.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a paper to start your practice.',
            style: TextStyle(fontSize: 13.5, color: QL.muted),
          ),
          const SizedBox(height: 16),
          for (final paper in papers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PastPaperCard(
                paper: paper,
                onTap: () => _openPaper(paper),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
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
                Icons.menu_book_outlined,
                color: QL.gold,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No past papers yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: QL.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no ${_mediumName.toLowerCase()} past papers '
              'for ${widget.subjectName} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: QL.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    final expired = error.toLowerCase().contains('session expired');

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
                expired ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
                color: QL.danger,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              expired ? 'Session expired' : 'Unable to load past papers',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: QL.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: QL.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: QLPrimaryButton(
                label: expired ? 'Log in' : 'Retry',
                onTap: expired ? _goToLogin : _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, this.gold = false});

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gold ? QL.gold : QL.navyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gold ? QL.navy : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================
// PAST PAPER CARD
// ============================================================

class _PastPaperCard extends StatelessWidget {
  final PastPaper paper;
  final VoidCallback onTap;

  const _PastPaperCard({required this.paper, required this.onTap});

  String get _mediumLabel {
    switch (paper.medium) {
      case 'si':
        return 'Sinhala';
      case 'en':
        return 'English';
      case 'ta':
        return 'Tamil';
      default:
        return paper.medium.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${paper.year} ${paper.title}';

    return Semantics(
      button: true,
      label:
          '$title, paper ${paper.paperNumber}, $_mediumLabel, '
          '${paper.questionsCount} questions',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: QL.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: QL.gold,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: QL.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paper ${paper.paperNumber} • $_mediumLabel',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: QL.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 14,
                          color: QL.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${paper.questionsCount} questions',
                          style: const TextStyle(fontSize: 12, color: QL.muted),
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
                  color: QL.blue,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
