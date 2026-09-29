import 'package:flutter/material.dart';
import 'package:quiz_lanka/PastPaperListScreen.dart';

class PastPaperLanguageSelectionScreen extends StatelessWidget {
  final int subjectId;
  final String subjectName;
  final String category;

  const PastPaperLanguageSelectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.category,
  });

  static const Color violet = Color(0xFF7C3AED);
  static const Color violetDeep = Color(0xFF4C1D95);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color gold = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    violet.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blue.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      30,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        _buildHero(),

                        const SizedBox(height: 28),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Choose Language',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF181B34),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select the language of the past paper you want to practice.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7086),
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        _LanguageCard(
                          language: 'Sinhala',
                          subtitle: 'සිංහල මාධ්‍ය',
                          code: 'si',
                          icon: Icons.translate_rounded,
                          colors: const [
                            Color(0xFF7C3AED),
                            Color(0xFF9333EA),
                          ],
                          onTap: () => _openPastPapers(
                            context,
                            'si',
                          ),
                        ),

                        const SizedBox(height: 14),

                        _LanguageCard(
                          language: 'English',
                          subtitle: 'English Medium',
                          code: 'en',
                          icon: Icons.language_rounded,
                          colors: const [
                            Color(0xFF2563EB),
                            Color(0xFF1D4ED8),
                          ],
                          onTap: () => _openPastPapers(
                            context,
                            'en',
                          ),
                        ),

                        const SizedBox(height: 14),

                        _LanguageCard(
                          language: 'Tamil',
                          subtitle: 'தமிழ் माध्यमம்',
                          code: 'ta',
                          icon: Icons.translate_rounded,
                          colors: const [
                            Color(0xFF0F766E),
                            Color(0xFF14B8A6),
                          ],
                          onTap: () => _openPastPapers(
                            context,
                            'ta',
                          ),
                        ),

                        const SizedBox(height: 26),

                        _buildInfoCard(),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFDCE7F7),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF181B34),
                size: 21,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Past Papers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF181B34),
                  ),
                ),
                Text(
                  subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7086),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            violetDeep,
            violet,
            blue,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: violet.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Past Paper Practice',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subjectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Choose your preferred medium',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFDCE7F7),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: blue,
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Past papers will be shown based on the selected language. '
              'Some questions may include diagrams or images.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7086),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPastPapers(
    BuildContext context,
    String medium,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PastPaperListScreen(
          subjectId: subjectId,
          subjectName: subjectName,
          category: category,
          medium: medium,
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String language;
  final String subtitle;
  final String code;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.subtitle,
    required this.code,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDCE7F7),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10232B6B),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF181B34),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7086),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.first.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code.toUpperCase(),
                style: TextStyle(
                  color: colors.first,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}