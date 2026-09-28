// lib/forgot_password_screen.dart
// QuizLanka AI — Forgot Password (Step 1: Request OTP)
// Light "Aurora" theme with soft blue shadows.
// Self-contained: palette + service + UI in one file.
//
// BACKEND ROUTES:
//   POST /forgot-password   body: { "email": "..." }
//   success response:  { "success": true, "message": "OTP sent to your email", "email": "..." }
//   error response:    { "success": false, "message": "..." }
//   OR Laravel validation: { "errors": { "email": ["..."] } } (422)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/verify_otp_screen.dart';

// ─────────────────────────────────────────────
// LIGHT THEME PALETTE (local to this screen)
// ─────────────────────────────────────────────
class _LightTheme {
  static const List<Color> backgroundGradient = [
    Color(0xFFFAFBFF),
    Color(0xFFEAF0FF),
  ];

  static const Color primaryBlue = Color(0xFF3D5CFF);
  static const Color accentCyan = Color(0xFF2FB6C9);
  static const Color danger = Color(0xFFE05A5A);

  static const Color textPrimary = Color(0xFF1B2440);
  static const Color textSecondary = Color(0xFF6B7A99);

  static const Color surface = Colors.white;
  static const Color border = Color(0xFFDCE4FF);

  static List<BoxShadow> blueShadow({
    double blur = 24,
    Offset offset = const Offset(0, 10),
    double opacity = 0.16,
  }) {
    return [
      BoxShadow(
        color: primaryBlue.withValues(alpha: opacity),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  static BoxDecoration card({double radius = 20}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: blueShadow(),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE - Enhanced with better error handling
// ─────────────────────────────────────────────
class _ForgotPasswordService {
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/student/forgot-password');

    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // Add Authorization header if needed
              // 'Authorization': 'Bearer ${ApiConfig.apiToken}',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};

      // Log for debugging (remove in production)
      debugPrint(
        'Forgot Password Response: Status ${res.statusCode}, Body: $body',
      );

      // Handle success (200, 201)
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Check if the response has a success field (Laravel convention)
        if (body['success'] == false) {
          return {
            'ok': false,
            'message': body['message'] ?? 'Failed to send OTP',
          };
        }

        return {
          'ok': true,
          'message': body['message'] ?? 'OTP sent to your email',
          'email': body['email'] ?? email,
        };
      }

      // Handle validation errors (422)
      if (res.statusCode == 422) {
        // Laravel validation error format
        if (body.containsKey('errors')) {
          final errors = body['errors'] as Map<String, dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            // Get first error message from any field
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              return {'ok': false, 'message': firstError.first.toString()};
            }
            if (firstError is String) {
              return {'ok': false, 'message': firstError};
            }
          }
        }

        // Alternative error format
        return {
          'ok': false,
          'message': body['message'] ?? 'Please check the email you entered.',
        };
      }

      // Handle other status codes
      return {
        'ok': false,
        'message':
            body['message'] ?? 'Something went wrong (${res.statusCode}).',
      };
    } on http.ClientException {
      return {
        'ok': false,
        'message':
            'Unable to connect to server. Please check your internet connection.',
      };
    } on FormatException {
      return {
        'ok': false,
        'message': 'Invalid response from server. Please try again.',
      };
    } catch (e) {
      debugPrint('Forgot Password Error: $e');
      return {
        'ok': false,
        'message': 'Network error. Please check your connection and try again.',
      };
    }
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _service = _ForgotPasswordService();

  bool _loading = false;
  String? _errorText;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear previous messages
    setState(() {
      _errorText = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();
    final result = await _service.sendOtp(email);

    if (!mounted) return;

    setState(() => _loading = false);

    if (result['ok'] == true) {
      // Show success message
      setState(() {
        _successMessage = result['message'] as String;
      });

      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: _LightTheme.primaryBlue,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to OTP verification screen
      final emailToSend = result['email'] as String? ?? email;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: emailToSend)),
      );
    } else {
      setState(() => _errorText = result['message'] as String);

      // Also show snackbar for errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: _LightTheme.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email address';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LightTheme.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _LightTheme.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(
                    onTap: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 24),
                  _IllustrationBadge(
                    icon: Icons.lock_reset_rounded,
                    color: _LightTheme.primaryBlue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _LightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No worries. Enter the email linked to your account "
                    "and we'll send you a 6-digit code to reset your password.",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _LightTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Email address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _LightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AuthTextField(
                    controller: _emailController,
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    onChanged: (_) {
                      if (_errorText != null || _successMessage != null) {
                        setState(() {
                          _errorText = null;
                          _successMessage = null;
                        });
                      }
                    },
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBanner(message: _errorText!),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 10),
                    _SuccessBanner(message: _successMessage!),
                  ],
                  const SizedBox(height: 28),
                  _PrimaryButton(
                    label: 'Send OTP',
                    loading: _loading,
                    onTap: _submit,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          color: _LightTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
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
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _LightTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LightTheme.border),
          boxShadow: _LightTheme.blueShadow(
            blur: 10,
            offset: const Offset(0, 3),
            opacity: 0.12,
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: _LightTheme.primaryBlue,
        ),
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IllustrationBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: _LightTheme.blueShadow(
          blur: 20,
          offset: const Offset(0, 8),
          opacity: 0.18,
        ),
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _LightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LightTheme.border),
        boxShadow: _LightTheme.blueShadow(
          blur: 14,
          offset: const Offset(0, 5),
          opacity: 0.08,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(
          color: _LightTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _LightTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: _LightTheme.primaryBlue, size: 20),
          suffixIcon: suffix,
          filled: false,
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 4,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _LightTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LightTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _LightTheme.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _LightTheme.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _LightTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _LightTheme.primaryBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: _LightTheme.primaryBlue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _LightTheme.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_LightTheme.primaryBlue, _LightTheme.accentCyan],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _LightTheme.blueShadow(
            blur: 20,
            offset: const Offset(0, 8),
            opacity: 0.32,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
      ),
    );
  }
}
