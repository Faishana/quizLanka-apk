// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:quiz_lanka/Login.dart';

// ============================================================
// ASSETS
// Add these to pubspec.yaml:
//
// flutter:
//   assets:
//     - assets/onborad_1.png
//     - assets/onborad_2.png
//     - assets/onborad_3.png
//
// Place the 3 background PNGs you uploaded at that exact path.
// ============================================================

// ============================================================
// DESIGN TOKENS
// ============================================================
class _OnboardingTokens {
  _OnboardingTokens._();

  static const Duration pageTransition = Duration(milliseconds: 420);

  static const Color titleDark = Color(0xFF241F5A);
  static const Color descColor = Color(0xFF6B6B85);
  static const Color dotInactive = Color(0xFFE1DFF2);
}

// ============================================================
// DATA MODELS
// ============================================================
class SlideFeature {
  const SlideFeature({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
}

class OnboardingSlideData {
  const OnboardingSlideData({
    required this.bgImage,
   // required this.badgeIcon,
    required this.badgeColor,
    required this.titlePlain,
    required this.titleAccent,
    required this.titleAccentColor,
    required this.description,
    required this.features,
    required this.ctaColors,
    required this.ctaLabel,
  });

  final String bgImage;
  // final IconData badgeIcon;
  final Color badgeColor;
  final String titlePlain;
  final String titleAccent;
  final Color titleAccentColor;
  final String description;
  final List<SlideFeature> features;
  final List<Color> ctaColors;
  final String ctaLabel;
}

final List<OnboardingSlideData> _slides = [
  // Slide 1 — matches onborad_1.png background ("AI Powered Learning")
  OnboardingSlideData(
    bgImage: 'assets/onborad_1.png',
    // badgeIcon: Icons.psychology_alt_rounded,
    badgeColor: const Color(0xFF6C4CF1),
    titlePlain: 'AI Powered',
    titleAccent: 'Learning',
    titleAccentColor: const Color(0xFF3B6CFF),
    description:
        'Generate unlimited smart quizzes from your lessons, papers, and study materials instantly.',
    features: const [
      SlideFeature(
        icon: Icons.fact_check_rounded,
        label: 'Smart Quiz\nGeneration',
        color: Color(0xFF7C5CFF),
      ),
      SlideFeature(
        icon: Icons.auto_stories_rounded,
        label: 'Any Subject\nAny Level',
        color: Color(0xFF3B6CFF),
      ),
      SlideFeature(
        icon: Icons.bolt_rounded,
        label: 'Instant\nFeedback',
        color: Color(0xFF7C5CFF),
      ),
    ],
    ctaColors: const [Color(0xFF5B4CF0), Color(0xFF3B6CFF)],
    ctaLabel: 'Next',
  ),

  // Slide 2 — matches onborad_2.png background ("Challenge Friends Live")
  OnboardingSlideData(
    bgImage: 'assets/onborad_2.png',
   // badgeIcon: Icons.sports_esports_rounded,
    badgeColor: const Color(0xFF6C4CF1),
    titlePlain: 'Challenge Friends',
    titleAccent: 'Live',
    titleAccentColor: const Color(0xFF3B6CFF),
    description:
        'Play real-time quiz battles, challenge classmates, and climb the national leaderboard.',
    features: const [
      SlideFeature(
        icon: Icons.videogame_asset_rounded,
        label: 'Real-time\nQuiz Battles',
        color: Color(0xFF3B6CFF),
      ),
      SlideFeature(
        icon: Icons.bar_chart_rounded,
        label: 'National\nLeaderboard',
        color: Color(0xFFFFA726),
      ),
      SlideFeature(
        icon: Icons.emoji_events_rounded,
        label: 'Win & Earn\nXP Rewards',
        color: Color(0xFF7C5CFF),
      ),
    ],
    ctaColors: const [Color(0xFF5B4CF0), Color(0xFF3B6CFF)],
    ctaLabel: 'Next',
  ),

  // Slide 3 — matches onborad_3.png background ("Rise Through The Ranks")
  OnboardingSlideData(
    bgImage: 'assets/onborad_3.png',
   // badgeIcon: Icons.workspace_premium_rounded,
    badgeColor: const Color(0xFF6C4CF1),
    titlePlain: 'Rise Through',
    titleAccent: 'The Ranks',
    titleAccentColor: const Color(0xFF3B6CFF),
    description:
        'Compete with students across Sri Lanka, earn rewards, and become the top quiz champion.',
    features: const [
      SlideFeature(
        icon: Icons.emoji_events_rounded,
        label: 'National\nRankings',
        color: Color(0xFFFFA726),
      ),
      SlideFeature(
        icon: Icons.account_balance_rounded,
        label: 'School\nCompetitions',
        color: Color(0xFF3B6CFF),
      ),
      SlideFeature(
        icon: Icons.card_giftcard_rounded,
        label: 'Rewards &\nAchievements',
        color: Color(0xFF7C5CFF),
      ),
      SlideFeature(
        icon: Icons.trending_up_rounded,
        label: 'Track Your\nProgress',
        color: Color(0xFF2ECC71),
      ),
    ],
    ctaColors: const [Color(0xFF5B4CF0), Color(0xFF3B6CFF)],
    ctaLabel: 'Get Started',
  ),
];

// ============================================================
// ONBOARDING SCREEN
// ============================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: _OnboardingTokens.pageTransition,
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              final isLast = index == _slides.length - 1;
              return _SlidePage(
                data: _slides[index],
                currentPage: _currentPage,
                pageCount: _slides.length,
                onCtaTap: _nextPage,
                onSkip: _goToLogin,
                showSkip: !isLast,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SINGLE SLIDE PAGE
// ============================================================
class _SlidePage extends StatelessWidget {
  const _SlidePage({
    required this.data,
    required this.currentPage,
    required this.pageCount,
    required this.onCtaTap,
    required this.onSkip,
    required this.showSkip,
  });

  final OnboardingSlideData data;
  final int currentPage;
  final int pageCount;
  final VoidCallback onCtaTap;
  final VoidCallback onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Full-bleed background illustration
        Positioned.fill(
          child: Image.asset(
            data.bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) {
              return const ColoredBox(
                color: Colors.white,
                child: Center(child: Icon(Icons.broken_image, size: 80)),
              );
            },
          ),
        ),

        // Skip button
        if (showSkip)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: GestureDetector(
                  onTap: onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Skip',
                          style: TextStyle(
                            color: _OnboardingTokens.titleDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: _OnboardingTokens.titleDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // White info card pinned to the bottom, overlapping the
        // fade-out area of the background image.
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight * 0.42),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),

              // ============================================================
              // UPDATED GLASSMORPHIC CARD WITH LOWER OPACITY (65%)
              // ============================================================
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.65,
                ), // Changed from 0.85 to 0.65
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),

              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // // Badge icon square
                    // Container(
                    //   width: 56,
                    //   height: 56,
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withValues(alpha: 0.9),
                    //     borderRadius: BorderRadius.circular(16),
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: Colors.black.withValues(alpha: 0.05),
                    //         blurRadius: 10,
                    //       ),
                    //     ],
                    //   ),
                    //   // child: Icon(
                    //   // //  data.badgeIcon,
                    //   //   color: data.badgeColor,
                    //   //   size: 28,
                    //   // ),
                    // ),
                    // const SizedBox(height: 18),

                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${data.titlePlain} ',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _OnboardingTokens.titleDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          TextSpan(
                            text: data.titleAccent,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: data.titleAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Text(
                      data.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: _OnboardingTokens.descColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 16,
                      children: data.features
                          .map((f) => _FeatureItem(feature: f))
                          .toList(),
                    ),
                    const SizedBox(height: 26),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onCtaTap,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: data.ctaColors,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data.ctaLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pageCount,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentPage == index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentPage == index
                                ? data.titleAccentColor
                                : _OnboardingTokens.dotInactive,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// FEATURE ITEM
// ============================================================
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.feature});

  final SlideFeature feature;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            feature.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _OnboardingTokens.titleDark,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
