import 'dart:ui';

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const List<Color> backgroundGradient = [
    Color(0xFF0B0B22),
    Color(0xFF141335),
    Color(0xFF1D1B4B),
  ];

  static const Color violet = Color(0xFF9B6BFF);
  static const Color cyan = Color(0xFF3FB4FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB9B6D9);
  static const Color success = Color(0xFF3FE0A0);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF7A7A);

  static const double cardRadius = 20;

  static BoxDecoration glassCard({double radius = cardRadius}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    );
  }
}