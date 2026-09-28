// settings_screen.dart
// ============================================================
// REDESIGN NOTES
// ============================================================
// Restyled to the same LIGHT theme as the redesigned ProfileScreen
// (soft lavender-white surfaces, glass cards, violet/cyan accents).
// All persistence/logout/navigation LOGIC is unchanged:
//   - language load/save via SharedPreferences
//   - quiz language load/save via SharedPreferences
//   - logout via TokenStorage.clearAll() + navigation reset
//   - navigation to ProfileScreen
//   - About dialog content
//   - AutomaticKeepAliveClientMixin behaviour
//
// THEME SOURCE: the original file pulled colors from `AppTheme`
// (appTheam.dart) mixed with hardcoded dark surfaces (0xFF201E4A,
// 0xFF14132F, white-opacity borders) — that combination is what was
// producing the dark look. Since I don't have access to appTheam.dart
// to know what's already defined there, this version defines its own
// self-contained `_Palette` (same values as ProfileScreen's) instead.
// If appTheam.dart already has matching light tokens, prefer wiring
// those in here — and ideally extract one shared `_Palette`/`AppTheme`
// used by both screens rather than duplicating it per-file.
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/ProfileScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// PALETTE — kept identical to ProfileScreen's light palette so
// both screens feel like the same app. TODO: move this into a
// shared theme file (e.g. appTheam.dart) instead of duplicating
// it in every screen.
// ============================================================
class _Palette {
  static const bgTop = Color(0xFFF3FAFF);
  static const bgMid = Color(0xFFE8F4FD);

  static const cardGlass = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE7E4F6);

  static const textPrimary = Color(0xFF1E1B3A);
  static const textSecondary = Color(0xFF6B6890);
  static const textMuted = Color(0xFF9490B8);

  static const neonCyan = Color(0xFF15AEDB);
  static const neonViolet = Color(0xFF7C5CFF);

  static const danger = Color(0xFFE0435F);
  static const dangerBg = Color(0xFFFCE7EC);
}

// ============================================================
// SETTINGS SCREEN — same state/logic as the original file.
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  String _language = 'English';
  String _quizLanguage = 'si'; // Default: Sinhala

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'English';
      _quizLanguage = prefs.getString('quiz_language') ?? 'si';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _language);
    await prefs.setString('quiz_language', _quizLanguage);
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

  void _showQuizLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuizLanguageSelector(
        currentQuizLanguage: _quizLanguage,
        onQuizLanguageSelected: (quizLanguage) {
          setState(() {
            _quizLanguage = quizLanguage;
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
        confirmColor: _Palette.danger,
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
            backgroundColor: _Palette.danger,
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
        backgroundColor: _Palette.neonViolet,
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Get display name for quiz language
    String getQuizLanguageDisplay() {
      switch (_quizLanguage) {
        case 'en':
          return 'English';
        case 'si':
          return 'Sinhala';
        case 'ta':
          return 'Tamil';
        default:
          return 'Sinhala';
      }
    }

    return Scaffold(
      backgroundColor: _Palette.bgTop,
      body: Stack(
        children: [
          const Positioned.fill(child: _SettingsBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                          title: 'App Preferences',
                          children: [
                            _SettingsTile(
                              icon: Icons.language_rounded,
                              title: 'App Language',
                              trailing: _language,
                              onTap: _showLanguageSelector,
                            ),
                            _SettingsTile(
                              icon: Icons.quiz_rounded,
                              title: 'Quiz Language',
                              trailing: getQuizLanguageDisplay(),
                              onTap: _showQuizLanguageSelector,
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
                              onTap: () =>
                                  _showComingSoon('Terms & Conditions'),
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
                              color: _Palette.textMuted,
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
        ],
      ),
    );
  }
}

// ============================================================
// BACKGROUND — same light wash + optional bg image as
// ProfileScreen, kept subtler here since this is a utility screen.
// ============================================================
class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.10,
            child: Image.asset(
              'assets/profile_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
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
                  _Palette.neonCyan.withValues(alpha: 0.10),
                  _Palette.bgMid.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TOP BAR
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
                color: _Palette.cardGlass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: _Palette.neonViolet.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                canPop
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.settings_rounded,
                color: _Palette.textPrimary,
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
              color: _Palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GLASS CARD — shared visual language with ProfileScreen
// ============================================================
class _GlassCard extends StatelessWidget {
  // ignore: unused_element_parameter
  const _GlassCard({required this.child, this.padding, this.radius = 16});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: _Palette.cardGlass.withValues(alpha: 0.85),
            border: Border.all(color: _Palette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: _Palette.neonViolet.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// SETTINGS SECTION
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
              color: _Palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, color: _Palette.cardBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SETTINGS TILE
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
                color: _Palette.neonViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _Palette.neonViolet, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _Palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: _Palette.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: _Palette.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGOUT BUTTON
// ============================================================
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Palette.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.danger.withValues(alpha: 0.3)),
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
                Icon(Icons.logout_rounded, color: _Palette.danger, size: 22),
                SizedBox(width: 10),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: _Palette.danger,
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
// CONFIRM DIALOG (used for Logout)
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
          color: _Palette.cardGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
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
                color: _Palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: _Palette.textSecondary,
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
                    foregroundColor: _Palette.textSecondary,
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
// ABOUT DIALOG
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
          color: _Palette.cardGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
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
                    color: _Palette.neonViolet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: _Palette.neonViolet,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'QuizLanka AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: _Palette.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: _Palette.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI-powered quiz platform for Sri Lankan students.',
              style: TextStyle(
                color: _Palette.textSecondary,
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
                  foregroundColor: _Palette.neonViolet,
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
        Icon(icon, size: 16, color: _Palette.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: _Palette.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ============================================================
// LANGUAGE SELECTOR (App Language)
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
        color: _Palette.cardGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select App Language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _Palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'UI language for buttons and settings',
            style: TextStyle(fontSize: 13, color: _Palette.textSecondary),
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
                              ? _Palette.neonViolet
                              : _Palette.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: _Palette.neonViolet,
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
                            ? _Palette.neonViolet
                            : _Palette.textPrimary,
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
                foregroundColor: _Palette.textSecondary,
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

// ============================================================
// QUIZ LANGUAGE SELECTOR (Quiz Generation Language)
// ============================================================
class _QuizLanguageSelector extends StatelessWidget {
  final String currentQuizLanguage;
  final Function(String) onQuizLanguageSelected;

  const _QuizLanguageSelector({
    required this.currentQuizLanguage,
    required this.onQuizLanguageSelected,
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
        color: _Palette.cardGlass,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Quiz Language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _Palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Language in which AI generates quiz questions',
            style: TextStyle(fontSize: 13, color: _Palette.textSecondary),
          ),
          const SizedBox(height: 16),
          ..._languages.map((lang) {
            final isSelected = lang['code'] == currentQuizLanguage;
            return InkWell(
              onTap: () => onQuizLanguageSelected(lang['code']!),
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
                              ? _Palette.neonViolet
                              : _Palette.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: _Palette.neonViolet,
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
                            ? _Palette.neonViolet
                            : _Palette.textPrimary,
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
                foregroundColor: _Palette.textSecondary,
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
