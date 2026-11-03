// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/Login.dart';

// ============================================================
// 2. MODELS
// ============================================================

/// Education category (scholarship / ol / al / gov).
class CategoryModel {
  final String value; // 'scholarship' | 'ol' | 'al' | 'gov'
  final String text; // Display label
  final String icon; // Material icon key — mapped in UI

  CategoryModel({
    required this.value,
    required this.text,
    this.icon = 'school',
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      value: (json['value'] ?? json['category'] ?? '').toString(),
      text: (json['text'] ?? json['name'] ?? '').toString(),
      icon: (json['icon'] ?? 'school').toString(),
    );
  }

  /// Fallback list — used when the backend categories endpoint fails.
  static List<CategoryModel> fallbackList() => [
    CategoryModel(
      value: 'scholarship',
      text: 'Grade 5 Scholarship',
      icon: 'emoji_events',
    ),
    CategoryModel(value: 'ol', text: 'Ordinary Level (O/L)', icon: 'menu_book'),
    CategoryModel(value: 'al', text: 'Advanced Level (A/L)', icon: 'science'),
    CategoryModel(
      value: 'gov',
      text: 'Government Exams',
      icon: 'account_balance',
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Grade — now carries its `category` and optional `al_streams` (for A/L).
class GradeModel {
  final int id;
  final String name;
  final String category; // 'scholarship' | 'ol' | 'al' | 'gov'
  final List<String> alStreams; // Only for 'al' grades

  GradeModel({
    required this.id,
    required this.name,
    required this.category,
    this.alStreams = const [],
  });

  bool get isAdvancedLevel => category == 'al';

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final int id;
    if (rawId is int) {
      id = rawId;
    } else if (rawId is num) {
      id = rawId.toInt();
    } else if (rawId is String) {
      id = int.tryParse(rawId) ?? 0;
    } else {
      id = 0;
    }

    final streamsRaw = json['al_streams'];
    final List<String> streams = streamsRaw is List
        ? streamsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return GradeModel(
      id: id,
      name: json['name'] is String ? json['name'] as String : 'Unassigned',
      category: (json['category'] ?? json['grade_category'] ?? '').toString(),
      alStreams: streams,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A/L stream option for UI dropdowns.
class AlStreamOption {
  final String value; // 'bio' | 'maths' | 'technology' | 'arts' | 'commerce'
  final String text;

  AlStreamOption({required this.value, required this.text});

  static final List<AlStreamOption> all = [
    AlStreamOption(value: 'bio', text: 'Biological Science'),
    AlStreamOption(value: 'maths', text: 'Physical Science / Maths'),
    AlStreamOption(value: 'technology', text: 'Technology'),
    AlStreamOption(value: 'arts', text: 'Arts'),
    AlStreamOption(value: 'commerce', text: 'Commerce'),
  ];

  static String labelFor(String? value) {
    if (value == null) return '';
    final match = all.where((s) => s.value == value).toList();
    return match.isEmpty ? value : match.first.text;
  }
}

class ProfileModel {
  final int id;
  final String name;
  final String email;
  final String? school;
  final String? district;
  final String? preferredMedium;
  final String? targetExam;
  final GradeModel? grade;
  final String? avatarUrl;
  final String? userCategory;

  // NEW fields
  final String? gradeCategory; // 'scholarship' | 'ol' | 'al' | 'gov'
  final String? alStream; // only for A/L

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.school,
    this.district,
    this.preferredMedium,
    this.targetExam,
    this.grade,
    this.avatarUrl,
    this.userCategory,
    this.gradeCategory,
    this.alStream,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    GradeModel? parsedGrade;
    final rawGrade = json['grade'];
    if (rawGrade is Map<String, dynamic> &&
        rawGrade['id'] != null &&
        rawGrade['name'] is String) {
      parsedGrade = GradeModel.fromJson(rawGrade);
    }

    // Category: prefer explicit field, fall back to grade.category
    final catFromJson = json['grade_category'];
    final category = (catFromJson is String && catFromJson.isNotEmpty)
        ? catFromJson
        : parsedGrade?.category;

    return ProfileModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      school: json['school'] is String ? json['school'] as String : null,
      district: json['district'] is String ? json['district'] as String : null,
      preferredMedium: json['preferred_medium'] is String
          ? json['preferred_medium'] as String
          : null,
      targetExam: json['target_exam'] is String
          ? json['target_exam'] as String
          : null,
      grade: parsedGrade,
      avatarUrl: json['profile_image'] is String
          ? json['profile_image'] as String
          : (json['avatar_url'] is String
                ? json['avatar_url'] as String
                : null),
      userCategory: json['user_category'] is String
          ? json['user_category'] as String
          : null,
      gradeCategory: category,
      alStream: json['al_stream'] is String
          ? json['al_stream'] as String
          : null,
    );
  }

  bool get isStudent => (userCategory ?? '').trim().toLowerCase() == 'student';

  bool get isGovernmentExamCandidate =>
      (userCategory ?? '').trim().toLowerCase() == 'government exam candidate';

  bool get isAdvancedLevel => gradeCategory == 'al';

  ProfileModel copyWith({
    String? name,
    String? school,
    String? district,
    String? preferredMedium,
    GradeModel? grade,
    String? targetExam,
    String? avatarUrl,
    String? gradeCategory,
    String? alStream,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email,
      school: school ?? this.school,
      district: district ?? this.district,
      preferredMedium: preferredMedium ?? this.preferredMedium,
      targetExam: targetExam ?? this.targetExam,
      grade: grade ?? this.grade,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userCategory: userCategory,
      gradeCategory: gradeCategory ?? this.gradeCategory,
      alStream: alStream ?? this.alStream,
    );
  }
}

// ============================================================
// Statistics / Ranking / Achievement / Progress models
// (unchanged — already null-safe)
// ============================================================

class ProfileStatistics {
  final int level;
  final int xp;
  final int requiredXp;
  final int completedQuizzes;
  final double averageAccuracy;
  final int timeSpentMinutes;
  final int currentStreak;
  final int longestStreak;

  ProfileStatistics({
    required this.level,
    required this.xp,
    required this.requiredXp,
    required this.completedQuizzes,
    required this.averageAccuracy,
    required this.timeSpentMinutes,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory ProfileStatistics.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    double _asDouble(dynamic v, {double fallback = 0}) {
      if (v is double) return v.isFinite ? v : fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return ProfileStatistics(
      level: _asInt(json['level'], fallback: 1),
      xp: _asInt(json['xp']),
      requiredXp: _asInt(json['required_xp'], fallback: 1000),
      completedQuizzes: _asInt(json['completed_quizzes']),
      averageAccuracy: _asDouble(json['average_accuracy']),
      timeSpentMinutes: _asInt(json['time_spent_minutes']),
      currentStreak: _asInt(json['current_streak']),
      longestStreak: _asInt(json['longest_streak']),
    );
  }
}

class ProfileRanking {
  final int nationalRank;
  final int schoolRank;

  ProfileRanking({required this.nationalRank, required this.schoolRank});

  factory ProfileRanking.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return ProfileRanking(
      nationalRank: _asInt(json['national_rank']),
      schoolRank: _asInt(json['school_rank']),
    );
  }
}

class AchievementModel {
  final int id;
  final String name;
  final String description;
  final String? icon;
  final String? color;

  AchievementModel({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.color,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] is int ? json['id'] as int : 0,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }
}

class SubjectProgressModel {
  final int id;
  final String name;
  final double accuracy;
  final int quizzesCompleted;
  final int xp;
  final int rank;

  SubjectProgressModel({
    required this.id,
    required this.name,
    required this.accuracy,
    required this.quizzesCompleted,
    required this.xp,
    required this.rank,
  });

  factory SubjectProgressModel.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double _asDouble(dynamic v) {
      if (v is double) return v.isFinite ? v : 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return SubjectProgressModel(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? '',
      accuracy: _asDouble(json['accuracy']),
      quizzesCompleted: _asInt(json['quizzes_completed']),
      xp: _asInt(json['xp']),
      rank: _asInt(json['rank']),
    );
  }
}

class WeeklyProgressModel {
  final String day;
  final double value;

  WeeklyProgressModel({required this.day, required this.value});

  factory WeeklyProgressModel.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is double) return v.isFinite ? v : 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return WeeklyProgressModel(
      day: (json['day'] as String?) ?? '',
      value: _asDouble(json['value']),
    );
  }
}

class StrongestSubjectModel {
  final String name;
  final double accuracy;

  StrongestSubjectModel({required this.name, required this.accuracy});

  factory StrongestSubjectModel.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is double) return v.isFinite ? v : 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return StrongestSubjectModel(
      name: (json['name'] as String?) ?? '',
      accuracy: _asDouble(json['accuracy']),
    );
  }
}

