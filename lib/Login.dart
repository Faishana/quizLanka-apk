// ignore_for_file: file_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Registre.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/forgot_password_screen.dart';
import 'package:quiz_lanka/main_navigation.dart';
import 'package:quiz_lanka/user_onboarding_screen.dart'
    show UserOnboardingScreen;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// USER MODEL
// ============================================================
class User {
  final int id;
  final String name;
  final String email;
  final String? userCategory;
  final int? gradeId;
  final String? school;
  final String? district;
  final String? alStream;
  final bool needsOnboarding;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.userCategory,
    this.gradeId,
    this.school,
    this.district,
    this.alStream,
    this.needsOnboarding = false,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      userCategory: json['user_category']?.toString(),
      gradeId: json['grade_id'] == null
          ? null
          : int.tryParse('${json['grade_id']}'),
      school: json['school']?.toString(),
      district: json['district']?.toString(),
      alStream: json['al_stream']?.toString(),

      // Important: support BOTH API response formats.
      // - Laravel returns `needs_onboarding` at the TOP level of the response.
      // - But once we save the user map and re-read it, we need the flag
      //   to survive round-tripping. Saving it inside `user` guarantees
      //   it persists in SharedPreferences.
      // - `user_category == null` is a safe fallback because a completed
      //   account always has a category.
      needsOnboarding:
          json['needs_onboarding'] == true || json['user_category'] == null,

      // Laravel `userPayload()` uses `profile_image`, not `avatar_url`.
      avatarUrl: json['profile_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'user_category': userCategory,
    'grade_id': gradeId,
    'school': school,
    'district': district,
    'al_stream': alStream,
    'needs_onboarding': needsOnboarding,
    'profile_image': avatarUrl,
  };
}

// ============================================================
// TOKEN STORAGE (+ remember-me & language preferences)
// ============================================================
class TokenStorage {
  TokenStorage._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _rememberKey = 'remember_me';
  static const String _rememberEmailKey = 'remember_email';
  static const String _langKey = 'app_lang';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> saveUser(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Remember-me stores ONLY the email (never the password).
  static Future<void> saveRemember(bool remember, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    if (remember) {
      await prefs.setString(_rememberEmailKey, email);
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }

  static Future<({bool remember, String email})> getRemember() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      remember: prefs.getBool(_rememberKey) ?? false,
      email: prefs.getString(_rememberEmailKey) ?? '',
    );
  }

  static Future<void> saveLang(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, code);
  }

  static Future<String> getLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) ?? 'en';
  }

  /// Clears the session only. Remember-me email and language are kept.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

