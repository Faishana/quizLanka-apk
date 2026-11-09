import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// QuizLanka shared design system (navy + gold, same as Login)
// Put this file at: lib/ql_design.dart
// ============================================================
class QL {
  QL._();

  static const Color navy = Color(0xFF12306B);
  static const Color navyDeep = Color(0xFF0D2658);
  static const Color navyLight = Color(0xFF1B4296);
  static const Color gold = Color(0xFFF5B323);
  static const Color blue = Color(0xFF1E4FD8);
  static const Color ink = Color(0xFF12244A);
  static const Color muted = Color(0xFF4A5878);
  static const Color hint = Color(0xFF66718C);
  static const Color border = Color(0xFFC9D2E6);
  static const Color fieldFill = Color(0xFFF7F9FD);
  static const Color ice = Color(0xFFDCE6FF);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerBg = Color(0xFFFDECEA);

  static const double fieldRadius = 14;
  static const double cardRadius = 28;
}

// ============================================================
// Small persisted flag: has the intro been seen already?
// ============================================================
class QLPrefs {
  QLPrefs._();
  static const String _onboardingSeenKey = 'onboarding_seen';

  static Future<bool> onboardingSeen() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_onboardingSeenKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboardingSeenKey, true);
  }
}

// ============================================================
// Backdrop: navy gradient + soft circles + faint subject icons
// ============================================================
class QLBackdrop extends StatelessWidget {
  const QLBackdrop({super.key});

  Widget _icon(IconData i, double size, double alpha) => Icon(
    i,
    size: size,
    color: Colors.white.withValues(alpha: alpha),
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [QL.navy, QL.navyDeep],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                color: QL.navyLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: -90,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: QL.navyLight.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: 28,
            child: _icon(Icons.menu_book_rounded, 44, 0.10),
          ),
          Positioned(
            top: 250,
            right: 70,
            child: _icon(Icons.calculate_rounded, 34, 0.08),
          ),
          Positioned(
            top: 205,
            left: 24,
            child: _icon(Icons.science_rounded, 30, 0.08),
          ),
          Positioned(
            top: 60,
            left: 150,
            child: _icon(Icons.public_rounded, 28, 0.07),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Brand mark (gold badge + wordmark)
// ============================================================
class QLBrandMark extends StatelessWidget {
  const QLBrandMark({super.key, this.size = 44, this.fontSize = 20});

  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: QL.gold,
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Icon(Icons.school_rounded, color: QL.navy, size: size * 0.6),
        ),
        SizedBox(width: size * 0.23),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: -0.3,
            ),
            children: const [
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
      ],
    );
  }
}

// ============================================================
// Auth layout: navy header on top, white sheet filling the rest.
// Scrolls when the keyboard opens. Used by Register.
// ============================================================
class QLAuthLayout extends StatefulWidget {
  const QLAuthLayout({super.key, required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  State<QLAuthLayout> createState() => _QLAuthLayoutState();
}

class _QLAuthLayoutState extends State<QLAuthLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<double>(
      begin: 32,
      end: 0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: QL.navy,
        body: Stack(
          children: [
            const Positioned.fill(child: QLBackdrop()),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, child) => Opacity(
                          opacity: _fade.value,
                          child: Transform.translate(
                            offset: Offset(0, _slide.value),
                            child: child,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            widget.header,
                            const SizedBox(height: 22),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24 + bottomInset,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(QL.cardRadius),
                                  ),
                                ),
                                child: widget.child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
// Form pieces
// ============================================================
InputDecoration qlFieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(QL.fieldRadius),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: QL.hint, fontSize: 14.5),
    prefixIcon: Icon(icon, color: QL.muted, size: 20),
    suffixIcon: suffix,
    errorStyle: const TextStyle(
      color: QL.danger,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: QL.fieldFill,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: border(QL.border, 1.5),
    focusedBorder: border(QL.blue, 2),
    errorBorder: border(QL.danger, 1.5),
    focusedErrorBorder: border(QL.danger, 2),
  );
}

const TextStyle qlInputStyle = TextStyle(
  fontSize: 15,
  color: QL.ink,
  fontWeight: FontWeight.w500,
);

class QLFieldLabel extends StatelessWidget {
  const QLFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: QL.ink,
    ),
  );
}

class QLErrorBanner extends StatelessWidget {
  const QLErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: QL.dangerBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: QL.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: QL.danger,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QLPrimaryButton extends StatelessWidget {
  const QLPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: (isLoading || !enabled) ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: QL.blue,
          disabledBackgroundColor: QL.blue.withValues(
            alpha: isLoading ? 0.75 : 0.4,
          ),
          disabledForegroundColor: Colors.white,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(QL.fieldRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}
