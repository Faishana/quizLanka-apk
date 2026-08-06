// lib/config/api_config.dart
// QuizLanka AI — Central API configuration

class ApiConfig {
  // Android Emulator : http://10.0.2.2:8000/api
  // Chrome/Web       : http://127.0.0.1:8000/api
  // Physical Device  : http://192.168.x.x:8000/api

  //static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String baseUrl = 'https://quizlanka.lk/api';

  // ============================
  // Authentication
  // ============================

  static const String login = '/student/login';
  static const String register = '/student/register';
  static const String logout = '/student/logout';
  static const String me = '/student/me';

  // ============================
  // Public
  // ============================

  static const String grades = '/public/grades';

  // ============================
  // Dashboard
  // ============================

  static const String dashboard = '/dashboard';

  // ============================
  // Subjects
  // ============================

  static const String subjects = '/subjects';

  // ============================
  // Quiz
  // ============================

  static const String quizStart = '/quiz/start';
  static const String quizSubmit = '/quiz/submit';
  static const String quizHistory = '/quiz/history';

  static String quizResult(int quizId) => '/quiz/$quizId/result';

  static String quizReview(int quizId) => '/quiz/$quizId/review';

  // ============================
  // Leadborqoard
  // ============================

  static const String leaderboard = '/leaderboard';

  // ============================
  // Materials
  // ============================

  static const String materials = '/materials';

  static String materialBySubject(int subjectId) =>
      '/subjects/$subjectId/materials';

  static String materialDetails(int materialId) => '/materials/$materialId';

  // ============================
  // Profile
  // ============================

  static const String profilePhoto = '/profile/photo';

  // ============================
  // Headers
  // ============================

  static Map<String, String> getHeaders(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================
  // Helpers
  // ============================

  /// Builds a full [Uri] for a given API path, e.g. ApiConfig.uri(ApiConfig.dashboard)
  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  // ============================
  // App
  // ============================

  static const String appName = 'QuizLanka';
  static const String version = '1.0.0';
}
