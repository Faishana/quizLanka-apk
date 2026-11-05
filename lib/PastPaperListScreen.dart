// ============================
// ApiConfig (add these)
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
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/past_paper_quiz_screen.dart';

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
  final http.Client _client = http.Client();

  Future<List<PastPaper>> getPastPapers({
    required int subjectId,
    String? medium,
    int? year,
  }) async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final query = <String, String>{'subject_id': subjectId.toString()};
    if (medium != null && medium.isNotEmpty) query['medium'] = medium;
    if (year != null) query['year'] = year.toString();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.pastPaperList}',
    ).replace(queryParameters: query);

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: ApiConfig.getHeaders(token))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Could not reach the server. Please try again.');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Received an invalid response from the server.');
    }

    debugPrint('Past Paper List Status: ${response.statusCode}');
    debugPrint('Past Paper List Body: ${response.body}');

    if (response.statusCode == 200 && data['success'] == true) {
      // Backend uses paginate(20) → data is { data: [...], ... }
      final payload = data['data'];
      List<dynamic> list;

      if (payload is Map<String, dynamic> && payload['data'] is List) {
        list = payload['data'] as List;
      } else if (payload is List) {
        list = payload;
      } else {
        throw Exception('Invalid past paper data received from server.');
      }

      return list
          .map((e) => PastPaper.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }
    if (response.statusCode == 403) {
      throw Exception(
        data['message'] ?? 'You are not allowed to access past papers.',
      );
    }
    if (response.statusCode == 422) {
      throw Exception(data['message'] ?? 'Invalid past paper request.');
    }
    if (response.statusCode >= 500) {
      throw Exception('Server error. Please try again later.');
    }

    throw Exception(data['message'] ?? 'Failed to load past papers.');
  }

  void dispose() => _client.close();
}

// ============================================================
// SCREEN
// ============================================================

class PastPaperListScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final String medium;
  // NOTE: `category` removed — backend infers it from the auth user.

  const PastPaperListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.medium, required String category,
  });

  @override
  State<PastPaperListScreen> createState() => _PastPaperListScreenState();
}

class _PastPaperListScreenState extends State<PastPaperListScreen> {
  final PastPaperListService _service = PastPaperListService();
  late Future<List<PastPaper>> _papersFuture;

  @override
  void initState() {
    super.initState();
    _papersFuture = _load();
  }

  Future<List<PastPaper>> _load() => _service.getPastPapers(
    subjectId: widget.subjectId,
    medium: widget.medium,
  );

  void _retry() {
    setState(() => _papersFuture = _load());
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  String get _mediumName {
    switch (widget.medium) {
      case 'si':
        return 'Sinhala Medium';
      case 'en':
        return 'English Medium';
      case 'ta':
        return 'Tamil Medium';
      default:
        return widget.medium.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: FutureBuilder<List<PastPaper>>(
                future: _papersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildError(snapshot.error.toString());
                  }

                  final papers = snapshot.data ?? [];
                  if (papers.isEmpty) return _buildEmpty();

                  return RefreshIndicator(
                    color: const Color(0xFF7C3AED),
                    onRefresh: () async {
                      _retry();
                      await _papersFuture;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        _buildHero(papers.length),
                        const SizedBox(height: 24),
                        const Text(
                          'Available Past Papers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF181B34),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose a paper to start your practice.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7086),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...papers.map(
                          (paper) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PastPaperCard(
                              paper: paper,
                              onTap: () => _openPaper(paper),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDCE7F7)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF181B34),
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Past Papers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF181B34),
                  ),
                ),
                Text(
                  widget.subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7086),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x457C3AED),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subjectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _mediumName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count Past Paper${count == 1 ? '' : 's'}',
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: Color(0xFF7C3AED),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Past Papers Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181B34),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'There are no $_mediumName past papers '
              'available for ${widget.subjectName} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7086),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load past papers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181B34),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7086)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
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
    );
  }

  void _openPaper(PastPaper paper) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PastPaperQuizScreen(paperId: paper.id)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE7F7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10232B6B),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${paper.year} ${paper.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF181B34),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Paper ${paper.paperNumber} • $_mediumLabel',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7086),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${paper.questionsCount} Questions',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6B7086),
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
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF7C3AED),
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
