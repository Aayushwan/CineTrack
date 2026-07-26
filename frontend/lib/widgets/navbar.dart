import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  const CustomNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return AppBar(
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      elevation: 4,
      titleSpacing: 24,
      title: InkWell(
        onTap: () => context.go('/'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_filter_rounded, color: Color(0xFFE11D48), size: 30),
            const SizedBox(width: 8),
            Text(
              'CineTrack',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded, color: Colors.white70),
          label: const Text('Home', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 12),
        if (authProvider.isAuthenticated) ...[
          TextButton.icon(
            onPressed: () => context.go('/watchlist'),
            icon: const Icon(Icons.bookmark_rounded, color: Colors.amber),
            label: const Text('Watchlist', style: TextStyle(color: Colors.amber)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
          ),
        ] else ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
            ),
            onPressed: () => context.go('/login'),
            child: const Text('Login'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.go('/register'),
            child: const Text('Register'),
          ),
        ],
        const SizedBox(width: 24),
      ],
    );
  }
}