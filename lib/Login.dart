// ignore_for_file: file_names

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Registre.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/forgot_password_screen.dart';
import 'package:quiz_lanka/main_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// TOKEN STORAGE — unchanged
// ============================================================
class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString != null) {
      try {
        return jsonDecode(userString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

// ============================================================
// USER MODEL — unchanged
// ============================================================
class User {
  final int? id;
  final String? name;
  final String? email;
  final int? gradeId;
  final String? school;
  final String? district;
  final String? role;

  User({
    this.id,
    this.name,
    this.email,
    this.gradeId,
    this.school,
    this.district,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      gradeId: json['grade_id'],
      school: json['school'],
      district: json['district'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'grade_id': gradeId,
      'school': school,
      'district': district,
      'role': role,
    };
  }
}

// ============================================================
// AUTH SERVICE — unchanged
// ============================================================
class AuthService {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await TokenStorage.saveToken(data['token']);
        await TokenStorage.saveUser(data['user']);
        final user = User.fromJson(data['user']);
        return {'success': true, 'user': user, 'token': data['token']};
      } else if (response.statusCode == 422) {
        final errors = data['errors'] ?? {};
        String errorMessage = 'Validation failed';
        if (errors.isNotEmpty) {
          errorMessage = errors.values.first.first;
        }
        return {'success': false, 'message': errorMessage};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    int gradeId,
    String school,
    String district,
  ) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.register}';

      final requestBody = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'grade_id': gradeId,
        'school': school,
        'district': district,
      };

      debugPrint('==============================');
      debugPrint('REGISTER URL : $url');
      debugPrint('REQUEST BODY : ${jsonEncode(requestBody)}');

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('STATUS CODE : ${response.statusCode}');
      debugPrint('RESPONSE : ${response.body}');
      debugPrint('==============================');

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        await TokenStorage.saveToken(data['token']);
        await TokenStorage.saveUser(data['user']);

        return {
          'success': true,
          'user': User.fromJson(data['user']),
          'token': data['token'],
        };
      }

      if (response.statusCode == 422) {
        final errors = data['errors'];

        if (errors != null && errors.isNotEmpty) {
          return {'success': false, 'message': errors.values.first.first};
        }

        return {
          'success': false,
          'message': data['message'] ?? 'Validation failed',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e, s) {
      debugPrint("REGISTER ERROR : $e");
      debugPrint(s.toString());

      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final userData = await TokenStorage.getUser();
      if (userData != null) {
        return {'success': true, 'user': User.fromJson(userData)};
      }

      return {'success': false, 'message': 'No user data found'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<void> logout() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null) {
        await _client.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
          headers: ApiConfig.getHeaders(token),
        );
      }
    } catch (e) {
      // Ignore network errors on logout
    } finally {
      await TokenStorage.clearAll();
    }
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// AUTH PROVIDER — unchanged
// ============================================================
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result['success']) {
        _user = result['user'];
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

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    int gradeId,
    String school,
    String district,
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
        gradeId,
        school,
        district,
      );

      if (result['success']) {
        _user = result['user'];
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

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.getCurrentUser();

      if (result['success']) {
        _user = result['user'];
      } else {
        _user = null;
      }
    } catch (_) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();

    _user = null;
    _isLoading = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

// ============================================================
// DESIGN TOKENS — "Aurora Glass" theme (contrast-tuned)
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
  // Brighter secondary so copy stays legible over busy artwork.
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
  bool _rememberMe = true;
  bool _isCheckingAuth = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkAuthStatus();

      if (mounted && auth.isAuthenticated) {
        _goToDashboard();
        return;
      }

      setState(() => _isCheckingAuth = false);
      _animController.forward();
    });
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    // Only start showing field-level red errors once the user has
    // actually tried to submit — not on first render.
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    if (!_formKey.currentState!.validate()) return;
    auth.clearError();

    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) _goToDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _LoginTokens.backgroundGradient.first,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (_isCheckingAuth) {
            return const _LoadingScreen();
          }

          return Stack(
            children: [
              // 1. Background artwork
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

              // 2. Darkening scrim — stronger top & bottom, lighter
              // in the middle, so text stays legible over busy art
              // without hiding the illustration completely.
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

              // 3. Safe area & form
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
                        const SizedBox(height: 28),
                        const _BrandMark(),
                        const SizedBox(height: 32),
                        _buildFormCard(auth),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── form card ──────────────────────────────────────────────
  Widget _buildFormCard(AuthProvider auth) {
    // Real glassmorphism: blur what's behind the card, then lay a
    // semi-opaque tint on top so the card reads as a solid, legible
    // surface instead of a washed-out see-through rectangle.
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
            autovalidateMode: _autovalidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome Back!',
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
                  'Login to continue your AI learning journey.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _LoginTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),

                if (auth.error != null)
                  _ErrorBanner(
                    message: auth.error!,
                    onDismiss: auth.clearError,
                  ),

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
                const SizedBox(height: 14),

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
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _rememberMe
                                  ? _LoginTokens.violet
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: _rememberMe
                                    ? _LoginTokens.violet
                                    : _LoginTokens.textSecondary,
                                width: 1.5,
                              ),
                            ),
                            child: _rememberMe
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 13,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 13,
                              color: _LoginTokens.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 13,
                          color: _LoginTokens.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                _GradientButton(
                  label: 'Login',
                  isLoading: auth.isLoading,
                  onTap: () => _handleLogin(auth),
                ),
                const SizedBox(height: 20),

                _GlassActionTile(
                  icon: Icons.person_add_outlined,
                  title: 'Create New Account',
                  subtitle: 'Join QuizLanka AI today!',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                ),
                const SizedBox(height: 20),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _LoginTokens.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to our '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: _LoginTokens.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: _LoginTokens.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: _LoginTokens.violet.withValues(alpha: 0.95),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Your data is secure with us',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _LoginTokens.violet.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
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
}

// ============================================================
// PRIVATE, REUSABLE WIDGETS
// ============================================================

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: _LoginTokens.backgroundGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

/// Logo mark + wordmark shown above the form card. Given its own
/// soft dark backing so it stays legible over busy artwork too.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [_LoginTokens.violet, _LoginTokens.cyan],
            ),
            boxShadow: [
              BoxShadow(
                color: _LoginTokens.violet.withValues(alpha: 0.5),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(
                  color: _LoginTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
                ),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(
                  color: _LoginTokens.violet,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Learn Smart. Rank Higher.',
          style: TextStyle(
            color: _LoginTokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _LoginTokens.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LoginTokens.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _LoginTokens.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _LoginTokens.danger,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              color: _LoginTokens.danger.withValues(alpha: 0.8),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass-style text field, tuned for readability: solid-enough fill,
/// bright hint text, and a clearly visible caret/border on focus.
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
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_LoginTokens.violet, _LoginTokens.cyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: _LoginTokens.violet.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            else ...[
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassActionTile extends StatelessWidget {
  const _GlassActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _LoginTokens.violet.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: _LoginTokens.violet, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _LoginTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _LoginTokens.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: _LoginTokens.textSecondary.withValues(alpha: 0.85),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
