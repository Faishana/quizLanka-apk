// profile_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:quiz_lanka/config/api_config.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/Login.dart';

// ============================================================
// 2. MODELS  (unchanged)
// ============================================================

class GradeModel {
  final int id;
  final String name;

  GradeModel({required this.id, required this.name});

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(id: json['id'], name: json['name']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProfileModel {
  final int id;
  final String name;
  final String email;
  final String school;
  final String district;
  final String preferredMedium;
  final GradeModel grade;
  final String? avatarUrl;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.school,
    required this.district,
    required this.preferredMedium,
    required this.grade,
    this.avatarUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    school: json['school'] as String,
    district: json['district'] as String,
    preferredMedium: json['preferred_medium'] as String? ?? 'English',
    grade: GradeModel.fromJson(json['grade'] as Map<String, dynamic>),
    avatarUrl: json['profile_image'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'school': school,
    'district': district,
    'preferred_medium': preferredMedium,
    'grade_id': grade.id,
    'profile_image': avatarUrl,
  };

  ProfileModel copyWith({
    String? name,
    String? school,
    String? district,
    String? preferredMedium,
    GradeModel? grade,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email,
      school: school ?? this.school,
      district: district ?? this.district,
      preferredMedium: preferredMedium ?? this.preferredMedium,
      grade: grade ?? this.grade,
      avatarUrl: avatarUrl,
    );
  }
}

// ============================================================
// 3. PROFILE SERVICE  (updated with uploadProfilePhoto)
// ============================================================

class ProfileService {
  final http.Client _client = http.Client();

  static const List<String> districts = [
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
    'North Western Province',
    'Nuwara Eliya',
    'Polonnaruwa',
    'Puttalam',
    'Ratnapura',
    'Trincomalee',
    'Vavuniya',
  ];

  static const List<String> mediums = ['Sinhala', 'English', 'Tamil'];

  Future<ProfileModel> getProfile() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/profile'),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ProfileModel.fromJson(data['user'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to load profile');
        }
      } else if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error loading profile: $e');
    }
  }

  Future<List<GradeModel>> getGrades() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/public/grades'),
            headers: ApiConfig.getHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final gradesList = data['data'] as List<dynamic>;
          return gradesList
              .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load grades');
        }
      } else {
        throw Exception('Failed to load grades: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error loading grades: $e');
    }
  }

  Future<ProfileModel> updateProfile({
    required String name,
    required int gradeId,
    required String school,
    required String district,
    required String preferredMedium,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final body = jsonEncode({
      'name': name,
      'grade_id': gradeId,
      'school': school,
      'district': district,
      'preferred_medium': preferredMedium,
    });

    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/profile'),
            headers: {
              ...ApiConfig.getHeaders(token),
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ProfileModel.fromJson(data['user'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to update profile');
        }
      } else if (response.statusCode == 401) {
        await TokenStorage.clearAll();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final errorMessages = errors.values
              .expand((e) => e as List<dynamic>)
              .map((e) => e.toString())
              .join('\n');
          throw Exception(errorMessages);
        }
        throw Exception('Validation error');
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('The request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // NEW: Upload profile photo with Horizon queue support
  Future<void> uploadProfilePhoto(File image) async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profilePhoto}'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.files.add(await http.MultipartFile.fromPath('photo', image.path));

    final response = await request.send();

    final body = await response.stream.bytesToString();

    debugPrint('Status: ${response.statusCode}');
    debugPrint('Response: $body');

    if (response.statusCode != 200) {
      throw Exception(body);
    }
  }

  void dispose() {
    _client.close();
  }
}

// ============================================================
// 4. PALETTE — Aurora Glass tokens local to this screen.
// If appTheam.dart already exposes matching tokens (e.g.
// AppTheme.bgTop, AppTheme.cardGlass, AppTheme.textPrimary),
// swap those in here instead of the hardcoded fallbacks below
// so every screen stays driven by one source of truth.
// ============================================================
class _Palette {
  static const bgTop = Color(0xFF0E0C29);
  static const bgBottom = Color(0xFF1B1540);
  static const cardGlass = Color(0xFF1C1A3D);
  static const cardBorder = Colors.white;
  static const textPrimary = Colors.white;
  static const divider = Color(0xFF2A2854);
  static const inputFill = Color(0xFF141230);
  static const danger = Color(0xFFEF5A6C);
  static const dangerBg = Color(0xFF2E1626);
}

// ============================================================
// 5. PROFILE SCREEN
// ============================================================

class ProfileScreen extends StatefulWidget {
  final Key? key;

  const ProfileScreen({this.key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _uploadingAvatar = false;
  String? _error;

  ProfileModel? _profile;
  List<GradeModel> _grades = [];

  late TextEditingController _nameController;
  late TextEditingController _schoolController;

  GradeModel? _selectedGrade;
  String? _selectedDistrict;
  String? _selectedMedium;

  // Polling controller for avatar generation
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30; // 60 seconds max

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _schoolController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _service.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getProfile(),
        _service.getGrades(),
      ]);

      final profile = results[0] as ProfileModel;
      final grades = results[1] as List<GradeModel>;

      setState(() {
        _profile = profile;
        _grades = grades;
        _nameController.text = profile.name;
        _schoolController.text = profile.school;

        if (grades.isNotEmpty) {
          try {
            _selectedGrade = grades.firstWhere(
              (g) => g.id == profile.grade.id,
              orElse: () => grades.first,
            );
          } catch (e) {
            _selectedGrade = grades.first;
          }
        } else {
          _selectedGrade = profile.grade;
        }

        if (ProfileService.districts.contains(profile.district)) {
          _selectedDistrict = profile.district;
        } else {
          _selectedDistrict = ProfileService.districts.isNotEmpty
              ? ProfileService.districts.first
              : null;
        }

        _selectedMedium = profile.preferredMedium;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // NEW: Pick profile photo from gallery
  Future<void> _pickProfilePhoto() async {
    try {
      // Show bottom sheet with options
      final source = await _showImageSourcePicker();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _uploadingAvatar = true;
      });

      await _service.uploadProfilePhoto(File(image.path));

      // Show generating dialog
      _showGeneratingDialog();

      // Start polling for the updated profile
      _pollProfileEvery2Seconds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _Palette.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  // NEW: Show image source picker (Camera/Gallery)
  Future<ImageSource?> _showImageSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _Palette.cardGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.violet),
              title: const Text(
                'Gallery',
                style: TextStyle(color: _Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.violet),
              title: const Text(
                'Camera',
                style: TextStyle(color: _Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close, color: _Palette.danger),
              title: const Text(
                'Cancel',
                style: TextStyle(color: _Palette.danger),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // NEW: Show generating dialog
  void _showGeneratingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _Palette.cardGlass,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.violet,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Generating Avatar...',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile picture is being processed.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Poll profile every 2 seconds until avatar is ready
  void _pollProfileEvery2Seconds() {
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollAttempts++;

      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context); // Close generating dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Avatar generation is taking longer than expected. Please refresh later.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      try {
        final updatedProfile = await _service.getProfile();

        if (updatedProfile.avatarUrl != null &&
            updatedProfile.avatarUrl!.isNotEmpty &&
            updatedProfile.avatarUrl != _profile?.avatarUrl) {
          timer.cancel();

          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          setState(() {
            _profile = updatedProfile;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar generated successfully')),
          );
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }
    if (_schoolController.text.trim().isEmpty) {
      _showSnackBar('Please enter your school', isError: true);
      return;
    }
    if (_selectedGrade == null) {
      _showSnackBar('Please select your grade', isError: true);
      return;
    }
    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      _showSnackBar('Please select your district', isError: true);
      return;
    }
    if (_selectedMedium == null || _selectedMedium!.isEmpty) {
      _showSnackBar('Please select your medium', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile = await _service.updateProfile(
        name: _nameController.text.trim(),
        gradeId: _selectedGrade!.id,
        school: _schoolController.text.trim(),
        district: _selectedDistrict!,
        preferredMedium: _selectedMedium!,
      );

      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
      });

      _showSnackBar('Profile updated successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _Palette.danger : AppTheme.violet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _Palette.bgTop,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _Palette.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: _Palette.textPrimary,
        ),
      ),
      body: Stack(
        children: [
          // Aurora background — soft glow blobs over a dark gradient,
          // matching the Dashboard / Login / Onboarding visual language.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_Palette.bgTop, _Palette.bgBottom],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -60,
                    left: -40,
                    child: _GlowBlob(
                      color: AppTheme.violet.withValues(alpha: 0.28),
                      size: 220,
                    ),
                  ),
                  Positioned(
                    top: 160,
                    right: -60,
                    child: _GlowBlob(
                      color: const Color(0xFFEF5A6C).withValues(alpha: 0.16),
                      size: 200,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const _LoadingView()
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadProfile)
                : _ProfileContent(
                    profile: _profile!,
                    grades: _grades,
                    nameController: _nameController,
                    schoolController: _schoolController,
                    selectedGrade: _selectedGrade,
                    onGradeChanged: (grade) {
                      setState(() {
                        _selectedGrade = grade;
                      });
                    },
                    selectedDistrict: _selectedDistrict,
                    onDistrictChanged: (district) {
                      setState(() {
                        _selectedDistrict = district;
                      });
                    },
                    selectedMedium: _selectedMedium,
                    onMediumChanged: (medium) {
                      setState(() {
                        _selectedMedium = medium;
                      });
                    },
                    isSaving: _isSaving,
                    onSave: _saveProfile,
                    uploadingAvatar: _uploadingAvatar,
                    onAvatarTap: _pickProfilePhoto,
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Soft radial glow blob used for the aurora background
// ------------------------------------------------------------
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Loading View
// ------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.violet, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            'Loading profile…',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Error View
// ------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _Palette.dangerBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _Palette.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: _Palette.danger,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load profile',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Profile Content
// ------------------------------------------------------------
class _ProfileContent extends StatelessWidget {
  final ProfileModel profile;
  final List<GradeModel> grades;
  final TextEditingController nameController;
  final TextEditingController schoolController;
  final GradeModel? selectedGrade;
  final ValueChanged<GradeModel> onGradeChanged;
  final String? selectedDistrict;
  final ValueChanged<String> onDistrictChanged;
  final String? selectedMedium;
  final ValueChanged<String> onMediumChanged;
  final bool isSaving;
  final VoidCallback onSave;
  final bool uploadingAvatar;
  final VoidCallback onAvatarTap;

  const _ProfileContent({
    required this.profile,
    required this.grades,
    required this.nameController,
    required this.schoolController,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.selectedMedium,
    required this.onMediumChanged,
    required this.isSaving,
    required this.onSave,
    required this.uploadingAvatar,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _AvatarSection(
            name: profile.name,
            email: profile.email,
            avatarUrl: profile.avatarUrl,
            uploading: uploadingAvatar,
            onTap: onAvatarTap,
          ),
          const SizedBox(height: 20),
          _ProfileForm(
            nameController: nameController,
            schoolController: schoolController,
            grades: grades,
            selectedGrade: selectedGrade,
            onGradeChanged: onGradeChanged,
            selectedDistrict: selectedDistrict,
            onDistrictChanged: onDistrictChanged,
            selectedMedium: selectedMedium,
            onMediumChanged: onMediumChanged,
          ),
          const SizedBox(height: 24),
          _SaveButton(isSaving: isSaving, onSave: onSave),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Glass card wrapper — shared look for every section on screen
// ------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Palette.cardGlass.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.cardBorder.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------
// Avatar Section (updated with tap & loading states)
// ------------------------------------------------------------
class _AvatarSection extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;
  final bool uploading;

  const _AvatarSection({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.onTap,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: uploading ? null : onTap,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.violet, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: uploading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.violet,
                              strokeWidth: 2.5,
                            ),
                          )
                        : CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.violet.withValues(
                              alpha: 0.18,
                            ),
                            backgroundImage:
                                avatarUrl != null && avatarUrl!.isNotEmpty
                                ? NetworkImage(avatarUrl!)
                                : null,
                            child: avatarUrl == null || avatarUrl!.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.violet,
                                    ),
                                  )
                                : null,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: uploading ? Colors.grey : AppTheme.violet,
                      shape: BoxShape.circle,
                      border: Border.all(color: _Palette.cardGlass, width: 3),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: uploading ? Colors.grey[400] : Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _Palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.violet.withValues(alpha: 0.3)),
            ),
            child: Text(
              uploading ? 'Uploading...' : 'Tap to change photo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: uploading ? Colors.grey : AppTheme.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Profile Form
// ------------------------------------------------------------
class _ProfileForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController schoolController;
  final List<GradeModel> grades;
  final GradeModel? selectedGrade;
  final ValueChanged<GradeModel> onGradeChanged;
  final String? selectedDistrict;
  final ValueChanged<String> onDistrictChanged;
  final String? selectedMedium;
  final ValueChanged<String> onMediumChanged;

  const _ProfileForm({
    required this.nameController,
    required this.schoolController,
    required this.grades,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.selectedMedium,
    required this.onMediumChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _FormField(
            label: 'Name',
            icon: Icons.person_outline_rounded,
            child: TextField(
              controller: nameController,
              cursorColor: AppTheme.violet,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: TextStyle(color: Color(0xFF6B6890)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15, color: _Palette.textPrimary),
            ),
          ),
          Divider(height: 1, color: _Palette.divider),
          _FormField(
            label: 'Grade',
            icon: Icons.school_outlined,
            child: _DarkDropdown<GradeModel>(
              value: selectedGrade,
              hint: 'Select your grade',
              items: grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                  .toList(),
              onChanged: (grade) {
                if (grade != null) onGradeChanged(grade);
              },
            ),
          ),
          Divider(height: 1, color: _Palette.divider),
          _FormField(
            label: 'School',
            icon: Icons.business_outlined,
            child: TextField(
              controller: schoolController,
              cursorColor: AppTheme.violet,
              decoration: const InputDecoration(
                hintText: 'Enter your school name',
                hintStyle: TextStyle(color: Color(0xFF6B6890)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15, color: _Palette.textPrimary),
            ),
          ),
          Divider(height: 1, color: _Palette.divider),
          _FormField(
            label: 'District',
            icon: Icons.location_city_outlined,
            child: _DarkDropdown<String>(
              value: selectedDistrict,
              hint: 'Select your district',
              items: ProfileService.districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (district) {
                if (district != null) onDistrictChanged(district);
              },
            ),
          ),
          Divider(height: 1, color: _Palette.divider),
          _FormField(
            label: 'Medium',
            icon: Icons.translate_rounded,
            child: _DarkDropdown<String>(
              value: selectedMedium,
              hint: 'Select your medium',
              items: ProfileService.mediums
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (medium) {
                if (medium != null) onMediumChanged(medium);
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Dark-themed dropdown shared by Grade / District / Medium
// ------------------------------------------------------------
class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: _Palette.inputFill,
        borderRadius: BorderRadius.circular(14),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.textSecondary,
        ),
        hint: Text(
          hint,
          style: const TextStyle(color: Color(0xFF6B6890), fontSize: 15),
        ),
        style: const TextStyle(color: _Palette.textPrimary, fontSize: 15),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ------------------------------------------------------------
// Form Field row (icon + label + input)
// ------------------------------------------------------------
class _FormField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _FormField({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.violet),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Save Button — violet → blue gradient pill, matching the
// Dashboard's "Continue" call-to-action button.
// ------------------------------------------------------------
class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveButton({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isSaving
                ? [const Color(0xFF4B4870), const Color(0xFF4B4870)]
                : [AppTheme.violet, const Color(0xFF5AA6FF)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isSaving ? null : onSave,
            child: Center(
              child: isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
