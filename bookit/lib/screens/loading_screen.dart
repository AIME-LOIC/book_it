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
  static const Duration _splashDuration = Duration(milliseconds: 3600);

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
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _buildMobileSplash();
    }
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

  /// Mobile-only cinematic bus intro. Desktop and web keep the existing splash.
  Widget _buildMobileSplash() {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _master,
            builder: (context, _) {
              final progress = _master.value;
              final letters = ((progress - 0.36) / 0.085)
                  .clamp(0.0, 1.0) * 6;
              final word = 'BOOKIT'.substring(0, letters.floor());
              final width = MediaQuery.sizeOf(context).width;
              final busLeft = -154 + (width + 308) * progress;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: MediaQuery.sizeOf(context).height * 0.30,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          word,
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
                        const SizedBox(height: 12),
                        Container(
                          width: 120,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: busLeft,
                    top: MediaQuery.sizeOf(context).height * 0.39,
                    child: const _ThreeDBus(),
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

/// A compact perspective-styled bus illustration built from Flutter shapes.
class _ThreeDBus extends StatelessWidget {
  const _ThreeDBus();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            right: 3,
            bottom: 6,
            child: Container(
              height: 13,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 14,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewY(-0.07),
              child: Container(
                width: 160,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE2EAF7), Color(0xFF9BB4D8)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44001845),
                      blurRadius: 12,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D6CE0),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(13),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
                        child: Row(
                          children: [
                            for (var i = 0; i < 4; i++) ...[
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF8CE5FF), Color(0xFF15519B)],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFF17467F),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 17,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2363C9),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'BOOKIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final left in [29.0, 126.0])
            Positioned(
              left: left,
              bottom: 7,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF45546B), Color(0xFF111A2A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFD9E5F7), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x44000000), blurRadius: 5, offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB9C8DA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            top: 39,
            child: Container(
              width: 8,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(color: Color(0x88FFD166), blurRadius: 9),
                ],
              ),
            ),
          ),
        ],
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
