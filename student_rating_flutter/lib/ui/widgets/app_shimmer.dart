import 'package:flutter/material.dart';

/// Simple reusable shimmer with lilac hues so it stays visible on purple pages.
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = _controller.value; // 0..1 sweep
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x70FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.25, 0.5, 0.75],
              begin: Alignment(-1 + (slide * 2), -0.05),
              end: Alignment(0 + (slide * 2), 0.05),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  final double height;
  final double radius;
  final EdgeInsets margin;
  final Color? color;

  const ShimmerBlock({
    super.key,
    required this.height,
    required this.radius,
    required this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AppShimmer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color ?? const Color(0x33E7E7FF),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
