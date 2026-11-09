import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'driver_dashboard_screen.dart';
import 'login_screen.dart';

/// Choose an account before signing in.
///
/// Shown after the loading screen when no access token is saved but at least
/// one account was used on this device recently. Tapping a profile restores
/// its stored session automatically (no password needed); a network hiccup
/// still enters the app - matching the app's restore resilience - while an
/// expired session removes the profile and asks for a fresh sign-in.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<Map<String, String>> _accounts = [];
  bool _loading = true;
  String? _busy; // identifier of the account currently auto-logging in.

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AuthService.savedAccounts();
    if (!mounted) return;
    setState(() { _accounts = accounts; _loading = false; });
  }

  Future<void> _useAccount(Map<String, String> account) async {
    if (_busy != null) return;
    setState(() => _busy = account['identifier']);
    final name = await AuthService.activateAccount(account['identifier']!);
    if (!mounted) return;
    if (name == null) {
      setState(() => _busy = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Session expired for ${_displayName(account)}. Please sign in again.'),
      ));
      await _loadAccounts();
      return;
    }
    _enterApp(name, driver: account['type'] == 'driver');
  }

  Future<void> _forgetAccount(Map<String, String> account) async {
    await AuthService.removeAccount(account['identifier']!);
    await _loadAccounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_displayName(account)} removed from this device.'),
      ));
    }
  }

  String _displayName(Map<String, String> account) =>
      account['name']?.trim().isNotEmpty == true ? account['name']!.trim() : account['identifier']!;

  void _enterApp(String name, {required bool driver}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => driver
            ? DriverDashboardScreen(driverName: name)
            : HomeScreen(userName: name),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Blue & white in light mode, dark navy & blue in dark mode.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020C1B), Color(0xFF042955), Color(0xFF01579B)],
          )
        : AppColors.heroGradient;
    final headlineColor = Colors.white;
    final cardColor = isDark ? const Color(0xFF0B2242) : AppColors.white;
    final cardBorder = isDark ? const Color(0xFF0B9BC7) : const Color(0xFFCFE6F7);
    final titleColor = isDark ? Colors.white : AppColors.primaryDark;
    final subColor = isDark ? Colors.white60 : AppColors.textMuted;

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _busy != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Signing you back in…', style: TextStyle(color: Colors.white70)),
              ]))
            : Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        final driver = account['type'] == 'driver';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                              onTap: () => _useAccount(account),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                                  border: Border.all(color: cardBorder, width: 1),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(children: [
                                  CircleAvatar(
                                    backgroundColor: driver
                                        ? (isDark ? const Color(0xFF38BDF8) : AppColors.primarySoft)
                                        : AppColors.primary,
                                    child: Text(
                                      _displayName(account).characters.first.toUpperCase(),
                                      style: TextStyle(
                                        color: driver && isDark ? const Color(0xFF04203F) : AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(_displayName(account),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)),
                                      Text(account['identifier']!,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: subColor, fontSize: 13)),
                                    ]),
                                  ),
                                  IconButton(
                                    tooltip: 'Forget this account',
                                    icon: const Icon(Icons.person_remove_alt_1_rounded,
                                        color: Colors.white54),
                                    onPressed: () => _forgetAccount(account),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
                      ),
                      icon: const Icon(Icons.person_add_alt_rounded),
                      label: const Text('Log in with another account',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Choose an account', style: TextStyle(fontWeight: FontWeight.w800, color: headlineColor)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(top: true, bottom: false, child: body),
      ),
    );
  }
}
