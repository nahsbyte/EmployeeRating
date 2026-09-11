import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared gradient background with subtle bubbles.
class AppBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool safeTop;
  final bool safeBottom;

  const AppBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.safeTop = true,
    this.safeBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C0C12), Color(0xFF14141C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _BlurSpot(
            size: 220,
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: 180,
          left: -50,
          child: _BlurSpot(
            size: 180,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            top: safeTop,
            bottom: safeBottom,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurSpot extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurSpot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}

/// Reusable card styling that matches the login form surface.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
