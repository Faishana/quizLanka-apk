import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/OnboardingScreen.dart';
import 'package:quiz_lanka/main_navigation.dart';

// ============================================================
// DESIGN TOKENS — "Bright Campus" theme
// A light, friendly, EdTech-app aesthetic instead of the dark
// cinematic look. All values used by the widget tree live here.
// ============================================================
class _SplashTokens {
  _SplashTokens._();

  static const Duration entranceDuration = Duration(milliseconds: 1200);
  static const Duration orbitDuration = Duration(seconds: 14);
  static const Duration dotsDuration = Duration(milliseconds: 1100);
  static const Duration minimumDisplay = Duration(milliseconds: 2200);

  static const List<Color> backgroundGradient = [
    Color(0xFFF7F5FF),
    Color(0xFFEFEAFE),
    Color(0xFFE7E2FB),
  ];

  static const Color primary = Color(0xFF5B3DF5);
  static const Color ink = Color(0xFF201A3D);
  static const Color inkSoft = Color(0xFF6B6485);

  static const List<Color> logoGradient = [Colors.white, Colors.white];

  static const String logoAsset = 'assets/Logo.png';

  static const double logoSize = 118;
  static const double orbitRadius = 118;
  static const double brandFontSize = 32;
}

class _OrbitIcon {
  const _OrbitIcon(this.icon, this.color, this.angleOffset, this.scale);
  final IconData icon;
  final Color color;
  final double angleOffset; // radians, starting position on the orbit
  final double scale;
}

const List<_OrbitIcon> _orbitIcons = [
  _OrbitIcon(Icons.calculate_rounded, Color(0xFFFF7A59), 0.0, 1.0),
  _OrbitIcon(Icons.science_rounded, Color(0xFF22C1A6), math.pi / 2, 0.9),
  _OrbitIcon(Icons.public_rounded, Color(0xFF3B82F6), math.pi, 1.0),
  _OrbitIcon(Icons.menu_book_rounded, Color(0xFFF5B637), 3 * math.pi / 2, 0.9),
];

// ============================================================
// SPLASH SCREEN — alternate design
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _orbitController;
  late final AnimationController _dotsController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: _SplashTokens.entranceDuration,
    )..forward();

    _orbitController = AnimationController(
      vsync: this,
      duration: _SplashTokens.orbitDuration,
    )..repeat();

    _dotsController = AnimationController(
      vsync: this,
      duration: _SplashTokens.dotsDuration,
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _navigateNext();
  }

  /// Identical behavior to the original: check the stored token, then
  /// route to MainNavigation or Onboarding. The auth check and the minimum
  /// splash display time run concurrently, and a failed check safely
  /// falls back to onboarding instead of crashing the splash screen.
  Future<void> _navigateNext() async {
    bool hasToken = false;

    try {
      final results = await Future.wait<dynamic>([
        TokenStorage.hasToken(),
        Future.delayed(_SplashTokens.minimumDisplay),
      ]);
      hasToken = results[0] as bool;
    } catch (_) {
      hasToken = false;
    }

    if (!mounted) return;

    // ✅ Step 2: Updated to use MainNavigation instead of DashboardScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            hasToken ? const MainNavigation() : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _orbitController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SplashTokens.backgroundGradient.first,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _SplashTokens.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Semantics(
            label: 'QuizLanka AI is loading',
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Logo + orbiting subject icons
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: _OrbitingLogo(orbitController: _orbitController),
                  ),
                ),

                const SizedBox(height: 44),

                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: const _BrandBlock(),
                  ),
                ),

                const Spacer(flex: 3),

                FadeTransition(
                  opacity: _textFade,
                  child: _PulsingDots(controller: _dotsController),
                ),

                const SizedBox(height: 12),

                FadeTransition(
                  opacity: _textFade,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 28),
                    child: Text(
                      'Powered by AI · Built for Sri Lankan Students',
                      style: TextStyle(
                        fontSize: 12,
                        color: _SplashTokens.inkSoft,
                        letterSpacing: 0.2,
                      ),
                    ),
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
// PRIVATE, REUSABLE WIDGETS
// ============================================================

/// Central logo card with four subject icons slowly orbiting around it.
class _OrbitingLogo extends StatelessWidget {
  const _OrbitingLogo({required this.orbitController});

  final Animation<double> orbitController;

  @override
  Widget build(BuildContext context) {
    const double fieldSize =
        _SplashTokens.logoSize + (_SplashTokens.orbitRadius * 2) + 56;

    return SizedBox(
      width: fieldSize,
      height: fieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: orbitController,
            builder: (context, _) {
              final angle = orbitController.value * 2 * math.pi;
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (final orbitIcon in _orbitIcons)
                    _buildOrbitingIcon(angle, orbitIcon),
                ],
              );
            },
          ),
          _LogoBadge(),
        ],
      ),
    );
  }

  Widget _buildOrbitingIcon(double angle, _OrbitIcon orbitIcon) {
    final theta = angle + orbitIcon.angleOffset;
    final dx = math.cos(theta) * _SplashTokens.orbitRadius;
    final dy = math.sin(theta) * _SplashTokens.orbitRadius;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: orbitIcon.scale,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: orbitIcon.color.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(orbitIcon.icon, color: orbitIcon.color, size: 22),
        ),
      ),
    );
  }
}

/// The rounded gradient badge at the center of the orbit, now showing
/// the actual app logo image instead of a generic icon.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SplashTokens.logoSize,
      height: _SplashTokens.logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _SplashTokens.logoGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: _SplashTokens.primary.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ClipOval(
          child: Image.asset(
            _SplashTokens.logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback in case the asset is missing or not yet
              // registered in pubspec.yaml, so the splash screen
              // never crashes because of a missing image.
              return const Icon(
                Icons.auto_awesome_rounded,
                size: 52,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wordmark + tagline, styled for a light background.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'QuizLanka ',
                style: TextStyle(
                  fontSize: _SplashTokens.brandFontSize,
                  fontWeight: FontWeight.w900,
                  color: _SplashTokens.ink,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(
                  fontSize: _SplashTokens.brandFontSize,
                  fontWeight: FontWeight.w900,
                  color: _SplashTokens.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Smarter practice. Better ranks.',
          style: TextStyle(
            fontSize: 15,
            color: _SplashTokens.inkSoft,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Three dots pulsing in sequence — a lighter-weight alternative
/// to a progress bar for a short, fixed-length wait.
class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = ((controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + (math.sin(t * math.pi).abs() * 0.6);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: _SplashTokens.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
