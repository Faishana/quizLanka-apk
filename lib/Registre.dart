// ignore_for_file: file_names

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart'; // LoginScreen + AuthProvider
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/main_navigation.dart';

// ============================================================
// DESIGN TOKENS — "Aurora Glass" theme (matches LoginScreen)
// ============================================================
class _RegisterTokens {
  _RegisterTokens._();

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

  static const List<Color> strengthColors = [
    Color(0xFF4B4870),
    Color(0xFFFF8A8A),
    Color(0xFFFFB020),
    Color(0xFFF5D742),
    Color(0xFF3FE0A0),
  ];
}

// ============================================================
// USER TYPE ENUM
// ============================================================
enum UserType { student, governmentExamCandidate }

extension UserTypeX on UserType {
  String get apiValue {
    switch (this) {
      case UserType.student:
        return 'Student';
      case UserType.governmentExamCandidate:
        return 'Government Exam Candidate';
    }
  }

  String get label {
    switch (this) {
      case UserType.student:
        return 'Student';
      case UserType.governmentExamCandidate:
        return 'Government Exam Candidate';
    }
  }

  String get subtitle {
    switch (this) {
      case UserType.student:
        return 'School student preparing for O/L or A/L';
      case UserType.governmentExamCandidate:
        return 'Preparing for government competitive exams';
    }
  }

  IconData get icon {
    switch (this) {
      case UserType.student:
        return Icons.school_rounded;
      case UserType.governmentExamCandidate:
        return Icons.menu_book_rounded;
    }
  }
}

