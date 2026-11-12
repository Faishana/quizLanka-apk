import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart' show TokenStorage;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';

const Color _pageBg = Color(0xFFF1F5FC);
const Color _tint = Color(0xFFEAF0FF);
const Color _success = Color(0xFF1B7F4B);

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _toNullableInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _mediumName(String medium) {
  switch (medium) {
    case 'si':
      return 'Sinhala';
    case 'en':
      return 'English';
    case 'ta':
      return 'Tamil';
    default:
      return medium.toUpperCase();
  }
}

// ============================================================
// MODELS
// ============================================================

class PastPaperQuizOption {
  final int id;
  final String key;
  final String text;

  const PastPaperQuizOption({
    required this.id,
    required this.key,
    required this.text,
  });

  factory PastPaperQuizOption.fromJson(Map<String, dynamic> json) {
    return PastPaperQuizOption(
      id: _toInt(json['id']),
      key: (json['option_key'] ?? '').toString(),
      text: (json['option_text'] ?? '').toString(),
    );
  }
}

class PastPaperQuizQuestion {
  final int id;
  final int questionNumber;
  final String questionText;
  final String? imageUrl;
  final String? difficulty;
  final List<PastPaperQuizOption> options;

  const PastPaperQuizQuestion({
    required this.id,
    required this.questionNumber,
    required this.questionText,
    required this.imageUrl,
    required this.difficulty,
    required this.options,
  });

  factory PastPaperQuizQuestion.fromJson(Map<String, dynamic> json) {
    return PastPaperQuizQuestion(
      id: _toInt(json['id']),
      questionNumber: _toInt(json['question_number']),
      questionText: json['question_text'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      difficulty: json['difficulty'] as String?,
      options: (json['options'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => PastPaperQuizOption.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class PastPaperQuizData {
  final int id;
  final int year;
  final String medium;
  final String title;
  final int? paperNumber;
  final int totalQuestions;
  final String gradeName;
  final String subjectName;
  final List<PastPaperQuizQuestion> questions;

  const PastPaperQuizData({
    required this.id,
    required this.year,
    required this.medium,
    required this.title,
    required this.paperNumber,
    required this.totalQuestions,
    required this.gradeName,
    required this.subjectName,
    required this.questions,
  });

  factory PastPaperQuizData.fromJson(Map<String, dynamic> json) {
    final grade = json['grade'] is Map
        ? Map<String, dynamic>.from(json['grade'])
        : <String, dynamic>{};
    final subject = json['subject'] is Map
        ? Map<String, dynamic>.from(json['subject'])
        : <String, dynamic>{};

    return PastPaperQuizData(
      id: _toInt(json['id']),
      year: _toInt(json['year']),
      medium: json['medium'] as String? ?? '',
      title: json['title'] as String? ?? '',
      paperNumber: _toNullableInt(json['paper_number']),
      totalQuestions: _toInt(json['total_questions']),
      gradeName: grade['name'] as String? ?? '',
      subjectName: subject['name'] as String? ?? '',
      questions: (json['questions'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => PastPaperQuizQuestion.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

// ============================================================
// SERVICE
// ============================================================

class PastPaperQuizService {
  static const Duration _timeout = Duration(seconds: 20);

  // ------------------------------------------------------------
  // TOKEN
  // ------------------------------------------------------------

  static Future<String> _getToken() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    return token;
  }

  // ------------------------------------------------------------
  // HEADERS
  // ------------------------------------------------------------

  static Map<String, String> _headers(String token) {
    return {
      ...ApiConfig.getHeaders(token),
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // ------------------------------------------------------------
  // NETWORK ERROR
  // ------------------------------------------------------------

  static String _networkMessage(Object e) {
    if (e is TimeoutException) {
      return 'The request timed out. Please try again.';
    }

    if (e is SocketException) {
      return 'No internet connection. Please check your network.';
    }

    if (e is http.ClientException) {
      return 'Could not reach the server. Please try again.';
    }

    return 'Could not complete the request. Please try again.';
  }

  // ------------------------------------------------------------
  // JSON DECODER
  // ------------------------------------------------------------

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const FormatException();
    } catch (e) {
      debugPrint('JSON Error: $e');
      debugPrint('Response: ${response.body}');

      throw Exception('Received an invalid response from the server.');
    }
  }

  // ------------------------------------------------------------
  // COMMON RESPONSE CHECK
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> _request(
    Future<http.Response> request,
  ) async {
    http.Response response;

    try {
      response = await request.timeout(_timeout);
    } catch (e) {
      throw Exception(_networkMessage(e));
    }

    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      throw Exception('Session expired. Please login again.');
    }

    final body = _decode(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      debugPrint('API Error: ${response.body}');

      throw Exception(body['message'] ?? 'Request failed. Please try again.');
    }

    return body;
  }

  // ------------------------------------------------------------
  // 1. GET PAST PAPER DETAILS
  // ------------------------------------------------------------

  static Future<PastPaperQuizData> getPaper(int paperId) async {
    final token = await _getToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.pastPaperDetails(paperId)}',
    );

    debugPrint('GET PAPER: $uri');

    final body = await _request(http.get(uri, headers: _headers(token)));

    if (body['data'] is! Map) {
      throw Exception('Invalid past paper details.');
    }

    return PastPaperQuizData.fromJson(Map<String, dynamic>.from(body['data']));
  }

  // ------------------------------------------------------------
  // 2. START OR RESUME QUIZ
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> startPaper(int paperId) async {
    final token = await _getToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.pastPaperStart(paperId)}',
    );

    debugPrint('START PAPER: $uri');

    final body = await _request(http.post(uri, headers: _headers(token)));

    if (body['data'] is! Map) {
      throw Exception('Invalid quiz start response.');
    }

    final data = Map<String, dynamic>.from(body['data']);

    final quizId = int.tryParse(data['quiz_id']?.toString() ?? '');

    if (quizId == null || quizId <= 0) {
      throw Exception('Quiz ID was not returned by the server.');
    }

    debugPrint('Quiz Started Successfully');
    debugPrint('Paper ID: $paperId');
    debugPrint('Quiz ID: $quizId');
    debugPrint('Remaining Seconds: ${data['remaining_seconds']}');
    debugPrint('Resumed: ${data['is_resumed']}');

    return data;
  }

  // ------------------------------------------------------------
  // 3. SUBMIT QUIZ
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> submitPaper({
    required int paperId,
    required int quizId,
    required Map<int, String> answers,
  }) async {
    final token = await _getToken();

    if (quizId <= 0) {
      throw Exception('Invalid quiz ID.');
    }

    final answerList = answers.entries.map((entry) {
      return {'question_id': entry.key, 'answer': entry.value};
    }).toList();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.pastPaperSubmit(paperId)}',
    );

    // IMPORTANT: Include quiz_id in request body.
    final requestBody = {'quiz_id': quizId, 'answers': answerList};

    debugPrint('SUBMIT PAPER: $uri');
    debugPrint('Quiz ID: $quizId');
    debugPrint('Answers: ${answerList.length}');

    final body = await _request(
      http.post(uri, headers: _headers(token), body: jsonEncode(requestBody)),
    );

    if (body['data'] is! Map) {
      throw Exception('Invalid quiz result received.');
    }

    return Map<String, dynamic>.from(body['data']);
  }
}

// ============================================================
// QUIZ SCREEN
// ============================================================

class PastPaperQuizScreen extends StatefulWidget {
  final int paperId;

  const PastPaperQuizScreen({super.key, required this.paperId});

  @override
  State<PastPaperQuizScreen> createState() => _PastPaperQuizScreenState();
}

class _PastPaperQuizScreenState extends State<PastPaperQuizScreen> {
  PastPaperQuizData? _paper;

  int? _quizId;
  int _remainingSeconds = 0;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;

  int _currentIndex = 0;

  /// questionId -> selected option key
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadPaper();
  }

  Future<void> _loadPaper() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _quizId = null;
    });

