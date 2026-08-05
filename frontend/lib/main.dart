// frontend/lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/watchlist_provider.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CineTrackApp());
}

class CineTrackApp extends StatelessWidget {
  const CineTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(
          create: (_) => WatchlistProvider()..fetchWatchlist(), // 👈 Auto-fetches watchlist state on launch
        ),
      ],
      child: MaterialApp.router(
        title: 'CineTrack',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF09090B),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFA855F7), // Trakt Purple Accent
            secondary: Color(0xFF38BDF8), // Cyan Accent
            surface: Color(0xFF131316),
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        ),
      ),
    );
  }
}