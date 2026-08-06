// bottombar.dart
// ============================================================
// Shared bottom navigation bar + theme tokens for every main
// screen (Dashboard, Subjects, Leaderboard, History, Settings).
//
// USAGE — in MainNavigation:
//   bottomNavigationBar: AppBottomNav(
//     currentTab: _currentTab,
//     onChanged: _onTabChanged,
//   ),
//
// FIX: the bar used to float with side margins + full rounding,
// so on devices where the bottom safe-area inset (gesture bar)
// differs from the fixed 16px padding it was given, the phone's
// background showed through at the rounded corners underneath.
// It's now edge-to-edge with only the TOP corners rounded, and
// its bottom padding is sized from the device's actual inset via
// MediaQuery instead of a hardcoded number — so it always sits
// flush with the real bottom edge on any Android phone.
//
// THEME UPDATE: switched from the dark "Aurora Glass" bar to a
// light "Daylight Aurora" (white + blue) bar so it matches the
// white-body Dashboard instead of looking like a separate dark
// panel bolted on underneath it.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// SHARED THEME TOKENS — "Daylight Aurora" (white + blue)
// Local, self-contained light palette matching the Dashboard's
// _Palette, so the bar reads as one continuous light surface
// instead of a dark glass bar sitting under a white screen.
// ============================================================
class _BarPalette {
  _BarPalette._();

  static const Color violet = Color(0xFF7C3AED);

  // Page/scaffold background behind the bar (matches Dashboard scaffold).
  // Used only for the safe-area filler strip so there's never a color
  // mismatch peeking through at the bottom edge.
  static const Color scaffold = Color(0xFFF6F7FB);

  // The bar itself — a white surface, same family as the Dashboard's cards.
  static const Color barSurface = Colors.white;
  static const Color border = Color(0xFFEBEDF5);

  static const Color textSecondary = Color(0xFF6B7086);
}

// ============================================================
// TABS
// ============================================================
enum AppTab { home, subjects, leaderboard, history, settings }

extension _AppTabMeta on AppTab {
  IconData get icon {
    switch (this) {
      case AppTab.home:
        return Icons.home_rounded;
      case AppTab.subjects:
        return Icons.menu_book_rounded;
      case AppTab.leaderboard:
        return Icons.leaderboard_rounded;
      case AppTab.history:
        return Icons.history_rounded;
      case AppTab.settings:
        return Icons.settings_rounded;
    }
  }

  String get label {
    switch (this) {
      case AppTab.home:
        return 'Home';
      case AppTab.subjects:
        return 'Subjects';
      case AppTab.leaderboard:
        return 'Ranks';
      case AppTab.history:
        return 'History';
      case AppTab.settings:
        return 'Settings';
    }
  }
}

// ============================================================
// APP BOTTOM NAV — edge-to-edge light bar, flush with the
// device's real bottom edge on every phone
// ============================================================
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentTab,
    required this.onChanged,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onChanged;

  static const double _barRadius = 24;
  static const double _minBottomPadding = 10;

  @override
  Widget build(BuildContext context) {
    // The real inset a phone reserves at the bottom — 0 on
    // old-style button-nav devices, larger on gesture-nav ones.
    // Using this (instead of a fixed number) is what keeps the
    // bar flush with the edge on every device instead of leaving
    // a mismatched gap that lets the background peek through.
    final systemInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = systemInset > 0 ? systemInset : _minBottomPadding;

    return Container(
      // Solid, opaque match for the app's own light background so
      // there is no gap of a different color between this bar and
      // the screen content behind it, even mid-transition.
      color: _BarPalette.scaffold,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        height: 64,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _BarPalette.barSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(_barRadius),
            topRight: Radius.circular(_barRadius),
          ),
          border: Border(top: BorderSide(color: _BarPalette.border)),
          boxShadow: const [
            // Soft blue-tinted shadow, same family as the Dashboard's
            // white cards, instead of a heavy black drop shadow.
            BoxShadow(
              color: Color(0x14232B6B),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: AppTab.values.map((tab) {
            return Expanded(
              child: _NavItem(
                tab: tab,
                isSelected: tab == currentTab,
                onTap: () {
                  if (tab != currentTab) {
                    HapticFeedback.selectionClick();
                    onChanged(tab);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final AppTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _BarPalette.violet : _BarPalette.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _BarPalette.violet.withValues(alpha: 0.12),
        highlightColor: _BarPalette.violet.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            // Selected tab gets a soft violet tint on the white bar,
            // rather than the darker glass highlight it had before.
            color: isSelected
                ? _BarPalette.violet.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, color: color, size: 22),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
