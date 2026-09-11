import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'supabase_options.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF695ae0));
    final appScheme = baseScheme.copyWith(secondary: const Color(0xFF695ae0));

    return MaterialApp(
      title: 'Student Rating',
      scrollBehavior: const _AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: appScheme,
        textTheme: GoogleFonts.manropeTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use clamping (no bounce) for smooth but firm scrolling across platforms.
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