// ============================================================
// AUTH SERVICE
// ============================================================
class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final http.Client _client = http.Client();

  static const Duration _timeout = Duration(seconds: 20);

  // Forgot-password endpoint is handled by ForgotPasswordScreen's own service.
  // Kept here only if you want a provider-level API; not used by LoginScreen.
  static const String _forgotPasswordPath = '/student/forgot-password';

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ── Helpers ─────────────────────────────────────────────────
  Map<String, dynamic> _decode(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _firstValidationError(Map<String, dynamic> data) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      return first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
    }
    return null;
  }

  String _friendlyError(Object e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your network.';
    }
    if (e is TimeoutException) {
      return 'The server took too long to respond. Please try again.';
    }
    if (e is http.ClientException) {
      return 'Could not reach the server. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── REGISTER ────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.register}';
      final requestBody = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      final response = await _client
          .post(
            Uri.parse(url),
            headers: _jsonHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('REGISTER STATUS: ${response.statusCode}');
      final data = _decode(response);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        await TokenStorage.saveToken(data['token']);

        // Merge the top-level `needs_onboarding` into the user map before
        // saving so the flag survives across app restarts.
        final userJson = Map<String, dynamic>.from(data['user'] ?? {});
        userJson['needs_onboarding'] =
            data['needs_onboarding'] == true ||
            userJson['user_category'] == null;

        await TokenStorage.saveUser(userJson);

        return {
          'success': true,
          'user': User.fromJson(userJson),
          'token': data['token'],
          'needs_onboarding': data['needs_onboarding'] == true,
        };
      }

      if (response.statusCode == 422) {
        final msg = _firstValidationError(data);
        if (msg != null) return {'success': false, 'message': msg};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e, s) {
      debugPrint('REGISTER ERROR: $e');
      debugPrint(s.toString());
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── LOGIN ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.login}';

      final response = await _client
          .post(
            Uri.parse(url),
            headers: _jsonHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      final data = _decode(response);

      if (response.statusCode == 200 && data['success'] == true) {
        await TokenStorage.saveToken(data['token']);

        // Merge the top-level `needs_onboarding` into the user map before
        // saving so the flag survives across app restarts.
        final userJson = Map<String, dynamic>.from(data['user'] ?? {});
        userJson['needs_onboarding'] =
            data['needs_onboarding'] == true ||
            userJson['user_category'] == null;

        await TokenStorage.saveUser(userJson);

        final user = User.fromJson(userJson);

        return {
          'success': true,
          'user': user,
          'token': data['token'],
          'needs_onboarding':
              data['needs_onboarding'] == true || user.needsOnboarding,
        };
      }

      if (response.statusCode == 422) {
        final msg = _firstValidationError(data);
        if (msg != null) return {'success': false, 'message': msg};
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': data['message'] ?? 'Incorrect email or password.',
        };
      }

      if (response.statusCode == 403) {
        return {
          'success': false,
          'message':
              data['message'] ??
              'This account cannot access the student application.',
        };
      }

      if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Too many attempts. Please wait a moment and try again.',
        };
      }

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── FORGOT PASSWORD ─────────────────────────────────────────
  // Kept for API completeness; LoginScreen no longer calls this directly.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$_forgotPasswordPath'),
            headers: _jsonHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);

      final data = _decode(response);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message':
              data['message'] ?? 'Password reset instructions have been sent.',
        };
      }
      if (response.statusCode == 422) {
        final msg = _firstValidationError(data);
        if (msg != null) return {'success': false, 'message': msg};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Could not send reset instructions.',
      };
    } catch (e) {
      debugPrint('FORGOT PASSWORD ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── COMPLETE ONBOARDING ─────────────────────────────────────
  Future<Map<String, dynamic>> completeOnboarding({
    required String userCategory,
    int? gradeId,
    String? school,
    String? district,
    String? alStream,
    String? preferredMedium,
    String? targetExam,
  }) async {
    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication token not found. Please login again.',
        };
      }

      final requestBody = <String, dynamic>{
        'user_category': userCategory,

        if (district != null && district.trim().isNotEmpty)
          'district': district.trim(),

        if (gradeId != null) 'grade_id': gradeId,

        if (school != null && school.trim().isNotEmpty) 'school': school.trim(),

        if (alStream != null && alStream.isNotEmpty) 'al_stream': alStream,

        if (preferredMedium != null && preferredMedium.isNotEmpty)
          'preferred_medium': preferredMedium,

        if (targetExam != null && targetExam.isNotEmpty)
          'target_exam': targetExam,
      };

      final url = '${ApiConfig.baseUrl}${ApiConfig.completeOnboarding}';

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('ONBOARDING STATUS: ${response.statusCode}');
      final data = _decode(response);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['user'] is Map) {
          final userJson = Map<String, dynamic>.from(data['user']);

          // Onboarding is complete — flag must be false from now on.
          userJson['needs_onboarding'] = false;

          await TokenStorage.saveUser(userJson);

          return {
            'success': true,
            'user': userJson,
            'message': data['message'] ?? 'Onboarding completed.',
          };
        }

        return {
          'success': true,
          'user': null,
          'message': data['message'] ?? 'Onboarding completed.',
        };
      }

      if (response.statusCode == 422) {
        final msg = _firstValidationError(data);
        if (msg != null) return {'success': false, 'message': msg};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Onboarding failed.',
      };
    } catch (e) {
      debugPrint('ONBOARDING ERROR: $e');
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── LOGOUT ──────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        await _client
            .post(
              Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(_timeout);
      }
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    } finally {
      await TokenStorage.clearAll();
    }
  }

  // ── FETCH PROFILE ───────────────────────────────────────────
  /// Returns the fresh user, or null. Sets [lastFetchUnauthorized] when the
  /// server says the saved token is no longer valid (HTTP 401).
  bool lastFetchUnauthorized = false;

  Future<User?> fetchProfile() async {
    lastFetchUnauthorized = false;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        lastFetchUnauthorized = true;
        return null;
      }

      if (response.statusCode == 200) {
        final data = _decode(response);
        if (data['user'] is Map) {
          final userJson = Map<String, dynamic>.from(data['user']);

          // Copy onboarding status from the top-level API response.
          userJson['needs_onboarding'] =
              data['needs_onboarding'] == true ||
              userJson['user_category'] == null;

          final user = User.fromJson(userJson);

          await TokenStorage.saveUser(user.toJson());

          return user;
        }
      }
      return null;
    } catch (e) {
      debugPrint('FETCH PROFILE ERROR: $e');
      return null;
    }
  }
}

