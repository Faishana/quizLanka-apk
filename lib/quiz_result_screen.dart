// lib/quiz_result_screen.dart
// QuizLanka AI — Quiz Result Screen (Light Theme)
// + Time Taken now comes from Laravel's `duration_seconds`.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quiz_lanka/quiz_review_screen.dart';

// ─────────────────────────────────────────────
// LIGHT THEME TOKENS
// ─────────────────────────────────────────────
class _ResultTheme {
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE4E7F0);
  static const Color borderStrong = Color(0xFFCBD1E0);

  static const Color textPrimary = Color(0xFF1A1D2B);
  static const Color textSecondary = Color(0xFF5A6072);
  static const Color textMuted = Color(0xFF8A90A2);

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF0891B2);
  static const Color violet = Color(0xFF6C4DFF);
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class QuizResultScreen extends StatefulWidget {
  final int quizId;
  final Map<String, dynamic> resultData;
  final String subjectName;
  final Color subjectColor;

  /// Live duration from backend (`duration_seconds`).
  /// Falls back to whatever the payload contains if not provided.
  final int durationSeconds;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.resultData,
    required this.subjectName,
    required this.subjectColor,
    this.durationSeconds = 0,
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

  // ── Field extractors ──────────────────────────────────────
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

  /// Prefer the explicit `durationSeconds` passed from the quiz screen
  /// (which comes from the Laravel `duration_seconds` response field).
  /// Fall back to any legacy string/number fields in `resultData`.
  String get _duration {
    if (widget.durationSeconds > 0) {
      return _formatDuration(widget.durationSeconds);
    }

    final raw =
        widget.resultData['duration_seconds'] ??
        widget.resultData['duration'] ??
        widget.resultData['time_taken'] ??
        widget.resultData['result']?['duration_seconds'];

    if (raw is num) {
      return _formatDuration(raw.toInt());
    }
    if (raw is String && raw.isNotEmpty) return raw;
    return '—';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String get _grade {
    if (_percentage >= 75) return 'Excellent';
    if (_percentage >= 50) return 'Good';
    if (_percentage >= 35) return 'Average';
    return 'Needs Work';
  }

  Color get _gradeColor {
    if (_percentage >= 75) return _ResultTheme.success;
    if (_percentage >= 50) return _ResultTheme.cyan;
    if (_percentage >= 35) return _ResultTheme.warning;
    return _ResultTheme.danger;
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
      backgroundColor: _ResultTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              color: widget.subjectColor.withValues(alpha: 0.18),
              size: 260,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _GlowOrb(
              color: _gradeColor.withValues(alpha: 0.14),
              size: 260,
            ),
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
                  const SizedBox(height: 18),
                  _FadeSlideIn(
                    animation: _statsAnim,
                    offsetY: 24,
                    child: _buildStatsRow(),
                  ),
                  const SizedBox(height: 18),
                  _FadeSlideIn(
                    animation: _detailAnim,
                    offsetY: 24,
                    child: _buildDetailCard(),
                  ),
                  const SizedBox(height: 28),
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

  // ─────────────────────────────────────────────
  // HERO CARD
  // ─────────────────────────────────────────────
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
              widget.subjectColor.withValues(alpha: 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.subjectColor.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: widget.subjectColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -22,
              top: -18,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.10),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
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
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
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

  // ─────────────────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: _correct,
            label: 'Correct',
            icon: Icons.check_circle_rounded,
            color: _ResultTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _wrong,
            label: 'Wrong',
            icon: Icons.cancel_rounded,
            color: _ResultTheme.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _total,
            label: 'Total',
            icon: Icons.quiz_outlined,
            color: _ResultTheme.cyan,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // DETAIL CARD
  // ─────────────────────────────────────────────
  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ResultTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ResultTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D2B).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ResultTheme.violet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: _ResultTheme.violet,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quiz Details',
                style: TextStyle(
                  color: _ResultTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Time Taken',
            value: _duration,
            iconColor: _ResultTheme.cyan,
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Icons.school_outlined,
            label: 'Subject',
            value: widget.subjectName,
            iconColor: widget.subjectColor,
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Icons.bar_chart_rounded,
            label: 'Score',
            value: '$_correct / $_total',
            iconColor: _ResultTheme.violet,
          ),
          const _RowDivider(),
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

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [_ResultTheme.violet, _ResultTheme.cyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _ResultTheme.violet.withValues(alpha: 0.32),
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
                          letterSpacing: 0.2,
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_outlined, size: 20),
            label: const Text('Back to Dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ResultTheme.textPrimary,
              backgroundColor: _ResultTheme.surface,
              side: const BorderSide(
                color: _ResultTheme.borderStrong,
                width: 1.4,
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

class _GlowRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _GlowRingPainter({required this.progress, required this.strokeWidth});

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweepFull = 2 * math.pi;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, sweepFull, false, trackPaint);

    if (progress <= 0) return;
    final sweep = sweepFull * progress;

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, _start, sweep, false, glowPaint);

    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, sweep, false, progressPaint);

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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: _ResultTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ResultTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D2B).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return Text(
                '$animatedValue',
                style: const TextStyle(
                  color: _ResultTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _ResultTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
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
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: _ResultTheme.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? _ResultTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(height: 1, color: _ResultTheme.border),
    );
  }
}

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
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
