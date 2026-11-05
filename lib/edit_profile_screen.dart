// ============================================================
// EDIT PROFILE SCREEN
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quiz_lanka/ProfileScreen.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;
  final List<CategoryModel> categories;
  final List<GradeModel> allGrades;

  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.categories,
    required this.allGrades,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _uploadingAvatar = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _schoolController;

  CategoryModel? _selectedCategory;
  GradeModel? _selectedGrade;
  String? _selectedStream;
  String? _selectedDistrict;
  String? _selectedMedium;

  List<GradeModel> _filteredGrades = [];

  bool get _isGovCandidate => widget.profile.isGovernmentExamCandidate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _schoolController = TextEditingController(
      text: widget.profile.school ?? '',
    );

    final catValue =
        widget.profile.gradeCategory ?? widget.profile.grade?.category;
    _selectedCategory = catValue != null
        ? widget.categories.firstWhere(
            (c) => c.value == catValue,
            orElse: () => widget.categories.isNotEmpty
                ? widget.categories.first
                : CategoryModel(value: catValue, text: catValue),
          )
        : null;

    _filteredGrades = _selectedCategory != null
        ? widget.allGrades
              .where((g) => g.category == _selectedCategory!.value)
              .toList()
        : List<GradeModel>.from(widget.allGrades);

    _selectedGrade = widget.profile.grade != null
        ? _filteredGrades.firstWhere(
            (g) => g.id == widget.profile.grade!.id,
            orElse: () => widget.profile.grade!,
          )
        : null;

    _selectedStream = _matchStream(widget.profile.alStream);

    // FIX: reconcile the district against the known list so the dropdown
    // never receives a value it can't find among its items.
    _selectedDistrict = _matchDistrict(widget.profile.district);

    _selectedMedium = _matchMedium(widget.profile.preferredMedium);
  }

  // ----------------------------------------------------------------
  // Value reconciliation helpers — keep the dropdown from crashing
  // when the server sends a string that doesn't exactly match one of
  // our canonical options.
  // ----------------------------------------------------------------

  String? _matchDistrict(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (ProfileService.districts.contains(trimmed)) return trimmed;
    final norm = trimmed.toLowerCase();
    for (final d in ProfileService.districts) {
      if (d.trim().toLowerCase() == norm) return d;
    }
    return null; // user will be prompted to re-select
  }

  String? _matchMedium(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (ProfileService.mediums.contains(trimmed)) return trimmed;
    final norm = trimmed.toLowerCase();
    for (final m in ProfileService.mediums) {
      if (m.trim().toLowerCase() == norm) return m;
    }
    return null;
  }

  String? _matchStream(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    for (final s in AlStreamOption.all) {
      if (s.value == trimmed) return trimmed;
      if (s.text.trim().toLowerCase() == trimmed.toLowerCase()) {
        return s.value;
      }
    }
    // Fall back to whatever was stored, but only if it will still
    // match an item — otherwise let the user re-pick.
    return AlStreamOption.all.any((s) => s.value == trimmed) ? trimmed : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _onCategoryChanged(CategoryModel? cat) {
    if (cat == null) return;
    setState(() {
      _selectedCategory = cat;
      _selectedGrade = null;
      _selectedStream = null;
      _filteredGrades = widget.allGrades
          .where((g) => g.category == cat.value)
          .toList();
    });
  }

  void _onGradeChanged(GradeModel? grade) {
    setState(() {
      _selectedGrade = grade;
      if (grade == null || !grade.isAdvancedLevel) {
        _selectedStream = null;
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }
    if (!_isGovCandidate) {
      if (_selectedCategory == null) {
        _showSnackBar('Please select your education category', isError: true);
        return;
      }
      if (_selectedGrade == null) {
        _showSnackBar('Please select your grade', isError: true);
        return;
      }
      if (_selectedGrade!.isAdvancedLevel &&
          (_selectedStream == null || _selectedStream!.isEmpty)) {
        _showSnackBar('Please select your A/L stream', isError: true);
        return;
      }
      if (_schoolController.text.trim().isEmpty) {
        _showSnackBar('Please enter your school', isError: true);
        return;
      }
      if (_selectedMedium == null || _selectedMedium!.isEmpty) {
        _showSnackBar('Please select your medium', isError: true);
        return;
      }
    }
    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      _showSnackBar('Please select your district', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final isAl = _selectedGrade?.isAdvancedLevel ?? false;
      final updated = await _service.updateProfile(
        name: _nameController.text.trim(),
        gradeId: _isGovCandidate ? null : _selectedGrade?.id,
        gradeCategory: _isGovCandidate ? null : _selectedCategory?.value,
        alStream: (_isGovCandidate || !isAl) ? null : _selectedStream,
        school: _isGovCandidate ? null : _schoolController.text.trim(),
        district: _selectedDistrict,
        preferredMedium: _isGovCandidate ? null : _selectedMedium,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final source = await _showImageSourcePicker();
      if (source == null) return;
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;

      setState(() => _uploadingAvatar = true);
      await _service.uploadProfilePhoto(File(image.path));
      if (mounted) {
        _showSnackBar('Photo uploaded. Avatar will be generated shortly.');
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<ImageSource?> _showImageSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Palette.cardGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: Palette.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Palette.neonCyan,
              ),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Palette.neonCyan,
              ),
              title: const Text(
                'Camera',
                style: TextStyle(color: Palette.textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Palette.danger),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Palette.danger),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Palette.danger : Palette.neonViolet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bgTop,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                TopHeader(
                  onBack: () => Navigator.maybePop(context),
                  onSettings: () {},
                  onNotifications: () {},
                  title: 'Edit Profile',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: _EditableAvatar(
                            avatarUrl: widget.profile.avatarUrl,
                            name: _nameController.text.isNotEmpty
                                ? _nameController.text
                                : widget.profile.name,
                            uploading: _uploadingAvatar,
                            onTap: _pickProfilePhoto,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileForm(
                          nameController: _nameController,
                          schoolController: _schoolController,
                          categories: widget.categories,
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: _onCategoryChanged,
                          grades: _filteredGrades,
                          selectedGrade: _selectedGrade,
                          onGradeChanged: _onGradeChanged,
                          selectedStream: _selectedStream,
                          onStreamChanged: (s) =>
                              setState(() => _selectedStream = s),
                          selectedDistrict: _selectedDistrict,
                          onDistrictChanged: (d) =>
                              setState(() => _selectedDistrict = d),
                          selectedMedium: _selectedMedium,
                          onMediumChanged: (m) =>
                              setState(() => _selectedMedium = m),
                          isGovCandidate: _isGovCandidate,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Palette.dangerBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Palette.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Palette.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Palette.danger,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _SaveButton(isSaving: _isSaving, onSave: _saveProfile),
                      ],
                    ),
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

// ------------------------------------------------------------
// Editable avatar (small circle w/ camera overlay)
// ------------------------------------------------------------
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.avatarUrl,
    required this.name,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 108,
            height: 108,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Palette.neonCyan,
                  Palette.neonViolet,
                  Palette.neonPink,
                  Palette.neonCyan,
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.bgMid,
              ),
              child: ClipOval(
                child: uploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Palette.neonCyan,
                          strokeWidth: 2.5,
                        ),
                      )
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => AvatarInitial(name: name),
                      )
                    : AvatarInitial(name: name),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.neonCyan, Palette.neonViolet],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Palette.bgMid, width: 3),
              ),
              child: Icon(
                uploading
                    ? Icons.hourglass_top_rounded
                    : Icons.camera_alt_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Edit-profile form — Category → Grade → Stream
// ------------------------------------------------------------
class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.nameController,
    required this.schoolController,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.grades,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.selectedStream,
    required this.onStreamChanged,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.selectedMedium,
    required this.onMediumChanged,
    required this.isGovCandidate,
  });

  final TextEditingController nameController;
  final TextEditingController schoolController;
  final List<CategoryModel> categories;
  final CategoryModel? selectedCategory;
  final ValueChanged<CategoryModel?> onCategoryChanged;
  final List<GradeModel> grades;
  final GradeModel? selectedGrade;
  final ValueChanged<GradeModel?> onGradeChanged;
  final String? selectedStream;
  final ValueChanged<String?> onStreamChanged;
  final String? selectedDistrict;
  final ValueChanged<String> onDistrictChanged;
  final String? selectedMedium;
  final ValueChanged<String> onMediumChanged;
  final bool isGovCandidate;

  @override
  Widget build(BuildContext context) {
    final showStream =
        !isGovCandidate &&
        selectedGrade != null &&
        selectedGrade!.isAdvancedLevel;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          FormFieldRow(
            label: 'Name',
            icon: Icons.person_outline_rounded,
            child: TextField(
              controller: nameController,
              cursorColor: Palette.neonCyan,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: TextStyle(color: Palette.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15, color: Palette.textPrimary),
            ),
          ),

          if (!isGovCandidate) ...[
            const Divider(height: 1, color: Palette.cardBorder),
            FormFieldRow(
              label: 'Category',
              icon: Icons.category_outlined,
              child: DarkDropdown<CategoryModel>(
                value: selectedCategory,
                hint: 'Select education category',
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.text)))
                    .toList(),
                onChanged: onCategoryChanged,
              ),
            ),
            const Divider(height: 1, color: Palette.cardBorder),
            FormFieldRow(
              label: 'Grade',
              icon: Icons.school_outlined,
              child: DarkDropdown<GradeModel>(
                value: selectedGrade,
                hint: selectedCategory == null
                    ? 'Select category first'
                    : 'Select your grade',
                items: grades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: selectedCategory == null ? null : onGradeChanged,
              ),
            ),
            if (showStream) ...[
              const Divider(height: 1, color: Palette.cardBorder),
              FormFieldRow(
                label: 'Stream',
                icon: Icons.account_tree_outlined,
                child: DarkDropdown<String>(
                  value: selectedStream,
                  hint: 'Select A/L stream',
                  items: AlStreamOption.all
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.value,
                          child: Text(s.text),
                        ),
                      )
                      .toList(),
                  onChanged: onStreamChanged,
                ),
              ),
            ],
            const Divider(height: 1, color: Palette.cardBorder),
            FormFieldRow(
              label: 'School',
              icon: Icons.business_outlined,
              child: TextField(
                controller: schoolController,
                cursorColor: Palette.neonCyan,
                decoration: const InputDecoration(
                  hintText: 'Enter your school name',
                  hintStyle: TextStyle(color: Palette.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Palette.textPrimary,
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: Palette.cardBorder),
          FormFieldRow(
            label: 'District',
            icon: Icons.location_city_outlined,
            child: DarkDropdown<String>(
              value: selectedDistrict,
              hint: 'Select your district',
              items: ProfileService.districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (d) {
                if (d != null) onDistrictChanged(d);
              },
            ),
          ),

          if (!isGovCandidate) ...[
            const Divider(height: 1, color: Palette.cardBorder),
            FormFieldRow(
              label: 'Medium',
              icon: Icons.translate_rounded,
              child: DarkDropdown<String>(
                value: selectedMedium,
                hint: 'Select your medium',
                items: ProfileService.mediums
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (m) {
                  if (m != null) onMediumChanged(m);
                },
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Save button
// ------------------------------------------------------------
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onSave});
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isSaving
                ? const [Color(0xFF4B4870), Color(0xFF4B4870)]
                : const [Palette.neonViolet, Palette.neonCyan],
          ),
          boxShadow: isSaving
              ? []
              : [
                  BoxShadow(
                    color: Palette.neonViolet.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
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
