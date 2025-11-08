import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:get/get.dart';
import 'package:quizverse/views/home/about_view.dart';
import 'package:quizverse/views/home/history_view.dart';
import 'package:quizverse/views/home/home_view.dart';
import 'package:quizverse/views/home/profile_view.dart';

class BottomNavBar extends StatelessWidget {
  final RxInt selectedIndex = 0.obs;

  final List<Widget> pages = [
    HomeView(),
    HistoryView(),
    ProfileView(),
    AboutView(),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      body: Obx(() => pages[selectedIndex.value]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withAlpha(26)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: colorScheme.primary.withAlpha(39),
              hoverColor: colorScheme.primary.withAlpha(26),
              gap: 8,

              activeColor: colorScheme.primary,

              iconSize: 24,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: Duration(milliseconds: 400),

              tabBackgroundColor: colorScheme.primary.withAlpha(26),

              color: colorScheme.onSurface.withAlpha(153),

              tabs: [
                GButton(icon: Icons.home, text: 'Home'),
                GButton(icon: Icons.history, text: 'History'),
                GButton(icon: Icons.person, text: 'Profile'),
                GButton(icon: Icons.info, text: 'About'),
              ],
              selectedIndex: selectedIndex.value,
              onTabChange: (index) {
                selectedIndex.value = index;
              },
            ),
          ),
        ),
      ),
    );
  }
}
