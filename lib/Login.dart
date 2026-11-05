// ignore_for_file: file_names

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Registre.dart';
import 'package:quiz_lanka/config/api_config.dart';
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
      needsOnboarding: json['needs_onboarding'] == true,
      avatarUrl: json['avatar_url']?.toString(),
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
    'avatar_url': avatarUrl,
  };
}

// ============================================================
// TOKEN STORAGE
// ============================================================
class TokenStorage {
  TokenStorage._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // CHECK TOKEN
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

      debugPrint('REGISTER URL: $url');
      debugPrint('REQUEST BODY: ${jsonEncode(requestBody)}');

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        await TokenStorage.saveToken(data['token']);
        await TokenStorage.saveUser(Map<String, dynamic>.from(data['user']));

        return {
          'success': true,
          'user': User.fromJson(Map<String, dynamic>.from(data['user'])),
          'token': data['token'],
          'needs_onboarding': data['needs_onboarding'] == true,
        };
      }

      if (response.statusCode == 422) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;
          final message = firstError is List && firstError.isNotEmpty
              ? firstError.first.toString()
              : firstError.toString();
          return {'success': false, 'message': message};
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e, s) {
      debugPrint('REGISTER ERROR: $e');
      debugPrint(s.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── LOGIN ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.login}';

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN RESPONSE: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await TokenStorage.saveToken(data['token']);
        await TokenStorage.saveUser(Map<String, dynamic>.from(data['user']));

        final user = User.fromJson(Map<String, dynamic>.from(data['user']));

        return {
          'success': true,
          'user': user,
          'token': data['token'],
          'needs_onboarding':
              data['needs_onboarding'] == true || user.needsOnboarding,
        };
      }

      if (response.statusCode == 422) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;
          final message = firstError is List && firstError.isNotEmpty
              ? firstError.first.toString()
              : firstError.toString();
          return {'success': false, 'message': message};
        }
      }

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── COMPLETE ONBOARDING ─────────────────────────────────────
  Future<Map<String, dynamic>> completeOnboarding({
    required String userCategory,
    int? gradeId,
    String? school,
    required String district,
    String? alStream,
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
        'district': district,
        if (gradeId != null) 'grade_id': gradeId,
        if (school != null && school.trim().isNotEmpty) 'school': school.trim(),
        if (alStream != null && alStream.isNotEmpty) 'al_stream': alStream,
      };

      final url = '${ApiConfig.baseUrl}${ApiConfig.completeOnboarding}';

      debugPrint('ONBOARDING URL: $url');
      debugPrint('ONBOARDING BODY: ${jsonEncode(requestBody)}');

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('ONBOARDING STATUS: ${response.statusCode}');
      debugPrint('ONBOARDING RESPONSE: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['user'] is Map) {
          await TokenStorage.saveUser(Map<String, dynamic>.from(data['user']));
        }
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'] ?? 'Onboarding completed.',
        };
      }

      if (response.statusCode == 422) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;
          final message = firstError is List && firstError.isNotEmpty
              ? firstError.first.toString()
              : firstError.toString();
          return {'success': false, 'message': message};
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Onboarding failed.',
      };
    } catch (e) {
      debugPrint('ONBOARDING ERROR: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── LOGOUT ──────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        await _client.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    } finally {
      await TokenStorage.clearAll();
    }
  }

  // ── FETCH PROFILE ───────────────────────────────────────────
  Future<User?> fetchProfile() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] is Map) {
          final user = User.fromJson(Map<String, dynamic>.from(data['user']));
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
    final storedUser = await TokenStorage.getUser();
    if (storedUser != null) {
      _user = User.fromJson(storedUser);
    }
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final fresh = await _authService.fetchProfile();
      if (fresh != null) _user = fresh;
    }
    _isInitialized = true;
    notifyListeners();
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
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── COMPLETE ONBOARDING ─────────────────────────────────────
  Future<bool> completeOnboarding({
    required String userCategory,
    int? gradeId,
    String? school,
    required String district,
    String? alStream,
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
      );

      if (result['success'] == true) {
        final userData = result['user'];
        if (userData is Map) {
          _user = User.fromJson(Map<String, dynamic>.from(userData));
        } else {
          // Fallback: reload from storage in case response lacks user
          final stored = await TokenStorage.getUser();
          if (stored != null) {
            _user = User.fromJson(stored);
          }
        }
        notifyListeners();
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
// DESIGN TOKENS (Login UI)
// ============================================================
class _LoginTokens {
  _LoginTokens._();

  static const List<Color> backgroundGradient = [
    Color(0xFF0B0B22),
    Color(0xFF141335),
    Color(0xFF1D1B4B),
  ];

  static const Color violet = Color(0xFF9B7BFF);
  static const Color cyan = Color(0xFF4FC3FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD6D3F0);
  static const Color danger = Color(0xFFFF8A8A);

  static const double fieldRadius = 16;
  static const double cardRadius = 28;
}

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

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  late AnimationController _animController;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _cardFade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── HANDLE LOGIN ────────────────────────────────────────────
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();

      final success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        _goToNextScreen();
      } else if (mounted) {
        final err = context.read<AuthProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Login failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _goToNextScreen() {
    final auth = context.read<AuthProvider>();

    if (auth.user?.needsOnboarding == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserOnboardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _LoginTokens.backgroundGradient.first,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _LoginTokens.backgroundGradient,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  children: [
                    const SizedBox(height: 24),
                    const _BrandMark(),
                    const SizedBox(height: 32),
                    _buildFormCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_LoginTokens.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1740).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(_LoginTokens.cardRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _LoginTokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Login to continue your learning journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _LoginTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                _GlassTextField(
                  controller: _emailController,
                  hint: 'Email Address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _GlassTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _LoginTokens.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Enter your password';
                    }
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildRememberMe(),
                const SizedBox(height: 22),
                _GradientButton(
                  label: 'Login',
                  isLoading: _isLoading,
                  onTap: _handleLogin,
                ),
                const SizedBox(height: 18),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: _LoginTokens.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Register',
                          style: const TextStyle(
                            color: _LoginTokens.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _rememberMe ? _LoginTokens.violet : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _rememberMe
                        ? _LoginTokens.violet
                        : _LoginTokens.textSecondary,
                    width: 1.4,
                  ),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember me',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _LoginTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 12.5,
              color: _LoginTokens.cyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PRIVATE WIDGETS
// ============================================================

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_LoginTokens.violet, _LoginTokens.cyan],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _LoginTokens.violet.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(
                  color: _LoginTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(
                  color: _LoginTokens.violet,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 15,
        color: _LoginTokens.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      cursorColor: _LoginTokens.violet,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFC9C6E8),
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: _LoginTokens.textSecondary, size: 20),
        suffixIcon: suffix,
        errorStyle: const TextStyle(
          color: _LoginTokens.danger,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_LoginTokens.fieldRadius),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_LoginTokens.fieldRadius),
          borderSide: const BorderSide(color: _LoginTokens.violet, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_LoginTokens.fieldRadius),
          borderSide: BorderSide(
            color: _LoginTokens.danger.withValues(alpha: 0.7),
            width: 1.3,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_LoginTokens.fieldRadius),
          borderSide: const BorderSide(color: _LoginTokens.danger, width: 1.8),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [_LoginTokens.violet, _LoginTokens.cyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
          borderRadius: BorderRadius.circular(27),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _LoginTokens.violet.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Center(
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
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : _LoginTokens.textSecondary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: enabled
                          ? Colors.white
                          : _LoginTokens.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
