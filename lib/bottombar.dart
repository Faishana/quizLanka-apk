// bottombar.dart
// ============================================================
// Shared bottom navigation bar for every main screen
// (Dashboard, Subjects, Leaderboard, History, Settings).
//
// USAGE — in MainNavigation:
//   bottomNavigationBar: AppBottomNav(
//     currentTab: _currentTab,
//     onChanged: _onTabChanged,
//   ),
//
// Design: one solid navy bar (same navy as the screen headers) with
// rounded top corners. The navy runs all the way down through the
// phone's gesture-bar area, so there is no light strip under it.
// The active tab is shown by a gold icon, a bold white label and a
// small gold dot. There is no light "pill" behind the icon.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_lanka/QL.dart';

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
// APP BOTTOM NAV
// ============================================================
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentTab,
    required this.onChanged,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onChanged;

  static const double _barRadius = 26;
  static const double _barHeight = 66;
  static const double _minBottomPadding = 8;

  @override
  Widget build(BuildContext context) {
    // Real bottom inset of the phone (gesture bar). The navy colour
    // continues through it, so the bar is flush with the screen edge.
    final systemInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = systemInset > 0 ? systemInset : _minBottomPadding;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [QL.navy, QL.navyDeep],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_barRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: QL.navy.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            for (final tab in AppTab.values)
              Expanded(
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
              ),
          ],
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

  // Light blue-grey that stays readable on navy.
  static const Color _inactive = Color(0xFFA9BAE3);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.10),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      tab.icon,
                      size: 25,
                      color: isSelected ? QL.gold : _inactive,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : _inactive,
                    ),
                    child: Text(tab.label, maxLines: 1, softWrap: false),
                  ),
                  const SizedBox(height: 5),
                  // gold dot under the active tab
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: isSelected ? 18 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: QL.gold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}