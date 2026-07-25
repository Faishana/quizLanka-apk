// ignore_for_file: file_names

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart'; // LoginScreen + AuthProvider
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/dashboard.dart';

// ============================================================
// DESIGN TOKENS — "Aurora Glass" theme (matches Login/Onboarding)
// ============================================================
class _RegisterTokens {
  _RegisterTokens._();

  static const List<Color> backgroundGradient = [
    Color(0xFF0B0B22),
    Color(0xFF141335),
    Color(0xFF1D1B4B),
  ];

  static const Color violet = Color(0xFF9B6BFF);
  static const Color cyan = Color(0xFF3FB4FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB9B6D9);

  static const double fieldRadius = 14;
  static const double cardRadius = 28;

  static const List<Color> strengthColors = [
    Color(0xFF4B4870),
    Color(0xFFFF7A7A),
    Color(0xFFFFB020),
    Color(0xFFF5D742),
    Color(0xFF3FE0A0),
  ];
}

// ============================================================
// REGISTER SCREEN — redesigned UI, identical behavior
// ============================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── controllers ────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolController = TextEditingController();

  // ── state ──────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String _selectedProvince = 'Western Province';

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<dynamic> _grades = [];
  int? _selectedGradeId;

  final List<String> _provinces = [
    'Western Province',
    'Central Province',
    'Southern Province',
    'Northern Province',
    'Eastern Province',
    'North Western Province',
    'North Central Province',
    'Uva Province',
    'Sabaragamuwa Province',
  ];

  // ── lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadGrades();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── API calls — unchanged ───────────────────────────────────
  Future<void> _loadGrades() async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.grades}';

      final response = await http.get(Uri.parse(url));

      final data = jsonDecode(response.body);

      debugPrint("GRADES API RESPONSE:");
      debugPrint(response.body);

      if (mounted) {
        setState(() {
          _grades = data['data'] ?? [];
        });

        debugPrint(_grades.toString());
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ── register handler — unchanged ────────────────────────────
  Future<void> _handleRegister() async {
    debugPrint("REGISTER GRADE ID = $_selectedGradeId");

    if (_selectedGradeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select your grade')));
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to Terms of Service')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.register(
        _fullNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _confirmPasswordController.text.trim(),
        _selectedGradeId!,
        _schoolController.text.trim(),
        _selectedProvince,
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Welcome aboard! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else if (!success && mounted) {
        final error = context.read<AuthProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Registration failed. Please try again.'),
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

  // ── password strength — unchanged logic ─────────────────────
  int _getPasswordStrength() {
    final pass = _passwordController.text;
    int strength = 0;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9]'))) strength++;
    if (pass.contains(RegExp(r'[!@#\$%^&*()_+]'))) strength++;
    return strength;
  }

  String _getStrengthLabel(int strength) {
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    return labels[strength];
  }

  Color _getStrengthColor(int strength) {
    return _RegisterTokens.strengthColors[strength];
  }

  // ── build UI ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _RegisterTokens.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _RegisterTokens.backgroundGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _GlowBlob(color: _RegisterTokens.violet, size: 260),
            ),
            Positioned(
              bottom: -60,
              left: -50,
              child: _GlowBlob(color: _RegisterTokens.cyan, size: 220),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(onBack: () => Navigator.pop(context)),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(
                                _RegisterTokens.cardRadius,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _HeaderBlock(),
                                  const SizedBox(height: 22),
                                  const _SectionLabel('Personal Information'),
                                  const SizedBox(height: 12),
                                  _GlassTextField(
                                    controller: _fullNameController,
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    hint: 'Enter your full name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassTextField(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    icon: Icons.mail_outline,
                                    hint: 'Enter your email',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  const _SectionLabel('Academic Information'),
                                  const SizedBox(height: 12),
                                  _GlassTextField(
                                    controller: _schoolController,
                                    label: 'School Name',
                                    icon: Icons.school_outlined,
                                    hint: 'Enter your school name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your school name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildGradeDropdown(),
                                  const SizedBox(height: 12),
                                  _buildProvinceDropdown(),
                                  const SizedBox(height: 20),
                                  const _SectionLabel('Create Password'),
                                  const SizedBox(height: 12),
                                  _GlassTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    hint: 'Min. 8 characters',
                                    isPassword: true,
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (value.length < 8) {
                                        return 'Password must be at least 8 characters';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildPasswordStrength(),
                                  const SizedBox(height: 12),
                                  _GlassTextField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm Password',
                                    icon: Icons.lock_outline,
                                    hint: 'Re-enter your password',
                                    isPassword: true,
                                    obscure: _obscureConfirm,
                                    onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTermsCheckbox(),
                                  const SizedBox(height: 22),
                                  _buildRegisterButton(),
                                  const SizedBox(height: 18),
                                  _buildSocialSection(),
                                  const SizedBox(height: 20),
                                  _buildLoginLink(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── data-bound components kept as instance methods since they
  //    read _grades / _selectedGradeId / _selectedProvince state ──

  Widget _buildGradeDropdown() {
    return _GlassDropdownShell(
      icon: Icons.grade_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedGradeId,
          hint: Text(
            'Select Grade',
            style: TextStyle(
              color: _RegisterTokens.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          isExpanded: true,
          items: _grades.map((grade) {
            return DropdownMenuItem<int>(
              value: grade['id'],
              child: Text(
                grade['name'] ?? 'Grade ${grade['id']}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _RegisterTokens.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            debugPrint("Selected Grade ID = $value");
            setState(() => _selectedGradeId = value);
          },
          style: const TextStyle(
            fontSize: 13,
            color: _RegisterTokens.textPrimary,
          ),
          dropdownColor: const Color(0xFF201E4A),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _RegisterTokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return _GlassDropdownShell(
      icon: Icons.location_on_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvince,
          isExpanded: true,
          items: _provinces.map((province) {
            return DropdownMenuItem<String>(
              value: province,
              child: Text(
                province,
                style: const TextStyle(
                  fontSize: 13,
                  color: _RegisterTokens.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedProvince = value!),
          style: const TextStyle(
            fontSize: 13,
            color: _RegisterTokens.textPrimary,
          ),
          dropdownColor: const Color(0xFF201E4A),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _RegisterTokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrength() {
    final strength = _getPasswordStrength();
    final label = _getStrengthLabel(strength);
    final color = _getStrengthColor(strength);

    if (_passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 11,
                color: _RegisterTokens.textSecondary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < strength
                      ? color
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Use 8+ chars, uppercase, numbers & symbols',
          style: TextStyle(
            fontSize: 10,
            color: _RegisterTokens.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _agreeToTerms
                  ? _RegisterTokens.violet
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreeToTerms
                    ? _RegisterTokens.violet
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: _agreeToTerms
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: _RegisterTokens.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: _RegisterTokens.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: _RegisterTokens.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. I understand my data will be used to personalize my learning experience.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleRegister,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: _agreeToTerms
              ? const LinearGradient(
                  colors: [_RegisterTokens.violet, _RegisterTokens.cyan],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _agreeToTerms
              ? [
                  BoxShadow(
                    color: _RegisterTokens.violet.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: TextStyle(
                        color: _agreeToTerms
                            ? Colors.white
                            : _RegisterTokens.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: _agreeToTerms
                          ? Colors.white
                          : _RegisterTokens.textSecondary,
                      size: 14,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.14)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or sign up with',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GlassSocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google Sign In coming soon!'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassSocialButton(
                label: 'Apple',
                icon: Icons.apple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apple Sign In coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              fontSize: 13,
              color: _RegisterTokens.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: Text(
              'Login',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _RegisterTokens.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRIVATE, REUSABLE, STATELESS WIDGETS
// (extracted since they don't depend on mutable form state)
// ============================================================

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_RegisterTokens.violet, _RegisterTokens.cyan],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'QuizLanka ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: 'AI',
                      style: TextStyle(
                        color: _RegisterTokens.violet,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _RegisterTokens.violet.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🎓', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Your Account',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: _RegisterTokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Join 50,000+ Sri Lankan students',
                    style: TextStyle(
                      fontSize: 12,
                      color: _RegisterTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatChip(value: '50K+', label: 'Students'),
              _StatDivider(),
              _StatChip(value: '9', label: 'Provinces'),
              _StatDivider(),
              _StatChip(value: '12+', label: 'Subjects'),
              _StatDivider(),
              _StatChip(value: 'Free', label: 'Forever'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: _RegisterTokens.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_RegisterTokens.violet, _RegisterTokens.cyan],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: _RegisterTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.isPassword = false,
    this.obscure,
    this.onToggle,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final bool isPassword;
  final bool? obscure;
  final VoidCallback? onToggle;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && (obscure ?? true),
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          color: _RegisterTokens.textPrimary,
        ),
        validator: validator,
        onChanged: onChanged,
        cursorColor: _RegisterTokens.violet,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: _RegisterTokens.textSecondary.withValues(alpha: 0.8),
            fontSize: 12,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: _RegisterTokens.textSecondary.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: _RegisterTokens.violet, size: 20),
          suffixIcon: isPassword && onToggle != null
              ? IconButton(
                  icon: Icon(
                    (obscure ?? true)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _RegisterTokens.textSecondary,
                    size: 20,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}

/// Shared glass shell used by both dropdowns so they visually match
/// the text fields above them.
class _GlassDropdownShell extends StatelessWidget {
  const _GlassDropdownShell({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _RegisterTokens.violet, size: 20),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _GlassSocialButton extends StatelessWidget {
  const _GlassSocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _RegisterTokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
