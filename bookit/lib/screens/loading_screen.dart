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
  static const Duration _splashDuration = Duration(seconds: 6);

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
              final width = size.width;
              // Time the reveal around the moment the bus crosses screen center.
              final centerCrossing = (width / 2 + 65) / (width + 308);
              // Reveal six distinct characters over ~1.4 seconds as the
              // bus passes the center; never show partial or skipped letters.
              final revealProgress =
                  ((progress - (centerCrossing - 0.12)) / 0.24)
                      .clamp(0.0, 1.0);
              final letters = (revealProgress * 6).floor().clamp(0, 6);
              final word = 'BOOKIT'.substring(0, letters);
              final busLeft = -154 + (width + 308) * progress;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: busLeft,
                    top: size.height * 0.30 + 16,
                    child: const _ThreeDBus(),
                  ),
                  Positioned(
                    top: size.height * 0.30,
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

/// Perspective-painted bus with visible side, front, roof, windows and wheels.
class _ThreeDBus extends StatelessWidget {
  const _ThreeDBus();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 250,
        height: 145,
        child: CustomPaint(painter: _BusPainter()),
      );
}

class _BusPainter extends CustomPainter {
  const _BusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 250;
    final sy = size.height / 145;
    canvas.save();
    canvas.scale(sx, sy);

    Paint paint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);

    // Soft contact shadow grounds the vehicle.
    canvas.drawOval(
      Rect.fromLTWH(18, 112, 220, 24),
      Paint()
        ..color = const Color(0x55001635)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Roof and far-side depth.
    canvas.drawPath(
      polygon(const [Offset(25, 38), Offset(185, 17), Offset(232, 42), Offset(69, 62)]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9FCFF), Color(0xFF8BA8D2)],
        ).createShader(const Rect.fromLTWH(25, 17, 207, 45)),
    );

    // Long side panel, tapered to create perspective.
    canvas.drawPath(
      polygon(const [Offset(25, 38), Offset(185, 17), Offset(185, 98), Offset(25, 117)]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFE2ECFA), Color(0xFF7E9FCB)],
        ).createShader(const Rect.fromLTWH(25, 17, 160, 100)),
    );

    // Front face angled toward the viewer.
    canvas.drawPath(
      polygon(const [Offset(185, 17), Offset(232, 42), Offset(232, 108), Offset(185, 98)]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB7D0F3), Color(0xFF315B9B), Color(0xFF173A70)],
        ).createShader(const Rect.fromLTWH(185, 17, 47, 91)),
    );

    // Side windows, individually framed to read as glass.
    for (var i = 0; i < 4; i++) {
      final x = 37.0 + i * 35;
      final top = 36.0 - i * 4.4;
      final bottom = 83.0 - i * 4.4;
      canvas.drawPath(
        polygon([
          Offset(x, top),
          Offset(x + 27, top - 3.5),
          Offset(x + 27, bottom - 3),
          Offset(x, bottom),
        ]),
        paint(const Color(0xFF143E75)),
      );
      canvas.drawPath(
        polygon([
          Offset(x + 2, top + 2),
          Offset(x + 24, top - 1),
          Offset(x + 24, bottom - 5),
          Offset(x + 2, bottom - 2),
        ]),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA7F0FF), Color(0xFF2A75B8), Color(0xFF17416F)],
          ).createShader(Rect.fromLTWH(x, top, 27, bottom - top)),
      );
      canvas.drawLine(
        Offset(x + 13, top + 1),
        Offset(x + 13, bottom - 2),
        Paint()..color = const Color(0xAAE9F8FF)..strokeWidth = 1.3,
      );
    }

    // Blue belt and lower chassis add depth and brand color.
    canvas.drawPath(
      polygon(const [Offset(25, 91), Offset(185, 73), Offset(185, 96), Offset(25, 117)]),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3487F5), Color(0xFF12459B)],
        ).createShader(const Rect.fromLTWH(25, 73, 160, 44)),
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BOOKIT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(70, 91);
    canvas.rotate(-0.11);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Panoramic windshield on the front plane.
    canvas.drawPath(
      polygon(const [Offset(195, 31), Offset(222, 46), Offset(222, 75), Offset(195, 69)]),
      paint(const Color(0xFF123B70)),
    );
    canvas.drawPath(
      polygon(const [Offset(198, 35), Offset(218, 47), Offset(218, 70), Offset(198, 65)]),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB7F4FF), Color(0xFF3B8DCB), Color(0xFF163F78)],
        ).createShader(const Rect.fromLTWH(195, 31, 27, 44)),
    );
    canvas.drawLine(
      const Offset(205, 39),
      const Offset(205, 67),
      Paint()..color = const Color(0x99E5FAFF)..strokeWidth = 1.2,
    );

    // Headlamp and bumper on the near-facing front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(224, 80, 7, 13), const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFFFFE9A0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      polygon(const [Offset(185, 98), Offset(232, 108), Offset(229, 116), Offset(185, 106)]),
      paint(const Color(0xFF182D4A)),
    );

    // Wheels with metallic hubs.
    for (final p in [const Offset(55, 104), const Offset(158, 92)]) {
      canvas.drawCircle(p, 17, paint(const Color(0xFF101B2B)));
      canvas.drawCircle(p, 12, paint(const Color(0xFF526781)));
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFEAF4FF), Color(0xFF879BB5), Color(0xFF34465E)],
          ).createShader(Rect.fromCircle(center: p, radius: 7)),
      );
      canvas.drawCircle(p, 2.5, paint(const Color(0xFF17263D)));
    }

    // Highlight along the side gives the body a glossy 3D edge.
    canvas.drawPath(
      polygon(const [Offset(28, 39), Offset(181, 19), Offset(181, 24), Offset(28, 44)]),
      paint(const Color(0xCCFFFFFF)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
