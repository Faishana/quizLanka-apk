// main_navigation.dart
// ============================================================
// The single Scaffold for the whole authenticated app. Builds
// each tab screen once and keeps them alive in an IndexedStack,
// with the one fixed AppBottomNav declared here only.
//
// Every post-login / auto-login navigation in the app (Login.dart,
// Splash.dart, Register.dart, etc.) must route to MainNavigation
// — NOT to DashboardScreen directly — or the bottom bar won't be
// there, since DashboardScreen (and the other tab screens) no
// longer declare their own bottomNavigationBar.
// ============================================================

import 'package:flutter/material.dart';

import 'package:quiz_lanka/bottombar.dart';
import 'package:quiz_lanka/dashboard.dart';
import 'package:quiz_lanka/subjects_screen.dart';
import 'package:quiz_lanka/leaderborad.dart';
import 'package:quiz_lanka/quiz_history_screen.dart';
import 'package:quiz_lanka/settings.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late AppTab _currentTab = widget.initialTab;

  // Built once. IndexedStack keeps every screen's State alive
  // (scroll position, in-flight futures) for the whole session —
  // switching tabs never re-creates or refires network calls.
  late final List<Widget> _pages = [
    const DashboardScreen(),
    SubjectsScreen(),
    LeaderboardScreen(),
    const QuizHistoryScreen(),
    SettingsScreen(),
  ];

  void _onTabChanged(AppTab tab) {
    if (_currentTab == tab) return;
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keeps the bar pinned in the same spot even when a keyboard
      // opens on a nested screen (e.g. a text field on Settings).
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _currentTab.index, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentTab: _currentTab,
        onChanged: _onTabChanged,
      ),
    );
  }
}
