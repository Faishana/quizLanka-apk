// lib/verify_otp_screen.dart
// QuizLanka AI — Forgot Password (Step 2: Verify OTP)
//
// BACKEND ROUTES (adjust the two paths below if yours differ):
//   POST /student/verify-otp       body: { "email": "...", "otp": "123456" }
//   POST /student/forgot-password  body: { "email": "..." }   (resend)
//   success: { "success": true, "message": "..." }
//   error:   { "success": false, "message": "..." } or 422 { "errors": {...} }

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/reset_password_screen.dart'; // <- your existing screen

const String _verifyPath = '/student/verify-otp';
const String _resendPath = '/student/forgot-password';
const int _otpLength = 6;
const int _resendSeconds = 60;

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class _OtpService {
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = <String, dynamic>{};
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }

      debugPrint('OTP $path STATUS: ${res.statusCode}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (body['success'] == false) {
          return {'ok': false, 'message': body['message'] ?? 'Request failed'};
        }
        return {'ok': true, 'message': body['message'] ?? 'Success'};
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
          'message': body['message'] ?? 'The code is invalid or has expired.',
        };
      }

      if (res.statusCode == 429) {
        return {
          'ok': false,
          'message': 'Too many attempts. Please wait a minute and try again.',
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
      debugPrint('OTP ERROR: $e');
      return {
        'ok': false,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> verify(String email, String otp) =>
      _post(_verifyPath, {'email': email, 'otp': otp});

  Future<Map<String, dynamic>> resend(String email) =>
      _post(_resendPath, {'email': email});
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _service = _OtpService();
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  bool _verifying = false;
  bool _resending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return widget.email;
    final name = parts[0];
    final shown = name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
    return '$shown***@${parts[1]}';
  }

  void _onChanged(String value) {
    setState(() => _errorText = null);
    if (value.length == _otpLength) _verify();
  }

  Future<void> _verify() async {
    if (_verifying) return;

    final otp = _otpController.text.trim();
    if (otp.length != _otpLength) {
      setState(() => _errorText = 'Enter the $_otpLength-digit code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _errorText = null;
    });

    final result = await _service.verify(widget.email, otp);

    if (!mounted) return;

    if (result['ok'] == true) {
      HapticFeedback.lightImpact();
      setState(() => _verifying = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Adjust the arguments to match your ResetPasswordScreen.
          builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _verifying = false;
        _errorText = result['message'] as String;
        _otpController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;

    setState(() {
      _resending = true;
      _errorText = null;
    });

    final result = await _service.resend(widget.email);

    if (!mounted) return;
    setState(() => _resending = false);

    final ok = result['ok'] == true;
    if (ok) {
      _otpController.clear();
      _startTimer();
      _focusNode.requestFocus();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF1B7F4B) : QL.danger,
        content: Text(
          ok ? 'A new code has been sent.' : result['message'] as String,
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final code = _otpController.text;

    return QLAuthLayout(
      header: _buildHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorText != null) ...[
            QLErrorBanner(message: _errorText!),
            const SizedBox(height: 16),
          ],
          const QLFieldLabel('Verification code'),
          const SizedBox(height: 10),

          // 6 visible boxes + one real (invisible) text field on top.
          // This keeps paste, autofill and the SMS/email one-time-code
          // suggestion working.
          Semantics(
            label: 'Verification code, $_otpLength digits',
            textField: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode.requestFocus(),
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (i) {
                      final hasChar = i < code.length;
                      final active = _focusNode.hasFocus &&
                          i == code.length.clamp(0, _otpLength - 1);
                      return _OtpBox(
                        char: hasChar ? code[i] : '',
                        active: active,
                        error: _errorText != null,
                      );
                    }),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _otpController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        enableInteractiveSelection: false,
                        showCursor: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_otpLength),
                        ],
                        onChanged: _onChanged,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          QLPrimaryButton(
            label: 'Verify code',
            isLoading: _verifying,
            enabled: code.length == _otpLength,
            onTap: _verify,
          ),
          const SizedBox(height: 18),

          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Resend code in ${_secondsLeft}s',
                    style: const TextStyle(fontSize: 14, color: QL.muted),
                  )
                : TextButton(
                    onPressed: _resending ? null : _resend,
                    style: TextButton.styleFrom(
                      foregroundColor: QL.blue,
                      minimumSize: const Size(44, 44),
                    ),
                    child: _resending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            "Didn't get a code? Resend",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
          ),

          const Spacer(),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _goBack,
              style: TextButton.styleFrom(
                foregroundColor: QL.muted,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text(
                'Use a different email',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ),
        ],
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
                    Icons.mark_email_read_rounded,
                    color: QL.navy,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check your email',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We sent a $_otpLength-digit code to $_maskedEmail. '
                  'Enter it below to continue.',
                  style: const TextStyle(
                    color: QL.ice,
                    fontSize: 14,
                    height: 1.5,
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

// ─────────────────────────────────────────────
// SINGLE OTP BOX
// ─────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.char,
    required this.active,
    required this.error,
  });

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? QL.danger
        : (active ? QL.blue : (char.isNotEmpty ? QL.navyLight : QL.border));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.white : QL.fieldFill,
        borderRadius: BorderRadius.circular(QL.fieldRadius),
        border: Border.all(color: borderColor, width: active ? 2 : 1.5),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: QL.ink,
        ),
      ),
    );
  }
}