    try {
      // STEP 01: Get paper details
      final paper = await PastPaperQuizService.getPaper(widget.paperId);

      if (!mounted) return;

      // STEP 02: Start or resume quiz
      final quizData = await PastPaperQuizService.startPaper(widget.paperId);

      if (!mounted) return;

      // STEP 03: Get Quiz ID
      final quizId = int.tryParse(quizData['quiz_id']?.toString() ?? '');

      if (quizId == null || quizId <= 0) {
        throw Exception('Invalid quiz ID received.');
      }

      // STEP 04: Save quiz information
      setState(() {
        _paper = paper;
        _quizId = quizId;

        _remainingSeconds = _toInt(quizData['remaining_seconds']);

        _loading = false;
      });

      debugPrint('================================');
      debugPrint('PAST PAPER READY');
      debugPrint('Paper ID: ${widget.paperId}');
      debugPrint('Quiz ID: $_quizId');
      debugPrint('Remaining: $_remainingSeconds');
      debugPrint('Resumed: ${quizData['is_resumed']}');
      debugPrint('================================');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectAnswer(String optionKey) {
    final paper = _paper;
    if (paper == null || paper.questions.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() => _answers[paper.questions[_currentIndex].id] = optionKey);
  }

  void _goTo(int index) {
    final paper = _paper;
    if (paper == null) return;
    if (index < 0 || index >= paper.questions.length) return;
    setState(() => _currentIndex = index);
  }

  void _nextQuestion() {
    final paper = _paper;
    if (paper == null) return;

    if (_currentIndex < paper.questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _showSubmitDialog();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  // ── Dialogs ─────────────────────────────────────────────────
  Future<bool> _confirm({
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: QL.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: QL.muted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(cancelLabel, style: const TextStyle(color: QL.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: QL.blue,
              minimumSize: const Size(88, 44),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showSubmitDialog() async {
    final paper = _paper;
    if (paper == null) return;

    final unanswered = paper.questions.length - _answers.length;

    final ok = await _confirm(
      title: 'Submit paper?',
      message: unanswered > 0
          ? 'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}. '
                'Do you want to submit now?'
          : 'You have answered all questions. Do you want to submit?',
      cancelLabel: 'Keep going',
      confirmLabel: 'Submit',
    );

    if (ok) await _submitQuiz();
  }

  Future<void> _requestExit() async {
    if (_submitting) return;

    if (_answers.isEmpty || _paper == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final leave = await _confirm(
      title: 'Leave this paper?',
      message: 'Your answers will be lost if you leave now.',
      cancelLabel: 'Stay',
      confirmLabel: 'Leave',
    );

    if (leave && mounted) Navigator.pop(context);
  }

  Future<void> _submitQuiz() async {
    if (_submitting || _paper == null) return;

    // Check Quiz ID before submitting.
    if (_quizId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz session not found. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await PastPaperQuizService.submitPaper(
        paperId: widget.paperId,
        quizId: _quizId!,
        answers: _answers,
      );

      if (!mounted) return;

      debugPrint('================================');
      debugPrint('QUIZ SUBMITTED SUCCESSFULLY');
      debugPrint('Paper ID: ${widget.paperId}');
      debugPrint('Quiz ID: $_quizId');
      debugPrint('Result: $result');
      debugPrint('================================');

      HapticFeedback.lightImpact();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PastPaperResultScreen(paper: _paper!, result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: QL.danger,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _showQuestionMap() {
    final paper = _paper;
    if (paper == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: QL.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${_answers.length} of ${paper.questions.length} answered',
                      style: const TextStyle(
                        fontSize: 13,
                        color: QL.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: paper.questions.length,
                    itemBuilder: (_, i) {
                      final q = paper.questions[i];
                      final answered = _answers.containsKey(q.id);
                      final current = i == _currentIndex;
                      return Semantics(
                        button: true,
                        label:
                            'Question ${i + 1}, ${answered ? 'answered' : 'not answered'}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            _goTo(i);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: answered ? QL.navy : QL.fieldFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: current ? QL.gold : QL.border,
                                width: current ? 2.5 : 1.5,
                              ),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: answered ? Colors.white : QL.ink,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _LegendDot(color: QL.navy),
                    SizedBox(width: 6),
                    Text(
                      'Answered',
                      style: TextStyle(fontSize: 12.5, color: QL.muted),
                    ),
                    SizedBox(width: 16),
                    _LegendDot(color: QL.fieldFill, border: QL.border),
                    SizedBox(width: 6),
                    Text(
                      'Not answered',
                      style: TextStyle(fontSize: 12.5, color: QL.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canLeaveFreely = _paper == null || _answers.isEmpty;

    return PopScope(
      canPop: canLeaveFreely && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(backgroundColor: _pageBg, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: QL.blue, strokeWidth: 2.5),
      );
    }

    if (_errorMessage != null) return _buildError();

    if (_paper == null || _paper!.questions.isEmpty) return _buildEmpty();

    return _buildQuiz();
  }

  Widget _plainTopBar() {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Semantics(
            button: true,
            label: 'Back',
            child: InkWell(
              onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: QL.navy,
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
        ),
      ),
    );
  }

  Widget _buildError() {
    final expired = (_errorMessage ?? '').toLowerCase().contains('session');

    return Column(
      children: [
        _plainTopBar(),
        Expanded(
          child: Center(
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
                      expired
                          ? Icons.lock_outline_rounded
                          : Icons.cloud_off_rounded,
                      size: 34,
                      color: QL.danger,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    expired ? 'Session expired' : 'Unable to load paper',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: QL.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Something went wrong.',
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
                      label: 'Try again',
                      onTap: _loadPaper,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        _plainTopBar(),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 60, color: QL.muted),
                  SizedBox(height: 16),
                  Text(
                    'No questions available for this paper.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: QL.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz() {
    final paper = _paper!;
    final question = paper.questions[_currentIndex];
    final selectedAnswer = _answers[question.id];

    return Column(
      children: [
        _buildHeader(paper),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_currentIndex), // resets scroll per question
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionCard(question),
                const SizedBox(height: 16),
                for (final option in question.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildOptionCard(
                      option: option,
                      selected: selectedAnswer == option.key,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _buildBottomBar(paper),
      ],
    );
  }

  // ── Header with progress ────────────────────────────────────
  Widget _buildHeader(PastPaperQuizData paper) {
    final total = paper.questions.length;
    final progress = (_currentIndex + 1) / total;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [QL.navy, QL.navyDeep],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: InkWell(
                        onTap: _submitting ? null : _requestExit,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.subjectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${paper.year} • ${_mediumName(paper.medium)}',
                            style: const TextStyle(color: QL.ice, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Show all questions',
                      child: InkWell(
                        onTap: _showQuestionMap,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: QL.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: QL.navy,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Question ${_currentIndex + 1} of $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_answers.length} answered',
                      style: const TextStyle(
                        color: QL.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: QL.navyDeep,
                    valueColor: const AlwaysStoppedAnimation<Color>(QL.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Question ────────────────────────────────────────────────
  Widget _buildQuestionCard(PastPaperQuizQuestion question) {
    final hasImage =
        question.imageUrl != null && question.imageUrl!.trim().isNotEmpty;
    final difficulty = (question.difficulty ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE4F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12123066),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: QL.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Q${question.questionNumber}',
                  style: const TextStyle(
                    color: QL.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (difficulty.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    difficulty[0].toUpperCase() + difficulty.substring(1),
                    style: const TextStyle(
                      color: QL.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                color: QL.fieldFill,
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  question.imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: QL.blue,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 44,
                        color: QL.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 17,
              height: 1.55,
              fontWeight: FontWeight.w700,
              color: QL.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required PastPaperQuizOption option,
    required bool selected,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Option ${option.key}: ${option.text}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _submitting ? null : () => _selectAnswer(option.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _tint : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? QL.blue : const Color(0xFFDCE4F4),
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? QL.blue : _tint,
                ),
                child: Text(
                  option.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : QL.navy,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.45,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: QL.ink,
                    ),
                  ),
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(top: 7, left: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: QL.blue,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fixed bottom buttons ────────────────────────────────────
  Widget _buildBottomBar(PastPaperQuizData paper) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == paper.questions.length - 1;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDCE4F4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: isFirst || _submitting ? null : _previousQuestion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: QL.navy,
                  side: BorderSide(
                    color: isFirst ? QL.border : QL.navy,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(QL.fieldRadius),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: QLPrimaryButton(
              label: isLast ? 'Submit paper' : 'Next',
              isLoading: _submitting,
              onTap: _submitting ? () {} : _nextQuestion,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, this.border});

  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: border != null ? Border.all(color: border!, width: 1.5) : null,
      ),
    );
  }
}

// ============================================================
// RESULT SCREEN
// ============================================================

class PastPaperResultScreen extends StatelessWidget {
  final PastPaperQuizData paper;
  final Map<String, dynamic> result;

  const PastPaperResultScreen({
    super.key,
    required this.paper,
    required this.result,
  });

  String _message(double pct) {
    if (pct >= 75) return 'Excellent work!';
    if (pct >= 50) return 'Good effort. Keep going!';
    return 'Keep practising. You will improve!';
  }

  @override
  Widget build(BuildContext context) {
    final summary = result['summary'] is Map
        ? Map<String, dynamic>.from(result['summary'])
        : <String, dynamic>{};

    final total = _toInt(summary['total_questions'], paper.questions.length);
    final correct = _toInt(summary['correct_answers']);
    final wrong = _toInt(summary['wrong_answers']);
    final unanswered = _toInt(summary['unanswered_questions']);
    final percentage = _toDouble(summary['percentage']).clamp(0.0, 100.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [QL.navy, QL.navyDeep],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your result',
                          style: TextStyle(
                            color: QL.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paper.subjectName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${paper.year} • ${_mediumName(paper.medium)}',
                          style: const TextStyle(color: QL.ice, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFDCE4F4)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14123066),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Semantics(
                            label:
                                'Score ${percentage.toStringAsFixed(0)} percent',
                            child: SizedBox(
                              width: 176,
                              height: 176,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 176,
                                    height: 176,
                                    child: CircularProgressIndicator(
                                      value: percentage / 100,
                                      strokeWidth: 13,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: _tint,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        percentage >= 50 ? QL.blue : QL.danger,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.w800,
                                          color: QL.ink,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const Text(
                                        'Score',
                                        style: TextStyle(
                                          color: QL.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _message(percentage),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: QL.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$correct of $total questions correct',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: QL.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.check_circle_rounded,
                            title: 'Correct',
                            value: '$correct',
                            color: _success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.cancel_rounded,
                            title: 'Wrong',
                            value: '$wrong',
                            color: QL.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.remove_circle_rounded,
                            title: 'Skipped',
                            value: '$unanswered',
                            color: QL.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFDCE4F4))),
              ),
              child: QLPrimaryButton(
                label: 'Back to dashboard',
                onTap: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4F4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: QL.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: QL.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
