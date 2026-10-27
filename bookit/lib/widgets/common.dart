import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A reusable entrance animation: fades in and slides up, optionally delayed
/// so screens can build staggered lists of animated children.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
    this.offset = const Offset(0, 0.35),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Expressed in fractions of the child's own size (like `Tween<Offset>`).
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// BookIt word-mark + logo badge, reused on splash and login.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96, this.onLight = false});

  final double size;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onLight ? AppColors.heroGradient : null,
        color: onLight ? null : AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (onLight ? AppColors.primaryDark : AppColors.primary)
                .withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        Icons.directions_bus_rounded,
        color: onLight ? AppColors.white : AppColors.primary,
        size: size * 0.52,
      ),
    );
  }
}
