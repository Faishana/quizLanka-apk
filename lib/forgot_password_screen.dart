// lib/forgot_password_screen.dart
// QuizLanka AI — Forgot Password (Step 1: Request OTP)
//
// BACKEND ROUTE:
//   POST /student/forgot-password   body: { "email": "..." }
//   success: { "success": true, "message": "OTP sent to your email", "email": "..." }
//   error:   { "success": false, "message": "..." }
//   or Laravel validation (422): { "errors": { "email": ["..."] } }

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/verify_otp_screen.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class _ForgotPasswordService {
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/student/forgot-password');

    try {
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = <String, dynamic>{};
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }

      debugPrint('FORGOT PASSWORD STATUS: ${res.statusCode}');

      if (res.statusCode == 200 || res.statusCode == 201) {
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

      if (res.statusCode == 422) {
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            return {'ok': false, 'message': first.first.toString()};
          }
          if (first is String) return {'ok': false, 'message': first};
        }
        return {
          'ok': false,
          'message': body['message'] ?? 'Please check the email you entered.',
        };
      }

      if (res.statusCode == 429) {
        return {
          'ok': false,
          'message': 'Too many requests. Please wait a minute and try again.',
        };
      }

      return {
        'ok': false,
        'message':
            body['message'] ?? 'Something went wrong (${res.statusCode}).',
      };
    } on TimeoutException {
      return {
        'ok': false,
        'message': 'The server took too long to respond. Please try again.',
      };
    } on SocketException {
      return {
        'ok': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException {
      return {
        'ok': false,
        'message': 'Unable to connect to the server. Please try again.',
      };
    } on FormatException {
      return {
        'ok': false,
        'message': 'Invalid response from server. Please try again.',
      };
    } catch (e) {
      debugPrint('FORGOT PASSWORD ERROR: $e');
      return {
        'ok': false,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Optional: pre-fill the email typed on the login screen.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _service = _ForgotPasswordService();

  bool _loading = false;
  bool _disposed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _disposed = true;
    _emailController.dispose();
    super.dispose();
  }

  /// Safe setState that no-ops after dispose.
  void _safeSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  Future<void> _submit() async {
    if (_disposed || _loading) return;

    FocusScope.of(context).unfocus();
    _safeSetState(() => _errorText = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    _safeSetState(() => _loading = true);

    // Capture email BEFORE await — never touch controller after await.
    final email = _emailController.text.trim();
    final result = await _service.sendOtp(email);

    if (_disposed || !mounted) return;
    _safeSetState(() => _loading = false);

    if (result['ok'] == true) {
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B7F4B),
          duration: const Duration(seconds: 2),
          content: Text(result['message'] as String),
        ),
      );

      final emailToSend = result['email'] as String? ?? email;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: emailToSend)),
      );
    } else {
      HapticFeedback.mediumImpact();
      _safeSetState(() => _errorText = result['message'] as String);
    }
  }

  void _goBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return QLAuthLayout(
      header: _buildHeader(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              QLErrorBanner(message: _errorText!),
              const SizedBox(height: 16),
            ],
            const QLFieldLabel('Email address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_errorText != null) {
                  _safeSetState(() => _errorText = null);
                }
              },
              style: qlInputStyle,
              cursorColor: QL.blue,
              decoration: qlFieldDecoration(
                hint: 'name@example.com',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Please enter your email address';
                if (!_emailRegex.hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            QLPrimaryButton(
              label: 'Send OTP',
              isLoading: _loading,
              onTap: _submit,
            ),
            const Spacer(),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: _goBack,
                style: TextButton.styleFrom(
                  foregroundColor: QL.blue,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Back to login',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  onTap: _goBack,
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
              const Spacer(),
              const QLBrandMark(size: 38, fontSize: 18),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: QL.gold,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: QL.navy,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "No worries. Enter the email linked to your account and "
                  "we'll send you a 6-digit code to reset your password.",
                  style: TextStyle(color: QL.ice, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
