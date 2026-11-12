import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/OnboardingScreen.dart';
import 'package:quiz_lanka/QL.dart';
import 'package:quiz_lanka/main_navigation.dart';
import 'package:quiz_lanka/user_onboarding_screen.dart'
    show UserOnboardingScreen;

// ============================================================
// Splash timing / sizes
// ============================================================
class _SplashTokens {
  _SplashTokens._();

  static const Duration entranceDuration = Duration(milliseconds: 1600);
  static const Duration orbitDuration = Duration(seconds: 16);
  static const Duration pulseDuration = Duration(milliseconds: 2400);
  static const Duration twinkleDuration = Duration(seconds: 5);
  static const Duration shimmerDuration = Duration(milliseconds: 2600);

  /// How long the splash stays on screen (was 2.2 s).
  static const Duration minimumDisplay = Duration(milliseconds: 3800);

  static const double logoSize = 96;
  static const double innerOrbitRadius = 108;
  static const double outerOrbitRadius = 140;
}

class _OrbitIcon {
  const _OrbitIcon(this.icon, this.color, this.angleOffset);
  final IconData icon;
  final Color color;
  final double angleOffset;
}

const List<_OrbitIcon> _orbitIcons = [
  _OrbitIcon(Icons.calculate_rounded, Colors.white, 0.0),
  _OrbitIcon(Icons.science_rounded, QL.gold, math.pi / 2),
  _OrbitIcon(Icons.public_rounded, Colors.white, math.pi),
  _OrbitIcon(Icons.menu_book_rounded, QL.gold, 3 * math.pi / 2),
];

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  late final AnimationController _twinkle;
  late final AnimationController _shimmer;
  late final AnimationController _progress;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _footerFade;
  late final Animation<double> _pulseCurve;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: _SplashTokens.entranceDuration,
    )..forward();

    _orbit = AnimationController(
      vsync: this,
      duration: _SplashTokens.orbitDuration,
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: _SplashTokens.pulseDuration,
    )..repeat(reverse: true);

    _twinkle = AnimationController(
      vsync: this,
      duration: _SplashTokens.twinkleDuration,
    )..repeat();

    _shimmer = AnimationController(
      vsync: this,
      duration: _SplashTokens.shimmerDuration,
    )..repeat();

    _progress = AnimationController(
      vsync: this,
      duration: _SplashTokens.minimumDisplay,
    )..forward();

    _pulseCurve = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _ringFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _footerFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    _navigateNext();
  }

  /// Decides where to go while the minimum splash time runs.
  ///  - saved token + profile incomplete -> profile setup
  ///  - saved token                      -> main app
  ///  - no token, intro already seen     -> login
  ///  - first launch                     -> intro slides
  Future<Widget> _resolveStart() async {
    final auth = context.read<AuthProvider>();

    // Initialize authentication and fetch fresh profile from Laravel.
    await auth.init();

    if (!mounted) return const OnboardingScreen();

    // No valid authenticated user.
    if (!auth.isAuthenticated) {
      return const OnboardingScreen();
    }

    // Only show profile onboarding if the latest user data says so.
    if (auth.user?.needsOnboarding == true) {
      return const UserOnboardingScreen();
    }

    return const MainNavigation();
  }

  Future<void> _navigateNext() async {
    Widget next = const OnboardingScreen();

    try {
      final results = await Future.wait<dynamic>([
        _resolveStart(),
        Future.delayed(_SplashTokens.minimumDisplay),
      ]);
      next = results[0] as Widget;
    } catch (_) {
      // Any storage error: fall back to the intro instead of crashing.
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _orbit.dispose();
    _pulse.dispose();
    _twinkle.dispose();
    _shimmer.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QL.navyDeep,
        body: Stack(
          children: [
            // ── Background: gradient + soft glow + twinkling stars ──
            const Positioned.fill(child: _SplashBackground()),
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(painter: _StarPainter(_twinkle)),
                ),
              ),
            ),

            // ── Content ──
            SafeArea(
              child: Semantics(
                label: 'QuizLanka AI is loading',
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _logoFade,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: _OrbitingLogo(
                                    orbit: _orbit,
                                    pulse: _pulseCurve,
                                    ringFade: _ringFade,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SlideTransition(
                                position: _textSlide,
                                child: FadeTransition(
                                  opacity: _textFade,
                                  child: _BrandBlock(shimmer: _shimmer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _footerFade,
                      child: _LoadingBar(progress: _progress),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _footerFade,
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 28),
                        child: Text(
                          'Powered by AI · Built for Sri Lankan Students',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB9C6E8),
                            letterSpacing: 0.2,
                          ),
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
    );
  }
}

// ============================================================
// Background: navy gradient with a soft light behind the logo
// ============================================================
class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF173A82), QL.navy, QL.navyDeep],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.85,
                  colors: [
                    QL.navyLight.withValues(alpha: 0.55),
                    QL.navyLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QL.navyLight.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QL.navyLight.withValues(alpha: 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Twinkling stars
// ============================================================
class _Star {
  const _Star(this.dx, this.dy, this.radius, this.phase, this.speed, this.gold);
  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final int speed; // whole number so the loop is seamless
  final bool gold;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static final List<_Star> _stars = _makeStars();

  static List<_Star> _makeStars() {
    final r = math.Random(11);
    return List.generate(
      44,
      (_) => _Star(
        r.nextDouble(),
        r.nextDouble(),
        0.8 + r.nextDouble() * 1.6,
        r.nextDouble(),
        1 + r.nextInt(3),
        r.nextInt(5) == 0,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in _stars) {
      final wave = math.sin(math.pi * (t.value * s.speed + s.phase)).abs();
      final alpha = 0.12 + 0.7 * wave * wave;
      paint.color = (s.gold ? QL.gold : Colors.white).withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => false;
}

// ============================================================
// Logo with glow, two orbits and floating subject icons
// ============================================================
class _OrbitingLogo extends StatelessWidget {
  const _OrbitingLogo({
    required this.orbit,
    required this.pulse,
    required this.ringFade,
  });

  final Animation<double> orbit;
  final Animation<double> pulse;
  final Animation<double> ringFade;

  @override
  Widget build(BuildContext context) {
    const double field = _SplashTokens.outerOrbitRadius * 2 + 28;

    return SizedBox(
      width: field,
      height: field,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // pulsing golden glow
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final p = pulse.value;
              return Container(
                width: 200 + 30 * p,
                height: 200 + 30 * p,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      QL.gold.withValues(alpha: 0.20 + 0.12 * p),
                      QL.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              );
            },
          ),

          // orbit rings
          FadeTransition(
            opacity: ringFade,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ring(_SplashTokens.innerOrbitRadius, 0.16),
                _ring(_SplashTokens.outerOrbitRadius, 0.08),
              ],
            ),
          ),

          // outer ring: small dots travelling the other way
          AnimatedBuilder(
            animation: orbit,
            builder: (_, __) {
              final angle = -orbit.value * 2 * math.pi * 1.5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    _dot(angle + i * 2 * math.pi / 3, i == 0),
                ],
              );
            },
          ),

          // inner ring: subject icons
          AnimatedBuilder(
            animation: orbit,
            builder: (_, __) {
              final angle = orbit.value * 2 * math.pi;
              return Stack(
                alignment: Alignment.center,
                children: [for (final o in _orbitIcons) _orbiting(angle, o)],
              );
            },
          ),

          // logo badge, gently floating
          AnimatedBuilder(
            animation: pulse,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (pulse.value - 0.5) * 10),
              child: child,
            ),
            child: const _LogoBadge(),
          ),
        ],
      ),
    );
  }

  Widget _ring(double radius, double alpha) => Container(
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: alpha),
        width: 1.5,
      ),
    ),
  );

  Widget _dot(double theta, bool gold) {
    return Transform.translate(
      offset: Offset(
        math.cos(theta) * _SplashTokens.outerOrbitRadius,
        math.sin(theta) * _SplashTokens.outerOrbitRadius,
      ),
      child: Container(
        width: gold ? 10 : 7,
        height: gold ? 10 : 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gold ? QL.gold : Colors.white.withValues(alpha: 0.75),
          boxShadow: gold
              ? [
                  BoxShadow(
                    color: QL.gold.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _orbiting(double angle, _OrbitIcon o) {
    final theta = angle + o.angleOffset;
    return Transform.translate(
      offset: Offset(
        math.cos(theta) * _SplashTokens.innerOrbitRadius,
        math.sin(theta) * _SplashTokens.innerOrbitRadius,
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: QL.navyLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: o.color == QL.gold
                ? QL.gold.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(o.icon, color: o.color, size: 22),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SplashTokens.logoSize,
      height: _SplashTokens.logoSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCB45), QL.gold],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: QL.gold.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.school_rounded, size: 54, color: QL.navy),
    );
  }
}

// ============================================================
// Wordmark with a light sheen sweeping across it
// ============================================================
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.percent);
  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: shimmer,
          builder: (_, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.65),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradientTransform(shimmer.value * 3.0 - 1.5),
            ).createShader(bounds),
            child: child,
          ),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: 'QuizLanka ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'AI',
                  style: TextStyle(color: QL.gold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Smarter practice. Better ranks.',
          style: TextStyle(
            fontSize: 15,
            color: QL.ice,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TagChip(label: 'Grade 5'),
            SizedBox(width: 8),
            _TagChip(label: 'O/L'),
            SizedBox(width: 8),
            _TagChip(label: 'A/L'),
            SizedBox(width: 8),
            _TagChip(label: 'Govt Exams'),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// Loading bar that fills over the splash time + status text
// ============================================================
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});

  final Animation<double> progress;

  String _message(double p) {
    if (p < 0.35) return 'Preparing your learning space';
    if (p < 0.70) return 'Loading subjects and past papers';
    return 'Almost ready';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        final p = Curves.easeInOut.transform(progress.value);
        final message = _message(progress.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 190,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.14)),
                    FractionallySizedBox(
                      widthFactor: p.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFCB45), QL.gold],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                message,
                key: ValueKey(message),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: QL.ice,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
