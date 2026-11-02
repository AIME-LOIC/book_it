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
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _busy != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Signing you back in…', style: TextStyle(color: AppColors.textMuted)),
              ]))
            : Container(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        final driver = account['type'] == 'driver';
                        return Card(
                          color: AppColors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                            side: const BorderSide(color: Color(0xFFE3ECF5)),
                          ),
                          child: ListTile(
                            onTap: () => _useAccount(account),
                            leading: CircleAvatar(
                              backgroundColor: driver ? AppColors.primarySoft : AppColors.primary,
                              child: Text(
                                _displayName(account).characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: driver ? AppColors.primaryDark : AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(_displayName(account),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            subtitle: Text(account['identifier']!,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted)),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Forget this account',
                              icon: const Icon(Icons.person_remove_alt_1_rounded, color: AppColors.textMuted),
                              onPressed: () => _forgetAccount(account),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      icon: const Icon(Icons.person_add_alt_rounded),
                      label: const Text('Log in with another account'),
                    ),
                  ),
                ]),
              );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Choose an account', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: body,
      ),
    );
  }
}
