// settings_screen.dart
// ============================================================
// 1. IMPORTS
// ============================================================
import 'package:flutter/material.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/ProfileScreen.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 2. SETTINGS SCREEN — simplified to essential settings only,
// redesigned UI, identical persistence/logout/profile logic
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// ✅ Step 4: Added AutomaticKeepAliveClientMixin
class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _language);
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageSelector(
        currentLanguage: _language,
        onLanguageSelected: (language) {
          setState(() {
            _language = language;
            _saveSettings();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConfirmDialog(
        title: 'Logout',
        message: 'Are you sure you want to logout?',
        confirmLabel: 'Logout',
        confirmColor: AppTheme.danger,
        onConfirm: () => _logout(context),
      ),
    );
  }

  void _logout(BuildContext context) async {
    try {
      await TokenStorage.clearAll();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        backgroundColor: const Color(0xFF201E4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _AboutDialog(),
    );
  }

  // ✅ Step 2: Removed _handleBack() method completely

  @override
  bool get wantKeepAlive => true; // ✅ Step 4: Keep page alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Step 5: Call super.build

    // ✅ Steps 1 & 3: Import removed, bottom bar removed
    return Scaffold(
      backgroundColor: AppTheme.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.backgroundGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ✅ Step 6: Updated TopBar with inline back logic
              _TopBar(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      _SettingsSection(
                        title: 'Account',
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline_rounded,
                            title: 'My Profile',
                            onTap: _navigateToProfile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Preferences',
                        children: [
                          _SettingsTile(
                            icon: Icons.language_rounded,
                            title: 'Language',
                            trailing: _language,
                            onTap: _showLanguageSelector,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'Support',
                        children: [
                          _SettingsTile(
                            icon: Icons.help_outline_rounded,
                            title: 'Help Center',
                            onTap: () => _showComingSoon('Help Center'),
                          ),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () => _showComingSoon('Privacy Policy'),
                          ),
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            onTap: () => _showComingSoon('Terms & Conditions'),
                          ),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            title: 'About QuizLanka AI',
                            onTap: _showAbout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _LogoutButton(onTap: _showLogoutDialog),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 3. TOP BAR
// ============================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: Icon(
                // ✅ Step 7: Updated icon to show settings icon when no back
                canPop
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.settings_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. SETTINGS SECTION
// ============================================================
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: AppTheme.glassCard(radius: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 5. SETTINGS TILE
// ============================================================
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.violet, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. LOGOUT BUTTON
// ============================================================
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppTheme.danger, size: 22),
                SizedBox(width: 10),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

// ============================================================
// 7. CONFIRM DIALOG (used for Logout)
// ============================================================
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF201E4A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context, true);
                    onConfirm();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: confirmColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 8. ABOUT DIALOG
// ============================================================
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF201E4A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppTheme.violet,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'QuizLanka AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI-powered quiz platform for Sri Lankan students.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _aboutItem(Icons.email_rounded, 'info@codehubsoftware.com'),
            const SizedBox(height: 8),
            _aboutItem(Icons.web_rounded, 'www.quizlanka.lk'),
            const SizedBox(height: 8),
            _aboutItem(Icons.people_rounded, 'Developed by QuizLanka Team'),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.violet,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ============================================================
// 9. LANGUAGE SELECTOR
// ============================================================
class _LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const _LanguageSelector({
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  final List<Map<String, String>> _languages = const [
    {'name': 'English', 'code': 'en'},
    {'name': 'Sinhala', 'code': 'si'},
    {'name': 'Tamil', 'code': 'ta'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF14132F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ..._languages.map((lang) {
            final isSelected = lang['name'] == currentLanguage;
            return InkWell(
              onTap: () => onLanguageSelected(lang['name']!),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.violet
                              : Colors.white.withValues(alpha: 0.24),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.violet,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      lang['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.violet
                            : AppTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