// ============================================================
// AUTH PROVIDER
// ============================================================
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── INIT ────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        _user = null;
        return;
      }

      // Always get the latest user status from Laravel.
      final fresh = await _authService.fetchProfile();

      if (fresh != null) {
        _user = fresh;
      } else if (_authService.lastFetchUnauthorized) {
        // Token expired or revoked.
        await TokenStorage.clearAll();
        _user = null;
      } else {
        // Network/server error: retain cached user if available.
        final storedUser = await TokenStorage.getUser();

        if (storedUser != null) {
          _user = User.fromJson(storedUser);
        }
      }
    } catch (e) {
      debugPrint('AUTH INIT ERROR: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ── REGISTER ────────────────────────────────────────────────
  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        name,
        email,
        password,
        passwordConfirmation,
      );

      if (result['success'] == true) {
        _user = result['user'] as User?;
        return true;
      }
      _error = result['message'];
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── LOGIN ───────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result['success'] == true) {
        _user = result['user'] as User?;
        return true;
      }
      _error = result['message'];
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── FORGOT PASSWORD ─────────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String email) =>
      _authService.forgotPassword(email);

  // ── COMPLETE ONBOARDING ─────────────────────────────────────
  Future<bool> completeOnboarding({
    required String userCategory,
    int? gradeId,
    String? school,
    String? district,
    String? alStream,
    String? preferredMedium,
    String? targetExam,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.completeOnboarding(
        userCategory: userCategory,
        gradeId: gradeId,
        school: school,
        district: district,
        alStream: alStream,
        preferredMedium: preferredMedium,
        targetExam: targetExam,
      );

      if (result['success'] == true) {
        final userData = result['user'];
        if (userData is Map) {
          _user = User.fromJson(Map<String, dynamic>.from(userData));
        } else {
          final stored = await TokenStorage.getUser();
          if (stored != null) {
            _user = User.fromJson(stored);
          }
        }
        return true;
      }

      _error = result['message'];
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── LOGOUT ──────────────────────────────────────────────────
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

// ============================================================
// DESIGN TOKENS (Login UI) – educational navy + gold
// ============================================================
class _T {
  _T._();

  static const Color navy = Color(0xFF12306B);
  static const Color navyDeep = Color(0xFF0D2658);
  static const Color navyLight = Color(0xFF1B4296);
  static const Color gold = Color(0xFFF5B323);
  static const Color blue = Color(0xFF1E4FD8);
  static const Color ink = Color(0xFF12244A);
  static const Color muted = Color(0xFF4A5878);
  static const Color hint = Color(0xFF66718C);
  static const Color border = Color(0xFFC9D2E6);
  static const Color fieldFill = Color(0xFFF7F9FD);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerBg = Color(0xFFFDECEA);

  static const double fieldRadius = 14;
  static const double cardRadius = 28;
}

// ============================================================
// LOGIN TEXT (English / සිංහල / தமிழ்)
// ============================================================
class _L {
  _L._();

  static const Map<String, Map<String, String>> _t = {
    'en': {
      'welcome': 'Welcome',
      'headline': 'Practise smarter.\nPass with confidence.',
      'chip1': 'Grade 5 Scholarship',
      'chip2': 'O/L & A/L',
      'chip3': 'Government Exams',
      'title': 'Log in to your account',
      'subtitle': 'Continue your exam preparation journey.',
      'email': 'Email address',
      'emailHint': 'name@example.com',
      'password': 'Password',
      'passwordHint': 'Enter your password',
      'remember': 'Remember me',
      'forgot': 'Forgot password?',
      'login': 'Log in',
      'noAccount': 'New to QuizLanka? ',
      'register': 'Create an account',
      'enterEmail': 'Enter your email',
      'validEmail': 'Enter a valid email',
      'enterPassword': 'Enter your password',
      'minPassword': 'Minimum 8 characters',
      'show': 'Show password',
      'hide': 'Hide password',
    },
    'si': {
      'welcome': 'සාදරයෙන් පිළිගනිමු',
      'headline': 'දක්ෂව පුහුණු වන්න.\nවිශ්වාසයෙන් සමත් වන්න.',
      'chip1': '5 ශ්‍රේණි ශිෂ්‍යත්වය',
      'chip2': 'සා/පෙළ සහ උ/පෙළ',
      'chip3': 'රාජ්‍ය විභාග',
      'title': 'ඔබගේ ගිණුමට ඇතුල් වන්න',
      'subtitle': 'ඔබගේ විභාග සූදානම දිගටම කරගෙන යන්න.',
      'email': 'ඊමේල් ලිපිනය',
      'emailHint': 'name@example.com',
      'password': 'මුරපදය',
      'passwordHint': 'ඔබගේ මුරපදය ඇතුළත් කරන්න',
      'remember': 'මාව මතක තබාගන්න',
      'forgot': 'මුරපදය අමතකද?',
      'login': 'ඇතුල් වන්න',
      'noAccount': 'QuizLanka වලට අලුතෙන්ද? ',
      'register': 'ගිණුමක් සාදන්න',
      'enterEmail': 'ඊමේල් ලිපිනය ඇතුළත් කරන්න',
      'validEmail': 'වලංගු ඊමේල් ලිපිනයක් ඇතුළත් කරන්න',
      'enterPassword': 'මුරපදය ඇතුළත් කරන්න',
      'minPassword': 'අක්ෂර 8ක් අවශ්‍යයි',
      'show': 'මුරපදය පෙන්වන්න',
      'hide': 'මුරපදය සඟවන්න',
    },
    'ta': {
      'welcome': 'வரவேற்கிறோம்',
      'headline':
          'புத்திசாலித்தனமாகப் பயிலுங்கள்.\nநம்பிக்கையுடன் சித்தியடையுங்கள்.',
      'chip1': '5ஆம் தரப் புலமைப்பரிசில்',
      'chip2': 'சா/த & உ/த',
      'chip3': 'அரச பரீட்சைகள்',
      'title': 'உங்கள் கணக்கில் உள்நுழைக',
      'subtitle': 'உங்கள் பரீட்சைத் தயாரிப்பைத் தொடருங்கள்.',
      'email': 'மின்னஞ்சல் முகவரி',
      'emailHint': 'name@example.com',
      'password': 'கடவுச்சொல்',
      'passwordHint': 'கடவுச்சொல்லை உள்ளிடுக',
      'remember': 'என்னை நினைவில் கொள்',
      'forgot': 'கடவுச்சொல் மறந்துவிட்டதா?',
      'login': 'உள்நுழை',
      'noAccount': 'QuizLanka-வுக்குப் புதியவரா? ',
      'register': 'கணக்கை உருவாக்கு',
      'enterEmail': 'மின்னஞ்சலை உள்ளிடுக',
      'validEmail': 'சரியான மின்னஞ்சலை உள்ளிடுக',
      'enterPassword': 'கடவுச்சொல்லை உள்ளிடுக',
      'minPassword': 'குறைந்தது 8 எழுத்துகள்',
      'show': 'கடவுச்சொல்லைக் காட்டு',
      'hide': 'கடவுச்சொல்லை மறை',
    },
  };

  static String get(String lang, String key) =>
      _t[lang]?[key] ?? _t['en']![key] ?? key;
}

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _disposed = false;
  String _lang = 'en';
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;

  String _s(String key) => _L.get(_lang, key);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _cardSlide = Tween<double>(begin: 32, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _cardFade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final remember = await TokenStorage.getRemember();
    final lang = await TokenStorage.getLang();
    if (!mounted || _disposed) return;
    setState(() {
      _rememberMe = remember.remember;
      _lang = lang;
      if (remember.remember && remember.email.isNotEmpty) {
        _emailController.text = remember.email;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Safe setState — never touches a disposed State.
  void _safeSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  Future<void> _setLang(String code) async {
    if (code == _lang) return;
    _safeSetState(() => _lang = code);
    await TokenStorage.saveLang(code);
  }

  // ── HANDLE LOGIN ────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (_isLoading || _disposed) return;

    FocusScope.of(context).unfocus();
    _safeSetState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    _safeSetState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    // Capture text BEFORE await — never touch the controller after.
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await auth.login(email, password);

    if (_disposed || !mounted) return;

    if (success) {
      await TokenStorage.saveRemember(_rememberMe, email);
      if (_disposed || !mounted) return;

      _safeSetState(() => _isLoading = false);
      HapticFeedback.lightImpact();
      _goToNextScreen();
    } else {
      HapticFeedback.mediumImpact();
      _safeSetState(() {
        _isLoading = false;
        _errorMessage = auth.error ?? 'Login failed. Please try again.';
      });
    }
  }

  void _goToNextScreen() {
    if (_disposed || !mounted) return;

    final auth = context.read<AuthProvider>();

    // Route to onboarding if either:
    // - API says needs_onboarding is true, OR
    // - The user has no category yet (defensive fallback).
    final needsOnboarding =
        (auth.user?.needsOnboarding ?? false) ||
        (auth.user?.userCategory == null);

    final Widget next = needsOnboarding
        ? const UserOnboardingScreen()
        : const MainNavigation();

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  // ── FORGOT PASSWORD ─────────────────────────────────────────
  // Simply navigate to the dedicated ForgotPasswordScreen. No email is sent
  // from this screen. The email typed on login is passed as initialEmail so
  // the user does not have to retype it.
  void _goToForgotPassword() {
    if (_disposed || !mounted) return;

    final email = _emailController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: email.isEmpty ? null : email),
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: _T.navy,
        body: Stack(
          children: [
            const Positioned.fill(child: _EducationBackdrop()),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (_, child) => Opacity(
                            opacity: _cardFade.value,
                            child: Transform.translate(
                              offset: Offset(0, _cardSlide.value),
                              child: child,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              Expanded(child: _buildFormCard()),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _BrandMark(),
              _LanguageSwitch(current: _lang, onChanged: _setLang),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _s('welcome'),
            style: const TextStyle(
              color: _T.gold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _s('headline'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: _s('chip1')),
              _Chip(label: _s('chip2')),
              _Chip(label: _s('chip3')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_T.cardRadius),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _s('title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _T.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _s('subtitle'),
              style: const TextStyle(fontSize: 14, color: _T.muted),
            ),
            const SizedBox(height: 22),
            if (_errorMessage != null) ...[
              _ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 14),
            ],
            _FieldLabel(_s('email')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              style: _inputStyle,
              cursorColor: _T.blue,
              decoration: _fieldDecoration(
                hint: _s('emailHint'),
                icon: Icons.mail_outline_rounded,
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return _s('enterEmail');
                if (!_emailRegex.hasMatch(value)) return _s('validEmail');
                return null;
              },
            ),
            const SizedBox(height: 16),
            _FieldLabel(_s('password')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _handleLogin(),
              style: _inputStyle,
              cursorColor: _T.blue,
              decoration: _fieldDecoration(
                hint: _s('passwordHint'),
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscurePassword ? _s('show') : _s('hide'),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _T.muted,
                    size: 20,
                  ),
                  onPressed: () =>
                      _safeSetState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return _s('enterPassword');
                if (v.length < 8) return _s('minPassword');
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _safeSetState(() => _rememberMe = !_rememberMe),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _rememberMe ? _T.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _rememberMe ? _T.blue : _T.hint,
                              width: 1.6,
                            ),
                          ),
                          child: _rememberMe
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _s('remember'),
                          style: const TextStyle(fontSize: 13, color: _T.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _goToForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _T.blue,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    _s('forgot'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: _s('login'),
              isLoading: _isLoading,
              onTap: _handleLogin,
            ),
            const Spacer(),
            const SizedBox(height: 20),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: _T.muted),
                  children: [
                    TextSpan(text: _s('noAccount')),
                    TextSpan(
                      text: _s('register'),
                      style: const TextStyle(
                        color: _T.blue,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (_disposed || !mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
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
// SHARED INPUT STYLE
// ============================================================
const TextStyle _inputStyle = TextStyle(
  fontSize: 15,
  color: _T.ink,
  fontWeight: FontWeight.w500,
);

InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
  String? errorText,
}) {
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(_T.fieldRadius),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _T.hint, fontSize: 14.5),
    prefixIcon: Icon(icon, color: _T.muted, size: 20),
    suffixIcon: suffix,
    errorText: errorText,
    errorStyle: const TextStyle(
      color: _T.danger,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: _T.fieldFill,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: border(_T.border, 1.5),
    focusedBorder: border(_T.blue, 2),
    errorBorder: border(_T.danger, 1.5),
    focusedErrorBorder: border(_T.danger, 2),
  );
}

// ============================================================
// PRIVATE WIDGETS
// ============================================================

/// Pure-Flutter backdrop: fills the whole screen (no asset needed).
class _EducationBackdrop extends StatelessWidget {
  const _EducationBackdrop();

  Widget _icon(IconData i, double size, double alpha) => Icon(
    i,
    size: size,
    color: Colors.white.withValues(alpha: alpha),
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_T.navy, _T.navyDeep],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                color: _T.navyLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: -90,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: _T.navyLight.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: 28,
            child: _icon(Icons.menu_book_rounded, 44, 0.10),
          ),
          Positioned(
            top: 250,
            right: 70,
            child: _icon(Icons.calculate_rounded, 34, 0.08),
          ),
          Positioned(
            top: 205,
            left: 24,
            child: _icon(Icons.science_rounded, 30, 0.08),
          ),
          Positioned(
            top: 60,
            left: 150,
            child: _icon(Icons.public_rounded, 28, 0.07),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _T.gold,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, color: _T.navy, size: 26),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
            children: [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(color: _T.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String code, String label, String semantic) {
      final selected = current == code;
      return Semantics(
        button: true,
        selected: selected,
        label: semantic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? _T.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? _T.navy : const Color(0xFFDCE6FF),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _T.navyDeep,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('si', 'සිං', 'Sinhala'),
          item('ta', 'த', 'Tamil'),
          item('en', 'EN', 'English'),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _T.navyLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _T.ink,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _T.dangerBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: _T.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _T.danger,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: isLoading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _T.blue,
          disabledBackgroundColor: _T.blue.withValues(alpha: 0.75),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_T.fieldRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}
