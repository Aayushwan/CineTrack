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
import 'screens/favorites_screen.dart';
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
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),

        // --- Detail Screens ---
        GoRoute(
          path: '/movie/:id',
          builder: (context, state) {
            final movieIdStr = state.pathParameters['id']!;
            final movieId = int.parse(movieIdStr);
            return MovieDetailsScreen(
              key: ValueKey('movie_$movieId'), // 👈 Forces reload when navigating movie-to-movie
              movieId: movieId,
            );
          },
        ),
        GoRoute(
          path: '/tv/:id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return ShowDetailsScreen(
              key: ValueKey('tv_$id'), // 👈 Forces reload when navigating show-to-show
              showId: id,
            );
          },
        ),
        GoRoute(
          path: '/person/:id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return PersonDetailsScreen(
              key: ValueKey('person_$id'), // 👈 Forces reload when navigating person-to-person
              personId: id,
            );
          },
        ),
      ],
    ),
  ],
);