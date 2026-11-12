// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/QL.dart';

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
    required this.heroIcon,
    required this.floatingIcons,
    required this.titlePlain,
    required this.titleAccent,
    required this.description,
    required this.features,
    required this.ctaLabel,
  });

  final IconData heroIcon;
  final List<IconData> floatingIcons; // exactly 3
  final String titlePlain;
  final String titleAccent;
  final String description;
  final List<SlideFeature> features;
  final String ctaLabel;
}

const List<OnboardingSlideData> _slides = [
  OnboardingSlideData(
    heroIcon: Icons.psychology_alt_rounded,
    floatingIcons: [
      Icons.menu_book_rounded,
      Icons.calculate_rounded,
      Icons.bolt_rounded,
    ],
    titlePlain: 'AI Powered',
    titleAccent: 'Learning',
    description:
        'Generate unlimited smart quizzes from your lessons, papers, and study materials instantly.',
    features: [
      SlideFeature(
        icon: Icons.fact_check_rounded,
        label: 'Smart Quiz\nGeneration',
      ),
      SlideFeature(
        icon: Icons.auto_stories_rounded,
        label: 'Any Subject\nAny Level',
      ),
      SlideFeature(icon: Icons.bolt_rounded, label: 'Instant\nFeedback'),
    ],
    ctaLabel: 'Next',
  ),
  OnboardingSlideData(
    heroIcon: Icons.sports_esports_rounded,
    floatingIcons: [
      Icons.groups_rounded,
      Icons.timer_rounded,
      Icons.emoji_events_rounded,
    ],
    titlePlain: 'Challenge Friends',
    titleAccent: 'Live',
    description:
        'Play real-time quiz battles, challenge classmates, and climb the national leaderboard.',
    features: [
      SlideFeature(
        icon: Icons.videogame_asset_rounded,
        label: 'Real-time\nQuiz Battles',
      ),
      SlideFeature(
        icon: Icons.bar_chart_rounded,
        label: 'National\nLeaderboard',
      ),
      SlideFeature(
        icon: Icons.emoji_events_rounded,
        label: 'Win & Earn\nXP Rewards',
      ),
    ],
    ctaLabel: 'Next',
  ),
  OnboardingSlideData(
    heroIcon: Icons.workspace_premium_rounded,
    floatingIcons: [
      Icons.trending_up_rounded,
      Icons.school_rounded,
      Icons.star_rounded,
    ],
    titlePlain: 'Rise Through',
    titleAccent: 'The Ranks',
    description:
        'Compete with students across Sri Lanka, earn rewards, and become the top quiz champion.',
    features: [
      SlideFeature(
        icon: Icons.emoji_events_rounded,
        label: 'National\nRankings',
      ),
      SlideFeature(
        icon: Icons.account_balance_rounded,
        label: 'School\nCompetitions',
      ),
      SlideFeature(
        icon: Icons.card_giftcard_rounded,
        label: 'Rewards &\nAchievements',
      ),
      SlideFeature(
        icon: Icons.trending_up_rounded,
        label: 'Track Your\nProgress',
      ),
    ],
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    await QLPrefs.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QL.navy,
        body: Stack(
          children: [
            const Positioned.fill(child: QLBackdrop()),
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const QLBrandMark(size: 36, fontSize: 17),
                          if (!isLast)
                            TextButton(
                              onPressed: _goToLogin,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(64, 44),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => _SlideBody(data: _slides[i]),
                  ),
                ),
                _BottomCard(
                  data: _slides[_currentPage],
                  currentPage: _currentPage,
                  pageCount: _slides.length,
                  onCtaTap: _nextPage,
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
// HERO ILLUSTRATION (pure Flutter, no image assets needed)
// ============================================================
class _SlideBody extends StatelessWidget {
  const _SlideBody({required this.data});

  final OnboardingSlideData data;

  Widget _bubble(IconData icon) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: QL.navyLight,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Icon(icon, color: Colors.white, size: 26),
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 280,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: QL.navyLight.withValues(alpha: 0.55),
                  ),
                ),
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    color: QL.gold,
                    borderRadius: BorderRadius.circular(38),
                    boxShadow: [
                      BoxShadow(
                        color: QL.gold.withValues(alpha: 0.30),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(data.heroIcon, size: 70, color: QL.navy),
                ),
                Align(
                  alignment: const Alignment(-0.95, -0.7),
                  child: _bubble(data.floatingIcons[0]),
                ),
                Align(
                  alignment: const Alignment(0.97, -0.25),
                  child: _bubble(data.floatingIcons[1]),
                ),
                Align(
                  alignment: const Alignment(-0.6, 0.95),
                  child: _bubble(data.floatingIcons[2]),
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
// WHITE BOTTOM CARD (title, text, features, button, dots)
// ============================================================
class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.data,
    required this.currentPage,
    required this.pageCount,
    required this.onCtaTap,
  });

  final OnboardingSlideData data;
  final int currentPage;
  final int pageCount;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(QL.cardRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(currentPage),
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${data.titlePlain} ',
                        style: const TextStyle(color: QL.ink),
                      ),
                      TextSpan(
                        text: data.titleAccent,
                        style: const TextStyle(color: QL.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: QL.muted,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final f in data.features) _FeatureItem(feature: f),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          QLPrimaryButton(label: data.ctaLabel, onTap: onCtaTap),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: currentPage == i ? QL.blue : QL.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.feature});

  final SlideFeature feature;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, color: QL.blue, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            feature.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: QL.ink,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
