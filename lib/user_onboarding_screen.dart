import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/main_navigation.dart';

import '../../config/api_config.dart';

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
  bool _submitting = false;
  String? _errorMessage;

  final List<String> _districts = [
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

  final List<Map<String, String>> _alStreams = [
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
    try {
      final response = await http.get(
        ApiConfig.uri(ApiConfig.grades),
        headers: ApiConfig.getHeaders(null),
      );

      if (response.statusCode == 200) {
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
          _grades = gradeList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          _loadingGrades = false;
        });
      } else {
        throw Exception('Unable to load grades');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingGrades = false;
        _errorMessage = 'Unable to load grades. Please try again.';
      });
    }
  }

  // ==============================
  // CHECK A/L GRADE
  // ==============================

  bool get _isALGrade {
    final selectedGrade = _grades.firstWhere(
      (grade) => grade['id'] == _gradeId,
      orElse: () => {},
    );

    final gradeName =
        (selectedGrade['name'] ?? selectedGrade['grade_name'] ?? '')
            .toString()
            .toLowerCase();

    return gradeName.contains('12') ||
        gradeName.contains('13') ||
        gradeName.contains('a/l') ||
        gradeName.contains('advanced level');
  }

  // ==============================
  // SUBMIT ONBOARDING
  // ==============================

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userCategory == null) {
      _showMessage('Please select your category.');
      return;
    }

    if (_district == null) {
      _showMessage('Please select your district.');
      return;
    }

    if (_userCategory == 'Student' && _gradeId == null) {
      _showMessage('Please select your grade.');
      return;
    }

    if (_userCategory == 'Student' && _isALGrade && _alStream == null) {
      _showMessage('Please select your A/L stream.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.completeOnboarding(
        userCategory: _userCategory!,
        gradeId: _userCategory == 'Student' ? _gradeId : null,
        school: _userCategory == 'Student'
            ? _schoolController.text.trim()
            : null,
        district: _district!,
        alStream: _userCategory == 'Student' && _isALGrade ? _alStream : null,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      } else {
        _showMessage('Unable to complete your profile. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==============================
  // UI
  // ==============================

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5B4BDB);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // LOGO
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: primaryColor,
                          size: 36,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Center(
                      child: Text(
                        'Let’s Set Up Your Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF20213A),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Center(
                      child: Text(
                        'Tell us a little about yourself to personalize '
                        'your QuizLanka AI experience.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    _sectionTitle('I am a'),

                    const SizedBox(height: 12),

                    _categoryCard(
                      title: 'Student',
                      subtitle: 'I am currently studying at school.',
                      icon: Icons.school_outlined,
                      selected: _userCategory == 'Student',
                      onTap: () {
                        setState(() {
                          _userCategory = 'Student';
                          _gradeId = null;
                          _alStream = null;
                          _errorMessage = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    _categoryCard(
                      title: 'Government Exam Candidate',
                      subtitle: 'I am preparing for government exams.',
                      icon: Icons.assignment_outlined,
                      selected: _userCategory == 'Government Exam Candidate',
                      onTap: () {
                        setState(() {
                          _userCategory = 'Government Exam Candidate';
                          _gradeId = null;
                          _alStream = null;
                          _errorMessage = null;
                        });
                      },
                    ),

                    // STUDENT FIELDS
                    if (_userCategory == 'Student') ...[
                      const SizedBox(height: 28),

                      _sectionTitle('Your Education'),

                      const SizedBox(height: 12),

                      _fieldLabel('Select Your Grade'),

                      const SizedBox(height: 8),

                      if (_loadingGrades)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          ),
                        )
                      else if (_grades.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grades could not be loaded.',
                              style: TextStyle(color: Colors.red),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loadingGrades = true;
                                  _errorMessage = null;
                                });
                                _fetchGrades();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: _gradeId,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            hint: 'Choose your grade',
                          ),
                          items: _grades
                              .map((grade) {
                                final id = int.tryParse(grade['id'].toString());

                                final name =
                                    (grade['name'] ??
                                            grade['grade_name'] ??
                                            'Grade')
                                        .toString();

                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(name),
                                );
                              })
                              .where((item) => item.value != null)
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _gradeId = value;
                              _alStream = null;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select your grade';
                            }
                            return null;
                          },
                        ),

                      // A/L STREAM
                      if (_isALGrade) ...[
                        const SizedBox(height: 20),

                        _fieldLabel('A/L Stream'),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          value: _alStream,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            hint: 'Select your A/L stream',
                          ),
                          items: _alStreams.map((stream) {
                            return DropdownMenuItem<String>(
                              value: stream['value'],
                              child: Text(stream['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _alStream = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select your A/L stream';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      _fieldLabel('School Name (Optional)'),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _schoolController,
                        decoration: _inputDecoration(
                          hint: 'Enter your school name',
                          prefixIcon: Icons.account_balance_outlined,
                        ),
                      ),
                    ],

                    // DISTRICT
                    if (_userCategory != null) ...[
                      const SizedBox(height: 24),

                      _fieldLabel('Your District'),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        value: _district,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          hint: 'Select your district',
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        items: _districts.map((district) {
                          return DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _district = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your district';
                          }
                          return null;
                        },
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 15),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // CONTINUE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _submitting ||
                                _userCategory == null ||
                                (_userCategory == 'Student' && _loadingGrades)
                            ? null
                            : _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: primaryColor.withOpacity(
                            0.4,
                          ),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Complete Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Center(
                      child: Text(
                        'You can update your profile details later.',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================
  // REUSABLE WIDGETS
  // ==============================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF20213A),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF36364A),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE5E5EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE5E5EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF5B4BDB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _categoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color(0xFF5B4BDB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFE5E5EF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? primaryColor.withOpacity(0.12)
                    : const Color(0xFFF1F1F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? primaryColor : Colors.black54,
                size: 24,
              ),
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
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF20213A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? primaryColor : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
