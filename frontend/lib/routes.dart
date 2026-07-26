import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/movie_details_screen.dart';
import 'screens/watchlist_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    // Protect watchlist route if user is not logged in
    if (!authProvider.isAuthenticated && state.matchedLocation == '/watchlist') {
      return '/login';
    }

    // Redirect away from login/register if already logged in
    if (authProvider.isAuthenticated && isLoggingIn) {
      return '/';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/movie/:id',
      builder: (context, state) {
        final movieId = int.parse(state.pathParameters['id']!);
        return MovieDetailsScreen(movieId: movieId);
      },
    ),
    GoRoute(
      path: '/watchlist',
      builder: (context, state) => const WatchlistScreen(),
    ),
  ],
);