import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _ready = false;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutSine,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      child: _ready
          ? _AuthGate(stream: _authStream, key: const ValueKey('auth'))
          : const _SplashView(key: ValueKey('splash')),
    );
  }
}

class _AuthGate extends StatelessWidget {
  final Stream<AuthState> stream;

  const _AuthGate({required this.stream, super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) return const HomeScreen();
    return StreamBuilder<AuthState>(
      stream: stream,
      builder: (context, snapshot) {
        final liveSession = snapshot.data?.session;
        if (liveSession == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({super.key});

  Widget _buildHeroCard(BuildContext context, double t) {
    final size = 140.0 + (240.0 - 140.0) * t;
    final radius = 32.0 + (28.0 - 32.0) * t;
    final padding = 18.0 + (20.0 - 18.0) * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25 - (0.1 * t)),
            blurRadius: 28 + (8 * t),
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: EdgeInsets.all(padding),
      child: Image.asset(
        'assets/ic_ibg3.png',
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C12),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0C0C12), Color(0xFF14141C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'brand-card',
                  flightShuttleBuilder: (flightContext, animation, direction,
                      fromContext, toContext) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final t = Curves.easeInOutSine.transform(animation.value);
                        return Material(
                          color: Colors.transparent,
                          child: _buildHeroCard(context, t),
                        );
                      },
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: _buildHeroCard(context, 0),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Mohon tunggu sebentar...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
