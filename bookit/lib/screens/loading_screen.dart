import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
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
  static const Duration _splashDuration = Duration(milliseconds: 4200);

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

  Future<void> _onDone(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    _master.removeStatusListener(_onDone);
    final restoredName = await AuthService.restoreSession();
    if (!mounted) return;
    final Widget destination = restoredName == null
        ? const LoginScreen()
        : HomeScreen(userName: restoredName);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => destination,
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
  Widget build(BuildContext context) => _buildMobileSplash();

  /// Cinematic bus intro shared by mobile and desktop.
  Widget _buildMobileSplash() {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _master,
            builder: (context, _) {
              final progress = _master.value;
              final size = MediaQuery.sizeOf(context);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: size.height * 0.30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'BOOKIT',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 16,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 54,
                    child: Column(
                      children: [
                        Text(
                          'Book anything, anytime.',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 42),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: 0.12 + 0.88 * progress,
                              minHeight: 4,
                              backgroundColor:
                                  AppColors.white.withValues(alpha: 0.22),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          ApiConfig.isConfigured
                              ? 'Connecting…'
                              : 'Running in demo mode',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
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
