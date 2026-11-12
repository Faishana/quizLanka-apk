// ignore_for_file: file_names

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart'; // LoginScreen + AuthProvider
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/user_onboarding_screen.dart'
    show UserOnboardingScreen;

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// Strength meter colours (all readable on white)
const List<Color> _strengthColors = [
  Color(0xFFD5DBEA),
  Color(0xFFB3261E),
  Color(0xFFB45309),
  Color(0xFF1E4FD8),
  Color(0xFF1B7F4B),
];

// ============================================================
// REGISTER SCREEN
// ============================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  // Tap recognizers must be disposed (the old code leaked them).
  final _termsTap = TapGestureRecognizer();
  final _privacyTap = TapGestureRecognizer();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  bool _termsError = false;
  bool _isLoading = false;
  String? _errorMessage;

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // TODO: open your Terms / Privacy pages here.
    _termsTap.onTap = () {};
    _privacyTap.onTap = () {};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  // ── REGISTER HANDLER ────────────────────────────────────────
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _errorMessage = null;
      _termsError = !_agreeToTerms;
    });

    final valid = _formKey.currentState!.validate();
    if (!valid || !_agreeToTerms) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();

    // Passwords are NOT trimmed, so they match exactly what Login sends.
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _confirmController.text,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1B7F4B),
          duration: Duration(seconds: 2),
          content: Text("Account created! Let's set up your profile."),
        ),
      );
      // Clear the stack so Back can't return to Login/Register.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserOnboardingScreen()),
        (route) => false,
      );
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _errorMessage = auth.error ?? 'Registration failed. Please try again.';
      });
    }
  }

  void _goToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── PASSWORD STRENGTH ───────────────────────────────────────
  int _passwordStrength() {
    final p = _passwordController.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    return s;
  }

  // ── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return QLAuthLayout(header: _buildHeader(), child: _buildForm());
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
                  onTap: _goToLogin,
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
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get started',
                  style: TextStyle(
                    color: QL.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Start your exam preparation today.',
                  style: TextStyle(color: QL.ice, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            QLErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],

          // ── Full name ──
          const QLFieldLabel('Full name'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
            style: qlInputStyle,
            cursorColor: QL.blue,
            decoration: qlFieldDecoration(
              hint: 'Your full name',
              icon: Icons.person_outline_rounded,
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your full name';
              if (value.length < 2) return 'Name is too short';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Email ──
          const QLFieldLabel('Email address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            style: qlInputStyle,
            cursorColor: QL.blue,
            decoration: qlFieldDecoration(
              hint: 'name@example.com',
              icon: Icons.mail_outline_rounded,
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your email';
              if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Password ──
          const QLFieldLabel('Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
            onChanged: (_) => setState(() {}),
            style: qlInputStyle,
            cursorColor: QL.blue,
            decoration: qlFieldDecoration(
              hint: 'At least 8 characters',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: QL.muted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 8) return 'Minimum 8 characters';
              return null;
            },
          ),
          _buildStrengthMeter(),
          const SizedBox(height: 16),

          // ── Confirm password ──
          const QLFieldLabel('Confirm password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmController,
            focusNode: _confirmFocus,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _handleRegister(),
            style: qlInputStyle,
            cursorColor: QL.blue,
            decoration: qlFieldDecoration(
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: QL.muted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          _buildTermsCheckbox(),
          const SizedBox(height: 18),

          QLPrimaryButton(
            label: 'Create account',
            isLoading: _isLoading,
            onTap: _handleRegister,
          ),

          const Spacer(),
          const SizedBox(height: 20),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: QL.muted),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(
                      color: QL.blue,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = _goToLogin,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, color: QL.muted, size: 15),
              SizedBox(width: 6),
              Text(
                'Your data is kept secure',
                style: TextStyle(
                  fontSize: 12,
                  color: QL.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthMeter() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    final strength = _passwordStrength();
    final color = _strengthColors[strength];
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < strength ? color : const Color(0xFFE1E6F2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                labels[strength],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: strength == 0 ? QL.muted : color,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Add capitals, numbers & symbols',
                  style: TextStyle(fontSize: 11.5, color: QL.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: _agreeToTerms,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _agreeToTerms = !_agreeToTerms;
              if (_agreeToTerms) _termsError = false;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: _agreeToTerms ? QL.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _termsError
                            ? QL.danger
                            : (_agreeToTerms ? QL.blue : QL.hint),
                        width: 1.6,
                      ),
                    ),
                    child: _agreeToTerms
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: QL.muted,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                              color: QL.blue,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: _termsTap,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: QL.blue,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: _privacyTap,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_termsError)
          const Padding(
            padding: EdgeInsets.only(left: 32, top: 2),
            child: Text(
              'Please agree to continue',
              style: TextStyle(
                color: QL.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