class AiImprovementModel {
  final double percentage;

  AiImprovementModel({required this.percentage});

  factory AiImprovementModel.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is double) return v.isFinite ? v : 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return AiImprovementModel(percentage: _asDouble(json['percentage']));
  }
}

class FullProfileResponse {
  final ProfileModel user;
  final ProfileStatistics statistics;
  final ProfileRanking ranking;
  final List<AchievementModel> achievements;
  final List<SubjectProgressModel> subjects;
  final List<WeeklyProgressModel> weeklyProgress;
  final StrongestSubjectModel? strongestSubject;
  final AiImprovementModel? aiImprovement;

  FullProfileResponse({
    required this.user,
    required this.statistics,
    required this.ranking,
    required this.achievements,
    required this.subjects,
    required this.weeklyProgress,
    this.strongestSubject,
    this.aiImprovement,
  });

  factory FullProfileResponse.fromJson(Map<String, dynamic> json) {
    return FullProfileResponse(
      user: ProfileModel.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      statistics: ProfileStatistics.fromJson(
        (json['statistics'] as Map<String, dynamic>?) ?? {},
      ),
      ranking: ProfileRanking.fromJson(
        (json['ranking'] as Map<String, dynamic>?) ?? {},
      ),
      achievements: ((json['achievements'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AchievementModel.fromJson)
          .toList(),
      subjects: ((json['subjects'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectProgressModel.fromJson)
          .toList(),
      weeklyProgress: ((json['weekly_progress'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WeeklyProgressModel.fromJson)
          .toList(),
      strongestSubject: json['strongest_subject'] is Map<String, dynamic>
          ? StrongestSubjectModel.fromJson(
              json['strongest_subject'] as Map<String, dynamic>,
            )
          : null,
      aiImprovement: json['ai_improvement'] is Map<String, dynamic>
          ? AiImprovementModel.fromJson(
              json['ai_improvement'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

// ============================================================
// 3. PROFILE SERVICE
// ============================================================

class ProfileService {
  final http.Client _client = http.Client();

  static const List<String> districts = [
    'Ampara',
    'Anuradhapura',
    'Badulla',
    'Batticaloa',
    'Colombo',
    'Galle',
    'Gampaha',
    'Hambantota',
    'Jaffna',
    'Kalutara',
    'Kandy',
    'Kegalle',
    'Kilinochchi',
    'Kurunegala',
    'Mannar',
    'Matale',
    'Matara',
    'Monaragala',
    'Mullaitivu',
    'Nuwara Eliya',
    'Polonnaruwa',
    'Puttalam',
    'Ratnapura',
    'Trincomalee',
    'Vavuniya',
  ];

  static const List<String> mediums = ['Sinhala', 'English', 'Tamil'];

  Future<FullProfileResponse> getProfile() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/profile'),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return FullProfileResponse.fromJson(data);
        }
        throw Exception(data['message'] ?? 'Failed to load profile');
      }
      if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Failed to load profile: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error loading profile: $e');
    }
  }

  /// Fetch grade categories.
  Future<List<CategoryModel>> getCategories() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/public/grade-categories'),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['data'] as List<dynamic>?;
          if (list == null || list.isEmpty) return CategoryModel.fallbackList();
          return list
              .whereType<Map<String, dynamic>>()
              .map(CategoryModel.fromJson)
              .toList();
        }
      }
      return CategoryModel.fallbackList();
    } catch (e) {
      debugPrint('getCategories failed, using fallback: $e');
      return CategoryModel.fallbackList();
    }
  }

  /// Fetch grades, optionally filtered by category.
  Future<List<GradeModel>> getGrades({String? category}) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/public/grades').replace(
        queryParameters: category != null && category.isNotEmpty
            ? {'category': category}
            : null,
      );

      final response = await _client
          .get(uri, headers: ApiConfig.getHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final gradesList = data['data'] as List<dynamic>?;
          if (gradesList == null) return <GradeModel>[];
          return gradesList
              .whereType<Map<String, dynamic>>()
              .map(GradeModel.fromJson)
              .toList();
        }
        throw Exception(data['message'] ?? 'Failed to load grades');
      }
      throw Exception('Failed to load grades: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error loading grades: $e');
    }
  }

  /// Update profile with grade_id + optional al_stream.
  Future<ProfileModel> updateProfile({
    required String name,
    int? gradeId,
    String? alStream,
    String? school,
    String? district,
    String? preferredMedium,
    String? targetExam,
    String? gradeCategory,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final body = jsonEncode({
      'name': name,
      if (gradeId != null) 'grade_id': gradeId,
      if (gradeCategory != null) 'grade_category': gradeCategory,
      if (alStream != null && alStream.isNotEmpty) 'al_stream': alStream,
      if (school != null && school.trim().isNotEmpty) 'school': school.trim(),
      if (district != null && district.trim().isNotEmpty)
        'district': district.trim(),
      if (preferredMedium != null && preferredMedium.trim().isNotEmpty)
        'preferred_medium': preferredMedium.trim(),
      if (targetExam != null && targetExam.trim().isNotEmpty)
        'target_exam': targetExam.trim(),
    });

    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/profile'),
            headers: {
              ...ApiConfig.getHeaders(token),
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ProfileModel.fromJson(
            data['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
          );
        }
        throw Exception(data['message'] ?? 'Failed to update profile');
      } else if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final msgs = errors.values
              .whereType<List<dynamic>>()
              .expand((e) => e)
              .map((e) => e.toString())
              .join('\n');
          throw Exception(msgs);
        }
        throw Exception('Validation error');
      }
      throw Exception('Failed to update profile: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  Future<void> uploadProfilePhoto(File image) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profilePhoto}'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.files.add(await http.MultipartFile.fromPath('photo', image.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    debugPrint('Status: ${response.statusCode}');
    debugPrint('Response: $body');

    if (response.statusCode != 200) {
      throw Exception(body);
    }
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 4. PALETTE
// ============================================================
class _Palette {
  static const bgTop = Color(0xFFF8F7FC);
  static const bgMid = Color(0xFFF2F0FA);
  static const bgBottom = Color(0xFFECE9F8);

  static const cardGlass = Color(0xFFFFFFFF);
  static const cardGlassLight = Color(0xFFF3F1FB);
  static const cardBorder = Color(0xFFE7E4F6);

  static const textPrimary = Color(0xFF1E1B3A);
  static const textSecondary = Color(0xFF6B6890);
  static const textMuted = Color(0xFF9490B8);

  static const neonCyan = Color(0xFF15AEDB);
  static const neonBlue = Color(0xFF4E6BFF);
  static const neonViolet = Color(0xFF7C5CFF);
  static const neonPink = Color(0xFFE24E90);
  static const neonGold = Color(0xFFDB9A2C);
  static const neonGreen = Color(0xFF10B981);

  static const danger = Color(0xFFE0435F);
  static const dangerBg = Color(0xFFFCE7EC);
}

// ============================================================
// 5. PROFILE SCREEN
// ============================================================

class ProfileScreen extends StatefulWidget {
  final Key? key;
  const ProfileScreen({this.key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _uploadingAvatar = false;
  String? _error;

  ProfileModel? _profile;
  FullProfileResponse? _fullProfile;

  List<CategoryModel> _categories = [];
  List<GradeModel> _allGrades = []; // full cache
  List<GradeModel> _filteredGrades = []; // by category

  late TextEditingController _nameController;
  late TextEditingController _schoolController;

  // Edit state
  CategoryModel? _selectedCategory;
  GradeModel? _selectedGrade;
  String? _selectedStream;
  String? _selectedDistrict;
  String? _selectedMedium;

  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30;

  bool get _isGovCandidate => _profile?.isGovernmentExamCandidate ?? false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _schoolController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _service.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fullProfile = await _service.getProfile();
      final profile = fullProfile.user;

      // Load categories + grades (best-effort)
      List<CategoryModel> cats = CategoryModel.fallbackList();
      List<GradeModel> grades = <GradeModel>[];
      try {
        cats = await _service.getCategories();
      } catch (e) {
        debugPrint('Categories load failed (using fallback): $e');
      }
      try {
        grades = await _service.getGrades();
      } catch (e) {
        debugPrint('Grades load failed (non-fatal): $e');
      }

      setState(() {
        _fullProfile = fullProfile;
        _profile = profile;
        _categories = cats;
        _allGrades = grades;

        _nameController.text = profile.name;
        _schoolController.text = profile.school ?? '';

        // Resolve category from profile
        final catValue = profile.gradeCategory ?? profile.grade?.category;
        _selectedCategory = catValue != null
            ? cats.firstWhere(
                (c) => c.value == catValue,
                orElse: () => cats.first,
              )
            : null;

        // Filter grades by category
        _filteredGrades = _selectedCategory != null
            ? grades
                  .where((g) => g.category == _selectedCategory!.value)
                  .toList()
            : grades;

        // Resolve grade
        if (profile.grade != null) {
          _selectedGrade = _filteredGrades.firstWhere(
            (g) => g.id == profile.grade!.id,
            orElse: () => profile.grade!,
          );
        } else {
          _selectedGrade = null;
        }

        // Resolve stream
        _selectedStream = profile.alStream;

        _selectedDistrict = profile.district;
        _selectedMedium = profile.preferredMedium;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final source = await _showImageSourcePicker();
      if (source == null) return;
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;

      setState(() => _uploadingAvatar = true);

      await _service.uploadProfilePhoto(File(image.path));
      _showGeneratingDialog();
      _pollProfileEvery2Seconds();
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<ImageSource?> _showImageSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _Palette.cardGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _Palette.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: _Palette.neonCyan,
              ),
              title: const Text(
                'Gallery',
                style: TextStyle(color: _Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: _Palette.neonCyan,
              ),
              title: const Text(
                'Camera',
                style: TextStyle(color: _Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: _Palette.danger),
              title: const Text(
                'Cancel',
                style: TextStyle(color: _Palette.danger),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGeneratingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _Palette.cardGlass,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: _Palette.neonCyan, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Generating Avatar...',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your profile picture is being processed.',
              style: TextStyle(color: _Palette.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _pollProfileEvery2Seconds() {
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
          _showSnackBar(
            'Avatar generation is taking longer than expected. Please refresh later.',
          );
        }
        return;
      }
      try {
        final updated = await _service.getProfile();
        if (updated.user.avatarUrl != null &&
            updated.user.avatarUrl!.isNotEmpty &&
            updated.user.avatarUrl != _profile?.avatarUrl) {
          timer.cancel();
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          setState(() {
            _fullProfile = updated;
            _profile = updated.user;
          });
          _showSnackBar('Avatar generated successfully');
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  /// Cascade: category → clears grade + stream
  void _onCategoryChanged(
    CategoryModel? cat,
    void Function(void Function()) sheetSetState,
  ) {
    if (cat == null) return;
    sheetSetState(() {
      setState(() {
        _selectedCategory = cat;
        _selectedGrade = null;
        _selectedStream = null;
        _filteredGrades = _allGrades
            .where((g) => g.category == cat.value)
            .toList();
      });
    });
  }

  /// Cascade: grade → clears stream if grade isn't A/L
  void _onGradeChanged(
    GradeModel? grade,
    void Function(void Function()) sheetSetState,
  ) {
    sheetSetState(() {
      setState(() {
        _selectedGrade = grade;
        if (grade == null || !grade.isAdvancedLevel) {
          _selectedStream = null;
        }
      });
    });
  }

  Future<void> _saveProfile(
    void Function(void Function()) sheetSetState,
  ) async {
    if (_profile == null) return;

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }

    if (!_isGovCandidate) {
      if (_selectedCategory == null) {
        _showSnackBar('Please select your education category', isError: true);
        return;
      }
      if (_selectedGrade == null) {
        _showSnackBar('Please select your grade', isError: true);
        return;
      }
      // A/L requires a stream
      if (_selectedGrade!.isAdvancedLevel &&
          (_selectedStream == null || _selectedStream!.isEmpty)) {
        _showSnackBar('Please select your A/L stream', isError: true);
        return;
      }
      if (_schoolController.text.trim().isEmpty) {
        _showSnackBar('Please enter your school', isError: true);
        return;
      }
      if (_selectedMedium == null || _selectedMedium!.isEmpty) {
        _showSnackBar('Please select your medium', isError: true);
        return;
      }
    }

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      _showSnackBar('Please select your district', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    sheetSetState(() {});

    try {
      final isAl = _selectedGrade?.isAdvancedLevel ?? false;

      final updated = await _service.updateProfile(
        name: _nameController.text.trim(),
        gradeId: _isGovCandidate ? null : _selectedGrade?.id,
        gradeCategory: _isGovCandidate ? null : _selectedCategory?.value,
        alStream: (_isGovCandidate || !isAl) ? null : _selectedStream,
        school: _isGovCandidate ? null : _schoolController.text.trim(),
        district: _selectedDistrict,
        preferredMedium: _isGovCandidate ? null : _selectedMedium,
      );

      setState(() {
        _profile = updated;
        _isSaving = false;
      });

      if (mounted) Navigator.pop(context, true);
      _showSnackBar('Profile updated successfully!');
    } catch (e) {
      setState(() => _isSaving = false);
      sheetSetState(() {});
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _Palette.danger : _Palette.neonViolet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showComingSoon(String feature) {
    _showSnackBar('$feature — coming soon!');
  }

  void _openEditProfileSheet() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: Container(
                  decoration: const BoxDecoration(
                    color: _Palette.bgMid,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _Palette.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: _Palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: _ProfileForm(
                            nameController: _nameController,
                            schoolController: _schoolController,
                            categories: _categories,
                            selectedCategory: _selectedCategory,
                            onCategoryChanged: (c) =>
                                _onCategoryChanged(c, sheetSetState),
                            grades: _filteredGrades,
                            selectedGrade: _selectedGrade,
                            onGradeChanged: (g) =>
                                _onGradeChanged(g, sheetSetState),
                            selectedStream: _selectedStream,
                            onStreamChanged: (s) => sheetSetState(() {
                              setState(() => _selectedStream = s);
                            }),
                            selectedDistrict: _selectedDistrict,
                            onDistrictChanged: (d) => sheetSetState(() {
                              setState(() => _selectedDistrict = d);
                            }),
                            selectedMedium: _selectedMedium,
                            onMediumChanged: (m) => sheetSetState(() {
                              setState(() => _selectedMedium = m);
                            }),
                            isGovCandidate: _isGovCandidate,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _SaveButton(
                          isSaving: _isSaving,
                          onSave: () => _saveProfile(sheetSetState),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.bgTop,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopHeader(
                  onBack: () => Navigator.maybePop(context),
                  onSettings: () => _showComingSoon('Settings'),
                  onNotifications: () => _showComingSoon('Notifications'),
                ),
                Expanded(
                  child: _isLoading
                      ? const _LoadingView()
                      : _error != null
                      ? _ErrorView(message: _error!, onRetry: _loadProfile)
                      : _ProfileContent(
                          profile: _profile!,
                          fullProfile: _fullProfile!,
                          selectedGrade: _selectedGrade,
                          uploadingAvatar: _uploadingAvatar,
                          onAvatarTap: _pickProfilePhoto,
                          onEditProfile: _openEditProfileSheet,
                          onShareProfile: () =>
                              _showComingSoon('Share Profile'),
                          onViewAchievements: () =>
                              _showComingSoon('Achievements'),
                          onPremiumUpgrade: () =>
                              _showComingSoon('Premium Upgrade'),
                          onLearningReports: () =>
                              _showComingSoon('Learning Reports'),
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

// ------------------------------------------------------------
// Background
// ------------------------------------------------------------
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.16,
            child: Image.asset(
              'assets/profile_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Palette.bgTop, _Palette.bgMid, _Palette.bgBottom],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: _Glow(
            color: _Palette.neonViolet.withValues(alpha: 0.10),
            size: 260,
          ),
        ),
        Positioned(
          top: 120,
          right: -80,
          child: _Glow(
            color: _Palette.neonCyan.withValues(alpha: 0.08),
            size: 220,
          ),
        ),
        Positioned(
          bottom: 40,
          left: -60,
          child: _Glow(
            color: _Palette.neonBlue.withValues(alpha: 0.07),
            size: 240,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
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
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Top header
// ------------------------------------------------------------
class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.onBack,
    required this.onSettings,
    required this.onNotifications,
  });

  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _IconGhostButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_Palette.neonCyan, _Palette.neonViolet],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.neonViolet.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'QuizLanka ',
                      style: TextStyle(
                        color: _Palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: 'AI',
                      style: TextStyle(
                        color: _Palette.neonCyan,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _IconGhostButton(icon: Icons.settings_rounded, onTap: onSettings),
          const SizedBox(width: 8),
          _IconGhostButton(
            icon: Icons.notifications_rounded,
            onTap: onNotifications,
          ),
        ],
      ),
    );
  }
}

class _IconGhostButton extends StatelessWidget {
  const _IconGhostButton({required this.icon, required this.onTap})
    : badge = null;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: _Palette.cardGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _Palette.cardBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 18, color: _Palette.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Loading view
// ------------------------------------------------------------
class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _skeleton({double height = 90, double? width}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: _Palette.cardGlass.withValues(
              alpha: 0.5 + _controller.value * 0.3,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Palette.cardBorder),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _skeleton(height: 200),
        const SizedBox(height: 16),
        _skeleton(height: 110),
        const SizedBox(height: 16),
        _skeleton(height: 140),
        const SizedBox(height: 16),
        _skeleton(height: 220),
      ],
    );
  }
}

// ------------------------------------------------------------
// Error view
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _Palette.dangerBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _Palette.danger.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: _Palette.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load profile',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 24),
            _GradientButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Profile Content
// ------------------------------------------------------------
class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.fullProfile,
    required this.selectedGrade,
    required this.uploadingAvatar,
    required this.onAvatarTap,
    required this.onEditProfile,
    required this.onShareProfile,
    required this.onViewAchievements,
    required this.onPremiumUpgrade,
    required this.onLearningReports,
  });

  final ProfileModel profile;
  final FullProfileResponse fullProfile;
  final GradeModel? selectedGrade;
  final bool uploadingAvatar;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditProfile;
  final VoidCallback onShareProfile;
  final VoidCallback onViewAchievements;
  final VoidCallback onPremiumUpgrade;
  final VoidCallback onLearningReports;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeroCard(
            profile: profile,
            gradeName: selectedGrade?.name ?? profile.grade?.name,
            statistics: fullProfile.statistics,
            uploading: uploadingAvatar,
            onAvatarTap: onAvatarTap,
          ),
          const SizedBox(height: 16),
          _RankingCard(
            ranking: fullProfile.ranking,
            streakDays: fullProfile.statistics.currentStreak,
          ),
          const SizedBox(height: 22),

          const _SectionHeader(title: 'Achievements', actionLabel: 'View All'),
          const SizedBox(height: 12),
          _AchievementsRow(achievements: fullProfile.achievements),
          const SizedBox(height: 22),

          const _SectionHeader(title: 'Learning Analytics'),
          const SizedBox(height: 12),
          _LearningAnalyticsSection(
            statistics: fullProfile.statistics,
            weeklyProgress: fullProfile.weeklyProgress,
            strongestSubject: fullProfile.strongestSubject,
            aiImprovement: fullProfile.aiImprovement,
          ),
          const SizedBox(height: 22),

          const _SectionHeader(
            title: 'Subject Progress',
            actionLabel: 'View All Subjects',
          ),
          const SizedBox(height: 12),
          _SubjectProgressRow(subjects: fullProfile.subjects),
          const SizedBox(height: 22),

          const _SectionHeader(title: 'Battle Statistics'),
          const SizedBox(height: 12),
          const _BattleStatisticsCard(),
          const SizedBox(height: 24),

          _ProfileActions(
            onEditProfile: onEditProfile,
            onShareProfile: onShareProfile,
            onViewAchievements: onViewAchievements,
            onPremiumUpgrade: onPremiumUpgrade,
            onLearningReports: onLearningReports,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Glass card
// ------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _Palette.cardGlass.withValues(alpha: 0.82),
            border: Border.all(color: borderColor ?? _Palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: _Palette.neonViolet.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Section header
// ------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel})
    : onAction = null;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _Palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: _Palette.neonCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: _Palette.neonCyan,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Profile hero card
// ------------------------------------------------------------
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.gradeName,
    required this.statistics,
    required this.uploading,
    required this.onAvatarTap,
  });

  final ProfileModel profile;
  final String? gradeName;
  final ProfileStatistics statistics;
  final bool uploading;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;
          final avatar = _AvatarWithLevel(
            avatarUrl: profile.avatarUrl,
            name: profile.name,
            statistics: statistics,
            uploading: uploading,
            onTap: onAvatarTap,
          );
          final info = _ProfileInfoBlock(
            name: profile.name,
            school: profile.school,
            gradeName: gradeName,
            medium: profile.preferredMedium,
            targetExam: profile.targetExam,
            userCategory: profile.userCategory,
            district: profile.district,
            alStream: profile.alStream,
            gradeCategory: profile.gradeCategory,
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [avatar, const SizedBox(height: 16), info],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(child: info),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarWithLevel extends StatelessWidget {
  const _AvatarWithLevel({
    required this.avatarUrl,
    required this.name,
    required this.statistics,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final ProfileStatistics statistics;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: uploading ? null : onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 118,
                height: 118,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      _Palette.neonCyan,
                      _Palette.neonViolet,
                      _Palette.neonPink,
                      _Palette.neonCyan,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.neonViolet.withValues(alpha: 0.55),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: _Palette.neonCyan.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _Palette.bgMid,
                  ),
                  child: ClipOval(
                    child: uploading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _Palette.neonCyan,
                              strokeWidth: 2.5,
                            ),
                          )
                        : (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _AvatarInitial(name: name),
                          )
                        : _AvatarInitial(name: name),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: uploading
                        ? const LinearGradient(
                            colors: [Color(0xFF6B6B8A), Color(0xFF4E4E6A)],
                          )
                        : const LinearGradient(
                            colors: [_Palette.neonCyan, _Palette.neonViolet],
                          ),
                    shape: BoxShape.circle,
                    border: Border.all(color: _Palette.bgMid, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _Palette.neonViolet.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    uploading
                        ? Icons.hourglass_top_rounded
                        : Icons.edit_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LevelXpBadge(
          level: statistics.level,
          currentXp: statistics.xp,
          requiredXp: statistics.requiredXp,
        ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.neonViolet.withValues(alpha: 0.28),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LevelXpBadge extends StatelessWidget {
  const _LevelXpBadge({
    required this.level,
    required this.currentXp,
    required this.requiredXp,
  });
  final int level;
  final int currentXp;
  final int requiredXp;

  @override
  Widget build(BuildContext context) {
    final progress = requiredXp == 0
        ? 0.0
        : (currentXp / requiredXp).clamp(0.0, 1.0);
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_Palette.neonBlue, _Palette.neonViolet],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lv. $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: _Palette.cardGlassLight),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_Palette.neonCyan, _Palette.neonViolet],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatNum(currentXp)} / ${_formatNum(requiredXp)} XP',
            style: const TextStyle(
              color: _Palette.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _ProfileInfoBlock extends StatelessWidget {
  const _ProfileInfoBlock({
    required this.name,
    required this.school,
    required this.gradeName,
    required this.medium,
    this.targetExam,
    this.userCategory,
    this.district,
    this.alStream,
    this.gradeCategory,
  });

  final String name;
  final String? school;
  final String? gradeName;
  final String? medium;
  final String? targetExam;
  final String? userCategory;
  final String? district;
  final String? alStream;
  final String? gradeCategory;

  bool get _isGov =>
      (userCategory ?? '').trim().toLowerCase() == 'government exam candidate';

  @override
  Widget build(BuildContext context) {
    final streamLabel = AlStreamOption.labelFor(alStream);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: _Palette.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (_isGov)
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 14,
                color: _Palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  district ?? 'Sri Lanka',
                  style: const TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        else if (school != null && school!.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.location_city_rounded,
                size: 14,
                color: _Palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  school!,
                  style: const TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_isGov)
              _NeonChip(
                label: 'Government Exam Candidate',
                color: _Palette.neonGold,
              )
            else if (gradeName != null && gradeName!.isNotEmpty)
              _NeonChip(label: gradeName!, color: _Palette.neonViolet),
            // A/L stream chip
            if (streamLabel.isNotEmpty)
              _NeonChip(label: streamLabel, color: _Palette.neonPink),
            if (medium != null && medium!.isNotEmpty)
              _NeonChip(label: '$medium Medium', color: _Palette.neonCyan),
            if (targetExam != null && targetExam!.isNotEmpty)
              _NeonChip(label: targetExam!, color: _Palette.neonGold),
          ],
        ),
      ],
    );
  }
}

class _NeonChip extends StatelessWidget {
  const _NeonChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Ranking card
// ------------------------------------------------------------
class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.ranking, required this.streakDays});
  final ProfileRanking ranking;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _RankStat(
              icon: Icons.emoji_events_rounded,
              iconColor: _Palette.neonGold,
              label: 'National Rank',
              value: ranking.nationalRank > 0
                  ? '#${ranking.nationalRank}'
                  : '—',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _RankStat(
              icon: Icons.account_balance_rounded,
              iconColor: _Palette.neonCyan,
              label: 'School Rank',
              value: ranking.schoolRank > 0 ? '#${ranking.schoolRank}' : '—',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _RankStat(
              icon: Icons.local_fire_department_rounded,
              iconColor: _Palette.neonPink,
              label: 'Streak',
              value: '$streakDays Days',
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: _Palette.cardBorder);
  }
}

class _RankStat extends StatelessWidget {
  const _RankStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _Palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _Palette.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Achievements
// ------------------------------------------------------------
class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow({required this.achievements});
  final List<AchievementModel> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const _GlassCard(
        child: _EmptyRow(
          icon: Icons.emoji_events_outlined,
          text: 'No achievements yet',
        ),
      );
    }
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            _AchievementCard(achievement: achievements[i]),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});
  final AchievementModel achievement;

  Color _getColor() {
    if (achievement.color != null) {
      try {
        return Color(int.parse(achievement.color!.replaceFirst('#', '0xFF')));
      } catch (_) {
        return _Palette.neonGold;
      }
    }
    return _Palette.neonGold;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return SizedBox(
      width: 128,
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        borderColor: color.withValues(alpha: 0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(Icons.emoji_events_rounded, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Palette.textSecondary,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Learning analytics
// ------------------------------------------------------------
class _LearningAnalyticsSection extends StatelessWidget {
  const _LearningAnalyticsSection({
    required this.statistics,
    required this.weeklyProgress,
    required this.strongestSubject,
    required this.aiImprovement,
  });

  final ProfileStatistics statistics;
  final List<WeeklyProgressModel> weeklyProgress;
  final StrongestSubjectModel? strongestSubject;
  final AiImprovementModel? aiImprovement;

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final tiles = [
              _StatTile(
                icon: Icons.fact_check_rounded,
                color: _Palette.neonViolet,
                label: 'Quizzes Completed',
                value: '${statistics.completedQuizzes}',
              ),
              _StatTile(
                icon: Icons.track_changes_rounded,
                color: _Palette.neonPink,
                label: 'Average Accuracy',
                value: '${statistics.averageAccuracy.toStringAsFixed(1)}%',
              ),
              _StatTile(
                icon: Icons.schedule_rounded,
                color: _Palette.neonCyan,
                label: 'Time Spent Learning',
                value: _formatMinutes(statistics.timeSpentMinutes),
              ),
            ];
            if (isNarrow) {
              return Column(
                children: [
                  for (final t in tiles) ...[t, const SizedBox(height: 10)],
                ],
              );
            }
            return Row(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  Expanded(child: tiles[i]),
                  if (i != tiles.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _WeeklyProgressChart(data: weeklyProgress),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final strongest = _StrongestSubjectCard(subject: strongestSubject);
            final aiCard = _AiImprovementCard(improvement: aiImprovement);
            if (isNarrow) {
              return Column(
                children: [strongest, const SizedBox(height: 10), aiCard],
              );
            }
            return Row(
              children: [
                Expanded(child: strongest),
                const SizedBox(width: 10),
                Expanded(child: aiCard),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 11.5,
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

// ------------------------------------------------------------
// Weekly chart
// ------------------------------------------------------------
class _WeeklyProgressChart extends StatelessWidget {
  const _WeeklyProgressChart({required this.data});
  final List<WeeklyProgressModel> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _GlassCard(
        child: _EmptyRow(
          icon: Icons.show_chart_rounded,
          text: 'No weekly progress yet',
        ),
      );
    }

    final values = data.map((e) => e.value).toList();
    final latest = values.last;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Progress',
                style: TextStyle(
                  color: _Palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _Palette.neonCyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${latest.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: _Palette.neonCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(painter: _WeeklyProgressPainter(values: values)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final item in data)
                Text(
                  item.day,
                  style: const TextStyle(
                    color: _Palette.textMuted,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressPainter extends CustomPainter {
  _WeeklyProgressPainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = 100.0;
    final minVal = 0.0;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    Offset pointFor(int i) {
      final normalized = (values[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normalized.clamp(0.0, 1.0) * size.height);
      return Offset(stepX * i, y);
    }

    final gridPaint = Paint()
      ..color = _Palette.cardBorder
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = pointFor(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, size.height);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        final prev = pointFor(i - 1);
        final ctrl1 = Offset((prev.dx + p.dx) / 2, prev.dy);
        final ctrl2 = Offset((prev.dx + p.dx) / 2, p.dy);
        path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p.dx, p.dy);
        fillPath.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p.dx, p.dy);
      }
    }
    fillPath.lineTo(pointFor(values.length - 1).dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _Palette.neonCyan.withValues(alpha: 0.35),
          _Palette.neonCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [_Palette.neonCyan, _Palette.neonViolet],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = Colors.white;
    final dotGlow = Paint()..color = _Palette.neonCyan.withValues(alpha: 0.5);
    for (int i = 0; i < values.length; i++) {
      final p = pointFor(i);
      canvas.drawCircle(p, 6, dotGlow);
      canvas.drawCircle(p, 3.2, dotFill);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyProgressPainter oldDelegate) =>
      oldDelegate.values != values;
}

// ------------------------------------------------------------
// Strongest / AI
// ------------------------------------------------------------
class _StrongestSubjectCard extends StatelessWidget {
  const _StrongestSubjectCard({required this.subject});
  final StrongestSubjectModel? subject;

  @override
  Widget build(BuildContext context) {
    if (subject == null || subject!.name.isEmpty) {
      return const _GlassCard(
        child: _EmptyRow(
          icon: Icons.star_border_rounded,
          text: 'Not enough data yet',
        ),
      );
    }
    return _GlassCard(
      borderColor: _Palette.neonGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star_rounded, color: _Palette.neonGold, size: 18),
              SizedBox(width: 6),
              Text(
                'Strongest Subject',
                style: TextStyle(color: _Palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject!.name,
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${subject!.accuracy.toStringAsFixed(0)}% Accuracy',
            style: const TextStyle(
              color: _Palette.neonGold,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiImprovementCard extends StatelessWidget {
  const _AiImprovementCard({required this.improvement});
  final AiImprovementModel? improvement;

  @override
  Widget build(BuildContext context) {
    if (improvement == null) {
      return _GlassCard(
        borderColor: _Palette.neonViolet.withValues(alpha: 0.35),
        child: const _EmptyRow(
          icon: Icons.auto_awesome_rounded,
          text: 'AI Improvement — Coming Soon',
        ),
      );
    }
    return _GlassCard(
      borderColor: _Palette.neonViolet.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_Palette.neonCyan, _Palette.neonViolet],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Improvement',
                style: TextStyle(color: _Palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${improvement!.percentage >= 0 ? '+' : ''}'
            '${improvement!.percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Improvement this week',
            style: TextStyle(color: _Palette.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Subject progress
// ------------------------------------------------------------
class _SubjectProgressRow extends StatelessWidget {
  const _SubjectProgressRow({required this.subjects});
  final List<SubjectProgressModel> subjects;

  IconData _subjectIcon(String name) {
    switch (name.toLowerCase()) {
      case 'mathematics':
      case 'maths':
      case 'math':
        return Icons.functions_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'english':
        return Icons.menu_book_rounded;
      case 'ict':
      case 'information technology':
        return Icons.computer_rounded;
      case 'sinhala':
      case 'tamil':
        return Icons.language_rounded;
      default:
        return Icons.book_rounded;
    }
  }

  Color _subjectColor(String name) {
    switch (name.toLowerCase()) {
      case 'mathematics':
      case 'maths':
      case 'math':
        return _Palette.neonBlue;
      case 'science':
        return _Palette.neonCyan;
      case 'english':
        return _Palette.neonPink;
      case 'ict':
      case 'information technology':
        return _Palette.neonViolet;
      case 'sinhala':
        return _Palette.neonGold;
      case 'tamil':
        return _Palette.neonGreen;
      default:
        return _Palette.neonViolet;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return const _GlassCard(
        child: _EmptyRow(
          icon: Icons.menu_book_outlined,
          text: 'No subject progress yet',
        ),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final subject = subjects[i];
          return _SubjectCard(
            subject: subject,
            icon: _subjectIcon(subject.name),
            color: _subjectColor(subject.name),
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.icon,
    required this.color,
  });

  final SubjectProgressModel subject;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subject.name,
                    style: const TextStyle(
                      color: _Palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(56, 56),
                    painter: _RingPainter(
                      progress: subject.accuracy / 100,
                      color: color,
                    ),
                  ),
                  Text(
                    '${subject.accuracy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: _Palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${subject.xp} XP',
              style: const TextStyle(
                color: _Palette.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Rank #${subject.rank}',
              style: const TextStyle(color: _Palette.textMuted, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()
      ..color = _Palette.cardGlassLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ------------------------------------------------------------
// Battle statistics
// ------------------------------------------------------------
class _BattleStatisticsCard extends StatelessWidget {
  const _BattleStatisticsCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      borderColor: _Palette.neonBlue.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _Palette.neonBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  size: 18,
                  color: _Palette.neonBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Multiplayer battles are launching soon',
                  style: TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _Palette.neonBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: _Palette.neonBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Wins, win rate, fastest answer, multiplayer rank and tournament badges will show up here once battles go live.',
            style: TextStyle(
              color: _Palette.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Empty row
// ------------------------------------------------------------
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _Palette.textMuted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _Palette.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Profile action buttons
// ------------------------------------------------------------
class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onEditProfile,
    required this.onShareProfile,
    required this.onViewAchievements,
    required this.onPremiumUpgrade,
    required this.onLearningReports,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onShareProfile;
  final VoidCallback onViewAchievements;
  final VoidCallback onPremiumUpgrade;
  final VoidCallback onLearningReports;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionButton(
          label: 'Edit Profile',
          icon: Icons.person_outline_rounded,
          colors: const [_Palette.neonBlue, _Palette.neonViolet],
          onTap: onEditProfile,
        ),
        _ActionButton(
          label: 'Share Profile',
          icon: Icons.share_rounded,
          colors: const [_Palette.neonCyan, _Palette.neonBlue],
          onTap: onShareProfile,
        ),
        _ActionButton(
          label: 'View Achievements',
          icon: Icons.emoji_events_outlined,
          colors: const [_Palette.neonViolet, _Palette.neonPink],
          onTap: onViewAchievements,
        ),
        _ActionButton(
          label: 'Premium Upgrade',
          icon: Icons.workspace_premium_rounded,
          colors: const [_Palette.neonGold, Color(0xFFE0893D)],
          onTap: onPremiumUpgrade,
        ),
        _ActionButton(
          label: 'Learning Reports',
          icon: Icons.bar_chart_rounded,
          colors: const [_Palette.neonBlue, _Palette.neonCyan],
          onTap: onLearningReports,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = MediaQuery.of(context).size.width - 32;
        final width = (parentWidth - 10) / 2;
        return SizedBox(
          width: width.clamp(140, 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_Palette.neonViolet, _Palette.neonCyan],
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.neonViolet.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

// ------------------------------------------------------------
// Edit-profile form — new cascade: Category → Grade → Stream
// ------------------------------------------------------------
class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.nameController,
    required this.schoolController,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.grades,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.selectedStream,
    required this.onStreamChanged,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.selectedMedium,
    required this.onMediumChanged,
    required this.isGovCandidate,
  });

  final TextEditingController nameController;
  final TextEditingController schoolController;
  final List<CategoryModel> categories;
  final CategoryModel? selectedCategory;
  final ValueChanged<CategoryModel?> onCategoryChanged;
  final List<GradeModel> grades;
  final GradeModel? selectedGrade;
  final ValueChanged<GradeModel?> onGradeChanged;
  final String? selectedStream;
  final ValueChanged<String?> onStreamChanged;
  final String? selectedDistrict;
  final ValueChanged<String> onDistrictChanged;
  final String? selectedMedium;
  final ValueChanged<String> onMediumChanged;
  final bool isGovCandidate;

  @override
  Widget build(BuildContext context) {
    final showStream =
        !isGovCandidate &&
        selectedGrade != null &&
        selectedGrade!.isAdvancedLevel;

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          _FormField(
            label: 'Name',
            icon: Icons.person_outline_rounded,
            child: TextField(
              controller: nameController,
              cursorColor: _Palette.neonCyan,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: TextStyle(color: _Palette.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15, color: _Palette.textPrimary),
            ),
          ),

          if (!isGovCandidate) ...[
            const Divider(height: 1, color: _Palette.cardBorder),
            _FormField(
              label: 'Category',
              icon: Icons.category_outlined,
              child: _DarkDropdown<CategoryModel>(
                value: selectedCategory,
                hint: 'Select education category',
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.text)))
                    .toList(),
                onChanged: onCategoryChanged,
              ),
            ),
            const Divider(height: 1, color: _Palette.cardBorder),
            _FormField(
              label: 'Grade',
              icon: Icons.school_outlined,
              child: _DarkDropdown<GradeModel>(
                value: selectedGrade,
                hint: selectedCategory == null
                    ? 'Select category first'
                    : 'Select your grade',
                items: grades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: selectedCategory == null ? null : onGradeChanged,
              ),
            ),
            if (showStream) ...[
              const Divider(height: 1, color: _Palette.cardBorder),
              _FormField(
                label: 'Stream',
                icon: Icons.account_tree_outlined,
                child: _DarkDropdown<String>(
                  value: selectedStream,
                  hint: 'Select A/L stream',
                  items: AlStreamOption.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.value,
                          child: Text(s.text),
                        ),
                      )
                      .toList(),
                  onChanged: onStreamChanged,
                ),
              ),
            ],
            const Divider(height: 1, color: _Palette.cardBorder),
            _FormField(
              label: 'School',
              icon: Icons.business_outlined,
              child: TextField(
                controller: schoolController,
                cursorColor: _Palette.neonCyan,
                decoration: const InputDecoration(
                  hintText: 'Enter your school name',
                  hintStyle: TextStyle(color: _Palette.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: _Palette.textPrimary,
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: _Palette.cardBorder),
          _FormField(
            label: 'District',
            icon: Icons.location_city_outlined,
            child: _DarkDropdown<String>(
              value: selectedDistrict,
              hint: 'Select your district',
              items: ProfileService.districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (d) {
                if (d != null) onDistrictChanged(d);
              },
            ),
          ),

          if (!isGovCandidate) ...[
            const Divider(height: 1, color: _Palette.cardBorder),
            _FormField(
              label: 'Medium',
              icon: Icons.translate_rounded,
              child: _DarkDropdown<String>(
                value: selectedMedium,
                hint: 'Select your medium',
                items: ProfileService.mediums
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (m) {
                  if (m != null) onMediumChanged(m);
                },
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null || items.isEmpty;
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: _Palette.cardGlassLight,
        borderRadius: BorderRadius.circular(14),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _Palette.textSecondary,
        ),
        hint: Text(
          hint,
          style: const TextStyle(color: _Palette.textMuted, fontSize: 15),
        ),
        style: const TextStyle(color: _Palette.textPrimary, fontSize: 15),
        items: items,
        onChanged: disabled ? null : onChanged,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Palette.neonViolet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _Palette.neonViolet),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onSave});
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isSaving
                ? const [Color(0xFF4B4870), Color(0xFF4B4870)]
                : const [_Palette.neonViolet, _Palette.neonCyan],
          ),
          boxShadow: isSaving
              ? []
              : [
                  BoxShadow(
                    color: _Palette.neonViolet.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isSaving ? null : onSave,
            child: Center(
              child: isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
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