// ============================================================
// REGISTER SCREEN
// ============================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String _selectedProvince = 'Western Province';

  UserType _userType = UserType.student;
  bool get _isStudent => _userType == UserType.student;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  late AnimationController _animController;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;

  List<dynamic> _grades = [];
  int? _selectedGradeId;
  String? _selectedAlStream;

  static const List<Map<String, String>> _alStreams = [
    {'value': 'bio', 'label': 'Biological Science'},
    {'value': 'maths', 'label': 'Mathematics'},
    {'value': 'technology', 'label': 'Technology'},
    {'value': 'arts', 'label': 'Arts'},
    {'value': 'commerce', 'label': 'Commerce'},
  ];

  Map<String, dynamic>? get _selectedGrade {
    for (final item in _grades) {
      if (item is Map &&
          item['id'].toString() == _selectedGradeId?.toString()) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  bool get _isALGrade {
    final category = (_selectedGrade?['category'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return category == 'al';
  }

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

  @override
  void initState() {
    super.initState();
    _loadGrades();

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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolController.dispose();
    _animController.dispose();
    super.dispose();
  }

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
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ── REGISTER HANDLER — FIXED to match backend contract ─────
  Future<void> _handleRegister() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    if (_isStudent && _selectedGradeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select your grade')));
      return;
    }

    if (_isStudent && _isALGrade && _selectedAlStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your A/L stream')),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to Terms of Service')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      // ✅ FIXED: non-students send `null` (backend validates as nullable),
      //            not 0 / '' which break the DB / validation.
      final int? gradeIdToSend = _isStudent ? _selectedGradeId : null;

      final String? schoolToSend = _isStudent
          ? (_schoolController.text.trim().isEmpty
                ? null
                : _schoolController.text.trim())
          : null;

      final String? districtToSend = _selectedProvince.trim().isEmpty
          ? null
          : _selectedProvince.trim();

      // Only A/L students send an al_stream value.
      final String? alStreamToSend = (_isStudent && _isALGrade)
          ? _selectedAlStream
          : null;

      debugPrint(
        "REGISTER → category=${_userType.apiValue}, "
        "grade=$gradeIdToSend, school='$schoolToSend', "
        "district='$districtToSend', al_stream='$alStreamToSend'",
      );

      final success = await authProvider.register(
        _fullNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _confirmPasswordController.text.trim(),
        gradeIdToSend,
        schoolToSend,
        districtToSend,
        _userType.apiValue,
        alStreamToSend,
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
          MaterialPageRoute(builder: (_) => const MainNavigation()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _RegisterTokens.backgroundGradient.first,
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
                    colors: _RegisterTokens.backgroundGradient,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const _BrandMark(),
                        const Spacer(),
                        const SizedBox(width: 42),
                      ],
                    ),
                    const SizedBox(height: 20),
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
      borderRadius: BorderRadius.circular(_RegisterTokens.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1740).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(_RegisterTokens.cardRadius),
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
                  'Create Your Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _RegisterTokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join 50,000+ Sri Lankan learners',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _RegisterTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),

                const _SectionLabel('I am a'),
                const SizedBox(height: 12),
                _buildUserTypeSelector(),
                const SizedBox(height: 20),

                const _SectionLabel('Personal Information'),
                const SizedBox(height: 12),
                _GlassTextField(
                  controller: _fullNameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your full name';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 20),

                const _SectionLabel('Academic Information'),
                const SizedBox(height: 12),

                if (_isStudent) ...[
                  _buildGradeDropdown(),
                  if (_isALGrade) ...[
                    const SizedBox(height: 12),
                    _buildAlStreamDropdown(),
                  ],
                  const SizedBox(height: 12),
                  _GlassTextField(
                    controller: _schoolController,
                    hint: 'School Name',
                    icon: Icons.school_outlined,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Enter your school name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                _buildProvinceDropdown(),
                const SizedBox(height: 20),

                const _SectionLabel('Create Password'),
                const SizedBox(height: 12),
                _GlassTextField(
                  controller: _passwordController,
                  hint: 'Password (min. 8 chars)',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _RegisterTokens.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _buildPasswordStrength(),
                const SizedBox(height: 12),
                _GlassTextField(
                  controller: _confirmPasswordController,
                  hint: 'Confirm Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _RegisterTokens.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _buildTermsCheckbox(),
                const SizedBox(height: 22),

                _GradientButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  enabled: _agreeToTerms,
                  onTap: _handleRegister,
                ),
                const SizedBox(height: 18),

                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: _RegisterTokens.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Login',
                          style: const TextStyle(
                            color: _RegisterTokens.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: _RegisterTokens.violet.withValues(alpha: 0.95),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Your data is secure with us',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _RegisterTokens.violet.withValues(alpha: 0.95),
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

  Widget _buildUserTypeSelector() {
    return Column(
      children: UserType.values.map((type) {
        final selected = _userType == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              if (_userType == type) return;
              setState(() {
                _userType = type;
                if (!_isStudent) {
                  _selectedGradeId = null;
                  _selectedAlStream = null;
                  _schoolController.clear();
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? _RegisterTokens.violet.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? _RegisterTokens.violet
                      : Colors.white.withValues(alpha: 0.16),
                  width: selected ? 1.6 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [
                                _RegisterTokens.violet,
                                _RegisterTokens.cyan,
                              ],
                            )
                          : null,
                      color: selected
                          ? null
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      type.icon,
                      color: selected
                          ? Colors.white
                          : _RegisterTokens.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? _RegisterTokens.textPrimary
                                : _RegisterTokens.textPrimary.withValues(
                                    alpha: 0.85,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _RegisterTokens.textSecondary,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? _RegisterTokens.violet
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? _RegisterTokens.violet
                            : _RegisterTokens.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? const Center(
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradeDropdown() {
    return _GlassDropdownShell(
      icon: Icons.grade_outlined,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedGradeId,
          hint: Text(
            'Select Grade',
            style: TextStyle(
              color: _RegisterTokens.textSecondary.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: _grades
              .map(
                (g) => DropdownMenuItem<int>(
                  value: g['id'],
                  child: Text(
                    g['name'] ?? 'Grade ${g['id']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _RegisterTokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedGradeId = v;
              // A stream must be selected again whenever the grade changes.
              _selectedAlStream = null;
            });
          },
          dropdownColor: const Color(0xFF201E4A),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _RegisterTokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAlStreamDropdown() {
    return _GlassDropdownShell(
      icon: Icons.menu_book_rounded,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAlStream,
          hint: Text(
            'Select A/L Stream',
            style: TextStyle(
              color: _RegisterTokens.textSecondary.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: _alStreams
              .map(
                (stream) => DropdownMenuItem<String>(
                  value: stream['value'],
                  child: Text(
                    stream['label']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _RegisterTokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _selectedAlStream = value);
          },
          dropdownColor: const Color(0xFF201E4A),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
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
          isDense: true,
          underline: const SizedBox.shrink(),
          items: _provinces
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p,
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _RegisterTokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedProvince = v!),
          dropdownColor: const Color(0xFF201E4A),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _RegisterTokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrength() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    final strength = _getPasswordStrength();
    final label = _getStrengthLabel(strength);
    final color = _getStrengthColor(strength);

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
                      : Colors.white.withValues(alpha: 0.10),
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
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _agreeToTerms
                  ? _RegisterTokens.violet
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _agreeToTerms
                    ? _RegisterTokens.violet
                    : _RegisterTokens.textSecondary,
                width: 1.5,
              ),
            ),
            child: _agreeToTerms
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: _RegisterTokens.textSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: _RegisterTokens.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: _RegisterTokens.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRIVATE, REUSABLE WIDGETS — unchanged
// ============================================================

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_RegisterTokens.violet, _RegisterTokens.cyan],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: _RegisterTokens.violet.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(
                  color: _RegisterTokens.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(
                  color: _RegisterTokens.violet,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
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
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _RegisterTokens.textPrimary,
            letterSpacing: 0.2,
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
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 15,
        color: _RegisterTokens.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      onChanged: onChanged,
      cursorColor: _RegisterTokens.violet,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFC9C6E8),
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: _RegisterTokens.textSecondary, size: 20),
        suffixIcon: suffix,
        errorStyle: const TextStyle(
          color: _RegisterTokens.danger,
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
          borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
          borderSide: const BorderSide(
            color: _RegisterTokens.violet,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
          borderSide: BorderSide(
            color: _RegisterTokens.danger.withValues(alpha: 0.7),
            width: 1.3,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
          borderSide: const BorderSide(
            color: _RegisterTokens.danger,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

class _GlassDropdownShell extends StatelessWidget {
  const _GlassDropdownShell({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_RegisterTokens.fieldRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: _RegisterTokens.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
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
                  colors: [_RegisterTokens.violet, _RegisterTokens.cyan],
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
                    color: _RegisterTokens.violet.withValues(alpha: 0.45),
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
                            : _RegisterTokens.textSecondary,
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
                          : _RegisterTokens.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
