// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:quiz_lanka/Login.dart';

// ============================================================
// DESIGN TOKENS — "Aurora" theme
// One consistent dark, premium background across every page;
// only the accent color, icon, and copy change per slide.
// ============================================================
class _OnboardingTokens {
  _OnboardingTokens._();

  static const Duration pageTransition = Duration(milliseconds: 420);
  static const Duration floatDuration = Duration(seconds: 4);

  static const List<Color> baseGradient = [
    Color(0xFF0B0B22),
    Color(0xFF141335),
    Color(0xFF1D1B4B),
  ];

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB9B6D9);
}

// ============================================================
// DATA MODELS
// ============================================================
class SlideFeature {
  const SlideFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class OnboardingSlideData {
  const OnboardingSlideData({
    required this.emoji,
    required this.title,
    required this.titleAccent,
    required this.description,
    required this.features,
    required this.accentColor,
    required this.ctaLabel,
  });

  final String emoji;
  final String title;
  final String titleAccent;
  final String description;
  final List<SlideFeature> features;
  final Color accentColor;
  final String ctaLabel;
}

final List<OnboardingSlideData> _slides = [
  OnboardingSlideData(
    emoji: '🧠',
    title: 'AI Powered',
    titleAccent: 'Learning',
    description:
        'Generate unlimited smart quizzes from your lessons, papers, and study materials instantly.',
    features: const [
      SlideFeature(icon: Icons.quiz_outlined, label: 'Smart Quizzes'),
      SlideFeature(icon: Icons.school_outlined, label: 'Any Subject'),
      SlideFeature(icon: Icons.bolt_outlined, label: 'Instant Feedback'),
    ],
    accentColor: const Color(0xFF9B6BFF),
    ctaLabel: 'Next',
  ),
  OnboardingSlideData(
    emoji: '⚔️',
    title: 'Challenge Friends',
    titleAccent: 'Live',
    description:
        'Play real-time quiz battles, challenge classmates, and climb the national leaderboard.',
    features: const [
      SlideFeature(icon: Icons.gamepad_outlined, label: 'Live Battles'),
      SlideFeature(icon: Icons.leaderboard_outlined, label: 'Leaderboard'),
      SlideFeature(icon: Icons.emoji_events_outlined, label: 'XP Rewards'),
    ],
    accentColor: const Color(0xFF3FB4FF),
    ctaLabel: 'Next',
  ),
  OnboardingSlideData(
    emoji: '🏆',
    title: 'Rise Through',
    titleAccent: 'The Ranks',
    description:
        'Compete with students across Sri Lanka, earn rewards, and become the top quiz champion.',
    features: const [
      SlideFeature(icon: Icons.flag_outlined, label: 'National Rank'),
      SlideFeature(
        icon: Icons.account_balance_outlined,
        label: 'School Battles',
      ),
      SlideFeature(icon: Icons.card_giftcard_outlined, label: 'Achievements'),
    ],
    accentColor: const Color(0xFFFFB020),
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

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _floatController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: _OnboardingTokens.floatDuration,
    )..repeat(reverse: true);
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
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: _OnboardingTokens.baseGradient.first,
      body: Stack(
        children: [
          // Consistent dark base + a soft glow tinted by the
          // current slide's accent color.
          AnimatedContainer(
            duration: _OnboardingTokens.pageTransition,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _OnboardingTokens.baseGradient,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: _OnboardingTokens.pageTransition,
                child: Align(
                  alignment: const Alignment(0, -0.55),
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slide.accentColor.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _TopBar(onSkip: _goToLogin),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _SlideContent(
                        key: ValueKey(index),
                        data: _slides[index],
                        floatController: _floatController,
                      );
                    },
                  ),
                ),
                _BottomBar(
                  currentPage: _currentPage,
                  pageCount: _slides.length,
                  accentColor: slide.accentColor,
                  ctaLabel: slide.ctaLabel,
                  onCtaTap: _nextPage,
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
// PRIVATE, REUSABLE WIDGETS
// ============================================================

/// Small translucent "Skip" pill pinned to the top-right corner.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onSkip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Skip',
                    style: TextStyle(
                      color: _OnboardingTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: _OnboardingTokens.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main content of a single onboarding page: a floating glass
/// orb with the slide's emoji, title, description, and feature chips.
class _SlideContent extends StatelessWidget {
  const _SlideContent({
    super.key,
    required this.data,
    required this.floatController,
  });

  final OnboardingSlideData data;
  final Animation<double> floatController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: floatController,
                builder: (context, child) {
                  final lift = (floatController.value - 0.5) * 14;
                  return Transform.translate(
                    offset: Offset(0, lift),
                    child: child,
                  );
                },
                child: _GlassOrb(
                  emoji: data.emoji,
                  accentColor: data.accentColor,
                ),
              ),
              const SizedBox(height: 40),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${data.title} ',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: _OnboardingTokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: data.titleAccent,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: data.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _OnboardingTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: data.features
                    .map(
                      (f) => _FeatureChip(
                        feature: f,
                        accentColor: data.accentColor,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glowing glass-morphic circle housing the slide's emoji.
class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.emoji, required this.accentColor});

  final String emoji;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.35),
            blurRadius: 44,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
    );
  }
}

/// Small translucent pill showing one feature icon + label.
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.feature, required this.accentColor});

  final SlideFeature feature;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(feature.icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Text(
            feature.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _OnboardingTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom bar: animated page dots + a full-width gradient CTA
/// button that advances the PageView or navigates to LoginScreen.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.pageCount,
    required this.accentColor,
    required this.ctaLabel,
    required this.onCtaTap,
  });

  final int currentPage;
  final int pageCount;
  final Color accentColor;
  final String ctaLabel;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: currentPage == index ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: currentPage == index
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ctaLabel,
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
        ],
      ),
    );
  }
}
