import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _loginKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _busy = false;
  bool _obscure = true;
  bool _forgotPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  Future<void> _login() async {
    if (_busy || !(_loginKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final error = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      // AuthWrapper existing menentukan role dan tujuan setelah login.
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Tidak dapat masuk. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_busy || !(_resetKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _resetEmailController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final error = await _authService.sendPasswordResetEmail(email);
      if (!mounted) {
        return;
      }
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      setState(() {
        _forgotPassword = false;
        _emailController.text = email;
        _notice =
            'Permintaan reset password berhasil diproses. Periksa email dan folder spam Anda.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Permintaan reset belum berhasil. Coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _switchForm() {
    FocusScope.of(context).unfocus();
    setState(() {
      _forgotPassword = !_forgotPassword;
      _error = null;
      _notice = null;
      if (_forgotPassword) {
        _resetEmailController.text = _emailController.text.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _hero(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _forgotPassword ? 'Lupa Password' : 'Selamat Datang',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _forgotPassword
                            ? 'Masukkan email akun untuk meminta tautan reset password.'
                            : 'Masuk dengan akun Surveyor atau Admin Anda.',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_notice != null) _feedback(_notice!, false),
                      if (_error != null) _feedback(_error!, true),
                      AbsorbPointer(
                        absorbing: _busy,
                        child: _forgotPassword ? _resetForm() : _loginForm(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : (_forgotPassword ? _resetPassword : _login),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _forgotPassword ? 'Kirim Link Reset' : 'Masuk',
                              ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _switchForm,
                        child: Text(
                          _forgotPassword
                              ? 'Kembali ke Login'
                              : 'Lupa password?',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() => SizedBox(
    width: double.infinity,
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/image/hero_cirebon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => Container(color: AppColors.navy),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xEE0B3554),
                  Color(0x660B3554),
                  Color(0xDD0B3554),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 48, 24, 28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.park, size: 52, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Pemetaan Pohon\nKota Cirebon',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Bersama menjaga pohon,\nuntuk kota yang lebih hijau',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            tooltip: 'Tutup Login',
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _feedback(String text, bool error) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(color: error ? Colors.red.shade700 : AppColors.leaf),
      ),
    ),
  );

  Widget _loginForm() => Form(
    key: _loginKey,
    child: AutofillGroup(
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            validator: _validateEmail,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            validator: (value) =>
                value == null || value.isEmpty ? 'Masukkan password.' : null,
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _resetForm() => Form(
    key: _resetKey,
    child: TextFormField(
      controller: _resetEmailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      validator: _validateEmail,
      onFieldSubmitted: (_) => _resetPassword(),
      decoration: const InputDecoration(
        labelText: 'Email akun',
        prefixIcon: Icon(Icons.email_outlined),
      ),
    ),
  );
}