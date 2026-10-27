import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

/// Animated login screen.
///
/// Animations:
///  * Gradient header with a gently floating logo.
///  * Form contents enter staggered (fields, button, footer each delayed).
///  * The sign-in button morphs into a spinner while authenticating, then a
///    success check before pushing the home screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _submitting = false;
  bool _succeeded = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      final name = await AuthService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _succeeded = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => HomeScreen(userName: name),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Decorative top background + floating blobs.
          Positioned.fill(
            child: Stack(
              children: [
                Container(
                  height: size.height * 0.42,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(44),
                    ),
                  ),
                ),
                const Positioned(
                  top: -40,
                  right: -30,
                  child: _Blob(diameter: 150, opacity: 0.14),
                ),
                const Positioned(
                  top: 130,
                  left: -50,
                  child: _Blob(diameter: 190, opacity: 0.10),
                ),
                Positioned(
                  top: size.height * 0.40,
                  right: 40,
                  child: const _Blob(diameter: 90, opacity: 0.10),
                ),
              ],
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              children: [
                const SizedBox(height: 24),

                // Floating logo.
                const FadeSlideIn(
                  duration: Duration(milliseconds: 650),
                  child: Center(child: _FloatingLogo()),
                ),
                const SizedBox(height: 22),

                // Headline.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: const Text(
                    'Welcome back 👋',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sign in to manage your bookings anywhere.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 34),

                // Card with the form.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 420),
                  duration: const Duration(milliseconds: 650),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius + 6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Email address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Email is required';
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(
                                Icons.lock_rounded,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    key: ValueKey(_obscurePassword),
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Password is required';
                              }
                              if ((v ?? '').length < 6) {
                                return 'At least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 6),

                          _AnimatedSubmitButton(
                            submitting: _submitting,
                            succeeded: _succeeded,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 18),

                          // Divider "or".
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFDCEEFB),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFDCEEFB),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.admin_panel_settings_rounded,
                                size: 20),
                            label: const Text('Sign in with admin key'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 560),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignupScreen())),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Button that morphs between "Sign in", the spinner and a success check.
class _AnimatedSubmitButton extends StatelessWidget {
  const _AnimatedSubmitButton({
    required this.submitting,
    required this.succeeded,
    required this.onPressed,
  });

  final bool submitting;
  final bool succeeded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final state = succeeded
        ? _ButtonState.success
        : submitting
            ? _ButtonState.loading
            : _ButtonState.idle;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: 54,
      decoration: BoxDecoration(
        gradient: state == _ButtonState.idle
            ? AppColors.heroGradient
            : null,
        color: state == _ButtonState.idle
            ? null
            : state == _ButtonState.loading
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.success,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        boxShadow: [
          BoxShadow(
            color: (state == _ButtonState.success
                    ? AppColors.success
                    : AppColors.primary)
                .withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: submitting || succeeded ? null : onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (state) {
                _ButtonState.loading => const SizedBox(
                    width: 26,
                    height: 26,
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  ),
                _ButtonState.success => const Icon(
                    Icons.check_rounded,
                    color: AppColors.white,
                    key: ValueKey('done'),
                  ),
                _ => const Text(
                    'Sign in',
                    key: ValueKey('idle'),
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum _ButtonState { idle, loading, success }

/// Decorative blurred-ish circle used as a background blob.
class _Blob extends StatelessWidget {
  const _Blob({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Logo badge that gently bobs up and down forever.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();

  @override
  State<_FloatingLogo> createState() => __FloatingLogoState();
}

class __FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _offset = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

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
        return Transform.translate(
          offset: Offset(0, 12 * (_offset.value - 0.5)),
          child: child,
        );
      },
      child: const BrandLogo(size: 92, onLight: true),
    );
  }
}
