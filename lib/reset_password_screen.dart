// lib/reset_password_screen.dart
// QuizLanka AI — Forgot Password (Step 3: Set New Password)
// Light "Aurora" theme with soft blue shadows.
// Self-contained: palette + service + UI in one file.
//
// BACKEND ASSUMPTION (adjust if your controller differs):
//   POST /reset-password
//   body: {
//     "email": "...",
//     "otp": "123456",
//     "password": "...",
//     "password_confirmation": "..."
//   }
//   success response: { "success": true, "message": "Password reset successful" }
//   error response:   { "success": false, "message": "..." } OR
//                      { "errors": { "password": ["..."] } } (Laravel 422 validation)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/config/api_config.dart';

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
  static const Color success = Color(0xFF2FB380);
  static const Color warning = Color(0xFFE0A23B);
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
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class _ResetPasswordService {
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/student/reset-password');
    try {
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'ok': true,
          'message': body['message'] ?? 'Password reset successful',
        };
      }

      if (res.statusCode == 422) {
        final errors = body['errors'] as Map<String, dynamic>?;
        final firstError = errors != null && errors.isNotEmpty
            ? (errors.values.first as List).first.toString()
            : (body['message'] ?? 'Please check your password and try again.');
        return {'ok': false, 'message': firstError};
      }

      return {
        'ok': false,
        'message':
            body['message'] ?? 'Something went wrong (${res.statusCode}).',
      };
    } catch (_) {
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
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _service = _ResetPasswordService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  double get _strength {
    final p = _passwordController.text;
    double score = 0;
    if (p.length >= 8) score += 0.34;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p))
      score += 0.33;
    if (RegExp(r'[0-9]').hasMatch(p) ||
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p))
      score += 0.33;
    return score.clamp(0, 1);
  }

  Color get _strengthColor {
    if (_strength < 0.4) return _LightTheme.danger;
    if (_strength < 0.9) return _LightTheme.warning;
    return _LightTheme.success;
  }

  String get _strengthLabel {
    if (_passwordController.text.isEmpty) return '';
    if (_strength < 0.4) return 'Weak';
    if (_strength < 0.9) return 'Medium';
    return 'Strong';
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a new password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please confirm your new password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _service.resetPassword(
      email: widget.email,
      otp: widget.otp,
      password: _passwordController.text,
      passwordConfirmation: _confirmController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['ok'] == true) {
      _showSuccessAndRedirect(result['message'] as String);
    } else {
      setState(() => _errorText = result['message'] as String);
    }
  }

  void _showSuccessAndRedirect(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _LightTheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _LightTheme.blueShadow(
              blur: 30,
              offset: const Offset(0, 14),
              opacity: 0.20,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _LightTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _LightTheme.success,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Password Reset!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _LightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _LightTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: 'Back to Login',
                loading: false,
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                    icon: Icons.password_rounded,
                    color: _LightTheme.primaryBlue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Set New Password',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _LightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your new password must be different from your previously used password.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _LightTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'New password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _LightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AuthTextField(
                    controller: _passwordController,
                    hint: 'Enter new password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    onChanged: (_) {
                      if (_errorText != null) setState(() => _errorText = null);
                      setState(() {});
                    },
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _LightTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _strength,
                              minHeight: 6,
                              backgroundColor: _LightTheme.border,
                              color: _strengthColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _strengthLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _strengthColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Confirm password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _LightTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AuthTextField(
                    controller: _confirmController,
                    hint: 'Re-enter new password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirm,
                    validator: _validateConfirm,
                    onChanged: (_) {
                      if (_errorText != null) setState(() => _errorText = null);
                    },
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _LightTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: _errorText!),
                  ],
                  const SizedBox(height: 28),
                  _PrimaryButton(
                    label: 'Reset Password',
                    loading: _loading,
                    onTap: _submit,
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
