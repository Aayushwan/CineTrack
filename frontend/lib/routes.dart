// frontend/lib/routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/api_service.dart';
import 'widgets/main_layout.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/discover_category_screen.dart';
import 'screens/releases_screen.dart';
import 'screens/lists_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/show_details_screen.dart';
import 'screens/person_details_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/recommended_screen.dart';
import 'screens/calendar_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',

  // 🔐 Auth Guard / Redirection Logic
  redirect: (context, state) async {
    final token = await ApiService.getToken();
    final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/register';

    if (token == null || token.isEmpty) {
      return isAuthRoute ? null : '/login';
    }

    if (token.isNotEmpty && isAuthRoute) {
      return '/';
    }

    return null;
  },

  routes: [
    // --- Auth Routes (Outside MainLayout Shell) ---
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // --- Main App Shell Routes (With Sidebar Navigation Layout) ---
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoverScreen(),
        ),
        GoRoute(
          path: '/discover/:category',
          builder: (context, state) {
            final category = state.pathParameters['category'] ?? 'trending';
            return DiscoverCategoryScreen(
              key: ValueKey(category), // 👈 Forces screen rebuild when switching categories
              category: category,
            );
          },
        ),
        GoRoute(
          path: '/releases',
          builder: (context, state) => const ReleasesScreen(),
        ),
        GoRoute(
          path: '/lists',
          builder: (context, state) => const ListsScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: '/watchlist',
          builder: (context, state) => const WatchlistScreen(),
        ),
        GoRoute(
          path: '/recommended',
          builder: (context, state) => const RecommendedScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // --- Detail Screens ---
        GoRoute(
          path: '/movie/:id',
          builder: (context, state) {
            final movieIdStr = state.pathParameters['id']!;
            final movieId = int.parse(movieIdStr);
            return MovieDetailsScreen(movieId: movieId);
          },
        ),
        GoRoute(
          path: '/tv/:id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return ShowDetailsScreen(showId: id);
          },
        ),
        GoRoute(
          path: '/person/:id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return PersonDetailsScreen(personId: id);
          },
        ),
      ],
    ),
  ],
);

// Lightweight placeholder widget while building out remaining screens
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Center(
        child: Text(
          '$title Screen Coming Soon',
          style: const TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}