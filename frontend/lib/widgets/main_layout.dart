// frontend/lib/widgets/main_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    // Determine current index based on route
    int selectedIndex = 1; // Default to Home
    if (location.startsWith('/search')) {
      selectedIndex = 0;
    } else if (location == '/') {
      selectedIndex = 1;
    } else if (location.startsWith('/discover')) {
      selectedIndex = 2;
    } else if (location.startsWith('/lists') || location.startsWith('/watchlist')) {
      selectedIndex = 3;
    } else if (location.startsWith('/history')) {
      selectedIndex = 4;
    } else if (location.startsWith('/profile')) {
      selectedIndex = 5;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Row(
        children: [
          // 1. Left Sidebar
          NavigationRail(
            backgroundColor: const Color(0xFF09090B),
            indicatorColor: const Color(0xFFE11D48).withValues(alpha: 0.15),
            selectedIndex: selectedIndex,
            minWidth: 90,
            groupAlignment: -0.9,
            onDestinationSelected: (int index) {
              switch (index) {
                case 0:
                  context.go('/search');
                  break;
                case 1:
                  context.go('/');
                  break;
                case 2:
                  context.go('/discover');
                  break;
                case 3:
                  context.go('/lists');
                  break;
                case 4:
                  context.go('/history');
                  break;
                case 5:
                  context.go('/profile');
                  break;
              }
            },
            leading: const Padding(
              padding: EdgeInsets.only(bottom: 24.0, top: 16.0),
              child: Icon(Icons.movie_filter_rounded, color: Color(0xFFE11D48), size: 36),
            ),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedIconTheme: const IconThemeData(color: Color(0xFFE11D48), size: 28),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54, fontSize: 11),
            selectedLabelTextStyle: const TextStyle(
                color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 12),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: Text('Discover'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.format_list_bulleted_rounded),
                selectedIcon: Icon(Icons.format_list_bulleted_rounded),
                label: Text('Lists'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_toggle_off_rounded),
                selectedIcon: Icon(Icons.history_rounded),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profile'),
              ),
            ],
          ),

          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),

          // 2. Main Screen Content
          Expanded(child: child),
        ],
      ),
    );
  }
}