import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'public_home_screen.dart';
import 'force_password_screen.dart';
import 'admin_dashboard.dart';
import 'surveyor_dashboard.dart';
import 'login_screen.dart';
import '../utils/app_mode.dart';

class AuthWrapper extends StatefulWidget {
  final bool showLogin;
  const AuthWrapper({super.key, this.showLogin = false});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
class _AuthWrapperState extends State<AuthWrapper> {
  final _auth = AuthService();
  late Stream<User?> _session;
  @override
  void initState() { super.initState(); _session = _auth.authStateChanges; }
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(stream: _session,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _AccessMessage(
        title: 'Sesi belum dapat diperiksa',
        message: 'Periksa koneksi internet lalu coba lagi.',
        action: 'Coba lagi', onAction: () => setState(() => _session = _auth.authStateChanges));
      }
      if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();
      final user = snapshot.data;
      if (user == null) {
        return (isSurveyorApp || widget.showLogin)
          ? const LoginScreen(standalone: true) : const PublicHomeScreen();
      }
      return _ProfileGate(key: ValueKey(user.uid), user: user, auth: _auth);
    });
}

class _ProfileGate extends StatefulWidget {
  final User user;
  final AuthService auth;
  const _ProfileGate({super.key, required this.user, required this.auth});
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}
class _ProfileGateState extends State<_ProfileGate> {
  late Future<AppUser?> _profile;
  String? _logoutError;
  bool _leaving = false;
  @override
  void initState() { super.initState(); _profile = _load(); }
  Future<AppUser?> _load() async {
    final profile = await widget.auth.getUserData(widget.user.uid, propagateErrors: true);
    if (profile == null || !profile.isActive) return profile;
    final email = widget.user.email;
    if (email != null && email != profile.email) {
      await widget.auth.reconcileEmail(profile.uid, email);
      return profile.copyWith(email: email);
    }
    return profile;
  }
  Future<void> _logout() async {
    if (_leaving) return;
    setState(() { _leaving = true; _logoutError = null; });
    try { await widget.auth.logout(); }
    catch (_) { if (mounted) setState(() => _logoutError = 'Belum berhasil keluar. Periksa koneksi lalu coba lagi.'); }
    finally { if (mounted) setState(() => _leaving = false); }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser?>(future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const _Loading();
      if (snapshot.hasError) {
        return _AccessMessage(
        title: 'Profil belum dapat dimuat',
        message: 'Periksa koneksi internet. Jika masalah berlanjut, hubungi pengelola. Akun Anda belum dikeluarkan.',
        action: 'Coba lagi', onAction: () => setState(() => _profile = _load()),
        secondary: TextButton(onPressed: _leaving ? null : _logout, child: const Text('Keluar')),
        error: _logoutError);
      }
      final profile = snapshot.data;
      if (profile == null || !profile.isActive) {
        return _AccessMessage(
        title: profile == null ? 'Profil akun belum tersedia' : 'Akun tidak aktif',
        message: 'Hubungi pengelola untuk memeriksa akses akun Anda.',
        action: _leaving ? 'Sedang keluar…' : 'Keluar dan ganti akun',
        onAction: _leaving ? null : _logout, error: _logoutError);
      }
      if (isSurveyorApp && profile.role != UserRole.surveyor) {
        return _AccessMessage(
        title: 'Aplikasi khusus surveyor',
        message: 'Gunakan akun surveyor untuk melanjutkan. Akun admin digunakan melalui website.',
        action: 'Keluar dan ganti akun', onAction: _leaving ? null : _logout, error: _logoutError);
      }
      if (profile.requiresPasswordChange) return ForcePasswordScreen(appUser: profile);
      return profile.role == UserRole.admin
          ? AdminDashboard(adminUser: profile) : SurveyorDashboard(surveyorUser: profile);
    });
}
class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
class _AccessMessage extends StatelessWidget {
  final String title, message, action;
  final String? error;
  final VoidCallback? onAction;
  final Widget? secondary;
  const _AccessMessage({required this.title, required this.message, required this.action,
    required this.onAction, this.secondary, this.error});
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(
    child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480), child: Column(mainAxisSize: MainAxisSize.min,
        children: [const Icon(Icons.badge_outlined, size: 48), const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), Text(message, textAlign: TextAlign.center),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(error!))),
          const SizedBox(height: 20), FilledButton(onPressed: onAction, child: Text(action)),
          if (secondary != null) secondary!,
        ]))))));
}
