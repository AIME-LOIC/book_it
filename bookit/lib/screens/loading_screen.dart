import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Animated splash / loading screen.
///
/// Sequence:
///  1. Pulsing rings expand behind the logo while it pops in with an
///     elastic curve.
///  2. The word-mark and tagline slide in staggered.
///  3. A thin linear progress bar "loads" while API key config is checked.
///  4. Navigation to [LoginScreen] happens automatically.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  static const Duration _splashDuration = Duration(milliseconds: 2600);

  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: _splashDuration,
  );

  /// Repeating controller that drives the endless pulse rings.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
  );
  late final Animation<double> _title = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.3, 0.92, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _master.forward();
    _master.addStatusListener(_onDone);
  }

  void _onDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _master.removeStatusListener(_onDone);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Pulsing rings + logo.
              SizedBox(
                width: 220,
                height: 220,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      _PulseRing(
                        animation: _pulse,
                        color: AppColors.white.withValues(alpha: 0.18),
                        beginScale: 0.55,
                        endScale: 1.0,
                      ),
                      _PulseRing(
                        animation: _pulse,
                        color: AppColors.white.withValues(alpha: 0.10),
                        beginScale: 0.75,
                        endScale: 1.2,
                      ),
                      child!,
                    ],
                  ),
                  child: ScaleTransition(
                    scale: _logoScale.drive(
                      Tween(begin: 0.4, end: 1.0),
                    ),
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: const BrandLogo(size: 104, onLight: true),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Word-mark.
              FadeTransition(
                opacity: _title,
                child: SlideTransition(
                  position: _title
                      .drive(Tween<Offset>(begin: const Offset(0, .5), end: Offset.zero)),
                  child: const Text(
                    'BookIt',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tagline.
              FadeTransition(
                opacity: _tagline,
                child: SlideTransition(
                  position: _tagline
                      .drive(Tween<Offset>(begin: const Offset(0, .5), end: Offset.zero)),
                  child: Text(
                    'Book anything, anytime.',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Loading progress.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding * 3,
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: 0.35 + 0.65 * _progress.value,
                            minHeight: 5,
                            backgroundColor:
                                AppColors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    FadeTransition(
                      opacity: _tagline,
                      child: Text(
                        ApiConfig.isConfigured
                            ? 'Connecting…'
                            : 'Running in demo mode — add API keys in\nconfig/bookit_keys.env',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// An expanding, fading circle used behind the splash logo.
class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.animation,
    required this.color,
    required this.beginScale,
    required this.endScale,
  });

  final Animation<double> animation;
  final Color color;
  final double beginScale;
  final double endScale;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 1, curve: Curves.easeOut),
    );
    return ScaleTransition(
      scale: Tween<double>(begin: beginScale, end: endScale).animate(curved),
      child: FadeTransition(
        opacity:
            Tween<double>(begin: 1, end: 0).animate(curved),
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}
