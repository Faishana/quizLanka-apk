import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/main_navigation.dart';

// These two values are sent to the backend exactly as written.
const String _kStudent = 'Student';
const String _kGovCandidate = 'Government Exam Candidate';

class UserOnboardingScreen extends StatefulWidget {
  const UserOnboardingScreen({super.key});

  @override
  State<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends State<UserOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolController = TextEditingController();

  String? _userCategory;
  String? _district;
  String? _alStream;
  int? _gradeId;

  List<Map<String, dynamic>> _grades = [];

  bool _loadingGrades = true;
  bool _gradesFailed = false;
  bool _submitting = false;
  String? _errorMessage;

  static const List<String> _districts = [
    'Ampara',
    'Anuradhapura',
    'Badulla',
    'Batticaloa',
    'Colombo',
    'Galle',
    'Gampaha',
    'Hambantota',
    'Jaffna',
    'Kalutara',
    'Kandy',
    'Kegalle',
    'Kilinochchi',
    'Kurunegala',
    'Mannar',
    'Matale',
    'Matara',
    'Monaragala',
    'Mullaitivu',
    'Nuwara Eliya',
    'Polonnaruwa',
    'Puttalam',
    'Ratnapura',
    'Trincomalee',
    'Vavuniya',
  ];

  static const List<Map<String, String>> _alStreams = [
    {'value': 'maths', 'label': 'Physical Science'},
    {'value': 'bio', 'label': 'Biological Science'},
    {'value': 'commerce', 'label': 'Commerce'},
    {'value': 'arts', 'label': 'Arts'},
    {'value': 'technology', 'label': 'Technology'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    super.dispose();
  }

  // ==============================
  // FETCH GRADES
  // ==============================
  Future<void> _fetchGrades() async {
    setState(() {
      _loadingGrades = true;
      _gradesFailed = false;
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri(ApiConfig.grades),
            headers: ApiConfig.getHeaders(null),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Unable to load grades');
      }

      final decoded = jsonDecode(response.body);
      List<dynamic> gradeList = [];

      if (decoded is List) {
        gradeList = decoded;
      } else if (decoded is Map) {
        if (decoded['data'] is List) {
          gradeList = decoded['data'];
        } else if (decoded['grades'] is List) {
          gradeList = decoded['grades'];
        }
      }

      if (!mounted) return;

      setState(() {
        _grades =
            gradeList
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where(
                  (grade) =>
                      grade['is_active'] == 1 ||
                      grade['is_active'] == true ||
                      grade['is_active'] == '1',
                )
                .toList()
              ..sort((a, b) {
                final aOrder = int.tryParse('${a['sort_order']}') ?? 0;
                final bOrder = int.tryParse('${b['sort_order']}') ?? 0;
                return aOrder.compareTo(bOrder);
              });
        _loadingGrades = false;
        _gradesFailed = _grades.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGrades = false;
        _gradesFailed = true;
      });
    }
  }

  // ==============================
  // CHECK A/L GRADE
  // ==============================
  String _gradeName(Map<String, dynamic> g) =>
      (g['name'] ?? g['grade_name'] ?? 'Grade').toString();

  bool get _isALGrade {
    if (_gradeId == null) return false;

    final selected = _grades.firstWhere(
      (g) => int.tryParse('${g['id']}') == _gradeId,
      orElse: () => <String, dynamic>{},
    );

    return selected['category']?.toString().toLowerCase() == 'al';
  }

  // ==============================
  // SUBMIT
  // ==============================
  Future<void> _completeOnboarding() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_userCategory == null) {
      setState(() => _errorMessage = 'Please select your category.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final isStudent = _userCategory == _kStudent;

    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();

    final success = await auth.completeOnboarding(
      userCategory: _userCategory!,
      gradeId: isStudent ? _gradeId : null,
      school: isStudent ? _schoolController.text.trim() : null,
      district: _district!,
      alStream: isStudent && _isALGrade ? _alStream : null,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _submitting = false;
        _errorMessage =
            auth.error ?? 'Unable to complete your profile. Please try again.';
      });
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    await auth.logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _userCategory = category;
      _gradeId = null;
      _alStream = null;
      _errorMessage = null;
    });
  }

  // ==============================
  // UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    final isStudent = _userCategory == _kStudent;

    return QLAuthLayout(
      header: _buildHeader(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              QLErrorBanner(message: _errorMessage!),
              const SizedBox(height: 16),
            ],

            const Text(
              'I am a',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: QL.ink,
              ),
            ),
            const SizedBox(height: 12),
            _CategoryCard(
              title: 'Student',
              subtitle: 'Grade 5 to A/L, studying at school.',
              icon: Icons.school_rounded,
              selected: _userCategory == _kStudent,
              onTap: () => _selectCategory(_kStudent),
            ),
            const SizedBox(height: 12),
            _CategoryCard(
              title: 'Government Exam Candidate',
              subtitle: 'SLAS, banking, teacher, forces and more.',
              icon: Icons.assignment_rounded,
              selected: _userCategory == _kGovCandidate,
              onTap: () => _selectCategory(_kGovCandidate),
            ),

            // ── Student fields ──
            if (isStudent) ...[
              const SizedBox(height: 26),
              const QLFieldLabel('Your grade'),
              const SizedBox(height: 6),
              _buildGradeField(),
              if (_isALGrade) ...[
                const SizedBox(height: 16),
                const QLFieldLabel('A/L stream'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _alStream,
                  isExpanded: true,
                  menuMaxHeight: 320,
                  style: qlInputStyle,
                  decoration: qlFieldDecoration(
                    hint: 'Select your A/L stream',
                    icon: Icons.science_outlined,
                  ),
                  items: [
                    for (final s in _alStreams)
                      DropdownMenuItem<String>(
                        value: s['value'],
                        child: Text(s['label']!),
                      ),
                  ],
                  onChanged: (v) => setState(() => _alStream = v),
                  validator: (v) =>
                      v == null ? 'Please select your A/L stream' : null,
                ),
              ],
              const SizedBox(height: 16),
              const QLFieldLabel('School name (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _schoolController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: qlInputStyle,
                cursorColor: QL.blue,
                decoration: qlFieldDecoration(
                  hint: 'Enter your school name',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],

            // ── District ──
            if (_userCategory != null) ...[
              const SizedBox(height: 16),
              const QLFieldLabel('Your district'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _district,
                isExpanded: true,
                menuMaxHeight: 320,
                style: qlInputStyle,
                decoration: qlFieldDecoration(
                  hint: 'Select your district',
                  icon: Icons.location_on_outlined,
                ),
                items: [
                  for (final d in _districts)
                    DropdownMenuItem<String>(value: d, child: Text(d)),
                ],
                onChanged: (v) => setState(() => _district = v),
                validator: (v) =>
                    v == null ? 'Please select your district' : null,
              ),
            ],

            const SizedBox(height: 26),
            QLPrimaryButton(
              label: 'Complete profile',
              isLoading: _submitting,
              enabled: _userCategory != null && !(isStudent && _loadingGrades),
              onTap: _completeOnboarding,
            ),

            const Spacer(),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'You can update your profile details later.',
                style: TextStyle(fontSize: 12.5, color: QL.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeField() {
    if (_loadingGrades) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: QL.blue),
          ),
        ),
      );
    }

    if (_gradesFailed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: QL.dangerBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: QL.danger, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Grades could not be loaded.',
                style: TextStyle(
                  color: QL.danger,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _fetchGrades,
              style: TextButton.styleFrom(
                foregroundColor: QL.danger,
                minimumSize: const Size(56, 44),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final items = <DropdownMenuItem<int>>[];
    for (final g in _grades) {
      final id = int.tryParse('${g['id']}');
      if (id == null) continue;
      items.add(DropdownMenuItem<int>(value: id, child: Text(_gradeName(g))));
    }

    return DropdownButtonFormField<int>(
      // ignore: deprecated_member_use
      value: _gradeId,
      isExpanded: true,
      menuMaxHeight: 320,
      style: qlInputStyle,
      decoration: qlFieldDecoration(
        hint: 'Choose your grade',
        icon: Icons.format_list_numbered_rounded,
      ),
      items: items,
      onChanged: (v) => setState(() {
        _gradeId = v;
        _alStream = null;
      }),
      validator: (v) => v == null ? 'Please select your grade' : null,
    );
  }

  // ==============================
  // HEADER
  // ==============================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const QLBrandMark(size: 38, fontSize: 18),
              TextButton.icon(
                onPressed: _submitting ? null : _logout,
                style: TextButton.styleFrom(
                  foregroundColor: QL.ice,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Almost there',
                  style: TextStyle(
                    color: QL.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Let's set up your profile",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tell us a little about yourself so we can personalise '
                  'your QuizLanka AI experience.',
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

// ============================================================
// CATEGORY CARD
// ============================================================
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QL.fieldRadius + 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF0FF) : QL.fieldFill,
            borderRadius: BorderRadius.circular(QL.fieldRadius + 2),
            border: Border.all(
              color: selected ? QL.blue : QL.border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? QL.blue : QL.navy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: QL.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: QL.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: QL.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? QL.blue : QL.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
