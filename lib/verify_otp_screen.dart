// lib/verify_otp_screen.dart
// QuizLanka AI — Forgot Password (Step 2: Verify OTP)
// Light "Aurora" theme with soft blue shadows.
// Self-contained: palette + service + UI in one file.
//
// BACKEND ASSUMPTION (adjust if your controller differs):
//   POST /verify-otp   body: { "email": "...", "otp": "123456" }
//   success response:  { "success": true,  "message": "OTP verified" }
//   error response:    { "success": false, "message": "Invalid or expired OTP" }
//
//   Resend reuses:
//   POST /forgot-password   body: { "email": "..." }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/reset_password_screen.dart';

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
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class _OtpService {
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/student/verify-otp');
    return _post(uri, {'email': email, 'otp': otp}, 'OTP verified');
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/student/forgot-password');
    return _post(uri, {
      'email': email,
    }, 'A new OTP has been sent to your email');
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> payload,
    String defaultSuccessMessage,
  ) async {
    try {
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'ok': true,
          'message': body['message'] ?? defaultSuccessMessage,
        };
      }

      if (res.statusCode == 422) {
        final errors = body['errors'] as Map<String, dynamic>?;
        final firstError = errors != null && errors.isNotEmpty
            ? (errors.values.first as List).first.toString()
            : (body['message'] ?? 'The code you entered is invalid.');
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
class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const int _otpLength = 6;
  static const int _resendCooldown = 60;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  final _service = _OtpService();
  bool _loading = false;
  bool _resending = false;
  String? _errorText;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _secondsLeft = _resendCooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_errorText != null) setState(() => _errorText = null);

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-submit once all boxes are filled
    if (_otpValue.length == _otpLength && !_otpValue.contains(RegExp(r'\D'))) {
      FocusScope.of(context).unfocus();
      _submit();
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final otp = _otpValue;
    if (otp.length != _otpLength) {
      setState(() => _errorText = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _service.verifyOtp(widget.email, otp);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['ok'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
        ),
      );
    } else {
      setState(() => _errorText = result['message'] as String);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);

    final result = await _service.resendOtp(widget.email);

    if (!mounted) return;
    setState(() => _resending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] as String),
        backgroundColor: result['ok'] == true
            ? _LightTheme.primaryBlue
            : _LightTheme.danger,
      ),
    );

    if (result['ok'] == true) _startCooldown();
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
                  icon: Icons.mark_email_read_outlined,
                  color: _LightTheme.primaryBlue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _LightTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _LightTheme.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Enter the 6-digit code we sent to ',
                      ),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(
                          color: _LightTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _otpLength,
                    (i) => _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      hasError: _errorText != null,
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _errorText!),
                ],
                const SizedBox(height: 28),
                _PrimaryButton(
                  label: 'Verify Code',
                  loading: _loading,
                  onTap: _submit,
                ),
                const SizedBox(height: 22),
                Center(
                  child: _resending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _LightTheme.primaryBlue,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: Text(
                            _secondsLeft > 0
                                ? "Didn't receive the code? Resend in ${_secondsLeft}s"
                                : "Didn't receive the code? Resend",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _secondsLeft > 0
                                  ? _LightTheme.textSecondary
                                  : _LightTheme.primaryBlue,
                            ),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final void Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? _LightTheme.danger.withValues(alpha: 0.5)
        : (focusNode.hasFocus ? _LightTheme.primaryBlue : _LightTheme.border);

    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: _LightTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: focusNode.hasFocus ? 1.6 : 1,
        ),
        boxShadow: _LightTheme.blueShadow(
          blur: 12,
          offset: const Offset(0, 4),
          opacity: 0.10,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _LightTheme.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
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
