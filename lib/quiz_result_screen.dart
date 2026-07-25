// lib/quiz_result_screen.dart
// QuizLanka AI — Quiz Result Screen
// "Aurora Glass" theme (see bottombar.dart), elevated for more visual polish:
//   - staggered fade/slide entrance for hero → stats → details → actions
//   - custom animated gradient glow-ring instead of a flat progress ring
//   - decorative watermark + bounce-in grade icon badge on the hero card
//   - glowing icon chips + count-up numbers on stat cards
//   - gradient CTA button for the primary action
// Self-contained: models + UI in one file (no network calls — data is passed in)
// Same public API and data logic as before — only presentation changed.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quiz_lanka/config/appTheam.dart';
import 'package:quiz_lanka/quiz_review_screen.dart'; // Make sure this import is correct

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class QuizResultScreen extends StatefulWidget {
  final int quizId;
  final Map<String, dynamic> resultData;
  final String subjectName;
  final Color subjectColor;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.resultData,
    required this.subjectName,
    required this.subjectColor,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroAnim;
  late final Animation<double> _badgeAnim;
  late final Animation<double> _statsAnim;
  late final Animation<double> _detailAnim;
  late final Animation<double> _actionsAnim;
  late final Animation<double> _ringAnim;

  // ── Safely extract fields from different possible response shapes ──
  double get _percentage {
    final v =
        widget.resultData['percentage'] ??
        widget.resultData['score_percentage'] ??
        widget.resultData['result']?['percentage'];
    return (v as num?)?.toDouble() ?? 0.0;
  }

  int get _correct {
    final v =
        widget.resultData['correct_answers'] ??
        widget.resultData['correct'] ??
        widget.resultData['result']?['correct_answers'];
    return (v as num?)?.toInt() ?? 0;
  }

  int get _wrong {
    final v =
        widget.resultData['wrong_answers'] ??
        widget.resultData['wrong'] ??
        widget.resultData['result']?['wrong_answers'];
    return (v as num?)?.toInt() ?? 0;
  }

  int get _total {
    final v =
        widget.resultData['total_questions'] ??
        widget.resultData['total'] ??
        widget.resultData['result']?['total_questions'];
    return (v as num?)?.toInt() ?? (_correct + _wrong);
  }

  String get _duration {
    final v =
        widget.resultData['duration'] ??
        widget.resultData['time_taken'] ??
        widget.resultData['result']?['duration'];
    if (v == null) return '—';
    return v.toString();
  }

  String get _grade {
    if (_percentage >= 75) return 'Excellent';
    if (_percentage >= 50) return 'Good';
    if (_percentage >= 35) return 'Average';
    return 'Needs Work';
  }

  Color get _gradeColor {
    if (_percentage >= 75) return AppTheme.success;
    if (_percentage >= 50) return AppTheme.cyan;
    if (_percentage >= 35) return AppTheme.warning;
    return AppTheme.danger;
  }

  IconData get _gradeIcon {
    if (_percentage >= 75) return Icons.emoji_events_rounded;
    if (_percentage >= 50) return Icons.thumb_up_rounded;
    if (_percentage >= 35) return Icons.trending_up_rounded;
    return Icons.flag_rounded;
  }

  bool get _isCelebration => _percentage >= 75;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _heroAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _ringAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    );
    _badgeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOutBack),
    );
    _statsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _detailAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
    );
    _actionsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B22),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppTheme.backgroundGradient,
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -50,
            child: _GlowOrb(color: widget.subjectColor, size: 210),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _GlowOrb(color: _gradeColor, size: 200),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _FadeSlideIn(
                    animation: _heroAnim,
                    offsetY: 28,
                    child: _buildHeroCard(),
                  ),
                  const SizedBox(height: 20),
                  _FadeSlideIn(
                    animation: _statsAnim,
                    offsetY: 24,
                    child: _buildStatsRow(),
                  ),
                  const SizedBox(height: 20),
                  _FadeSlideIn(
                    animation: _detailAnim,
                    offsetY: 24,
                    child: _buildDetailCard(),
                  ),
                  const SizedBox(height: 32),
                  _FadeSlideIn(
                    animation: _actionsAnim,
                    offsetY: 20,
                    child: _buildActions(context),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.subjectColor,
              widget.subjectColor.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: widget.subjectColor.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative oversized watermark icon for depth/premium feel.
            Positioned(
              right: -22,
              top: -18,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            if (_isCelebration) ...[
              Positioned(
                left: 14,
                top: 10,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                left: 40,
                top: 34,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
            Column(
              children: [
                const Text(
                  '🎉 Quiz Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subjectName,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (context, _) {
                    final animatedPct = _percentage * _ringAnim.value;
                    return SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(150, 150),
                            painter: _GlowRingPainter(
                              progress: (animatedPct / 100).clamp(0.0, 1.0),
                              strokeWidth: 11,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${animatedPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ScaleTransition(
                                scale: _badgeAnim,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _gradeIcon,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _grade,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: _correct,
            label: 'Correct',
            icon: Icons.check_circle_rounded,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _wrong,
            label: 'Wrong',
            icon: Icons.cancel_rounded,
            color: AppTheme.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _total,
            label: 'Total',
            icon: Icons.quiz_outlined,
            color: AppTheme.cyan,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(radius: 18),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTheme.violet, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Quiz Details',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Time Taken',
            value: _duration,
            iconColor: AppTheme.cyan,
          ),
          Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
          _DetailRow(
            icon: Icons.school_outlined,
            label: 'Subject',
            value: widget.subjectName,
            iconColor: widget.subjectColor,
          ),
          Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
          _DetailRow(
            icon: Icons.bar_chart_rounded,
            label: 'Score',
            value: '$_correct / $_total',
            iconColor: AppTheme.violet,
          ),
          Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
          _DetailRow(
            icon: Icons.emoji_events_outlined,
            label: 'Performance',
            value: _grade,
            valueColor: _gradeColor,
            iconColor: _gradeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Review Answers — gradient glow CTA
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppTheme.violet, AppTheme.cyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.violet.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(quizId: widget.quizId),
                    ),
                  );
                },
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Review Answers',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back to Dashboard
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_outlined, size: 20),
            label: const Text('Back to Dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ANIMATION HELPERS
// ─────────────────────────────────────────────

/// Fades + slides a child up into place as [animation] runs 0→1.
/// Opacity is clamped since some curves (e.g. easeOutBack) overshoot.
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({
    required this.animation,
    required this.child,
    this.offsetY = 24,
  });

  final Animation<double> animation;
  final Widget child;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value.clamp(0.0, 1.0)) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Gradient progress ring with a soft outer glow and a bright "handle"
/// dot at the current progress angle — used on the hero result card.
class _GlowRingPainter extends CustomPainter {
  final double progress; // 0..1
  final double strokeWidth;

  _GlowRingPainter({required this.progress, required this.strokeWidth});

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweepFull = 2 * math.pi;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, sweepFull, false, trackPaint);

    if (progress <= 0) return;
    final sweep = sweepFull * progress;

    // Soft blurred glow behind the progress arc
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, _start, sweep, false, glowPaint);

    // Crisp progress arc on top
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, sweep, false, progressPaint);

    // Bright handle dot at the tip of the arc
    final angle = _start + sweep;
    final handleCenter = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final handleGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(handleCenter, strokeWidth * 0.9, handleGlow);
    final handlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(handleCenter, strokeWidth * 0.55, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      decoration: AppTheme.glassCard(radius: 16),
      child: Column(
        children: [
          // Top accent bar
          Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return Text(
                '$animatedValue',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft blurred color orb used purely for background depth/atmosphere.
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
