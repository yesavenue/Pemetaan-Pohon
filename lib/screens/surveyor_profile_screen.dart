import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/civic_design.dart';

class SurveyorProfileScreen extends StatefulWidget {
  final AppUser surveyorUser;
  final bool embedded;
  final ValueChanged<AppUser>? onUserUpdated;

  const SurveyorProfileScreen({
    super.key,
    required this.surveyorUser,
    this.embedded = false,
    this.onUserUpdated,
  });

  @override
  State<SurveyorProfileScreen> createState() => _SurveyorProfileScreenState();
}

class _SurveyorProfileScreenState extends State<SurveyorProfileScreen> {
  final _authService = AuthService();
  late AppUser _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = widget.surveyorUser;
  }

  @override
  void didUpdateWidget(covariant SurveyorProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surveyorUser != widget.surveyorUser) {
      _user = widget.surveyorUser;
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _editProfile() async {
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Ubah Profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Ubah Nama'),
                subtitle: Text(_user.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, _AccountAction.name),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Ganti Email'),
                subtitle: Text(_user.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, _AccountAction.email),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (mounted && action != null) {
      await _editAccount(action);
    }
  }

  Future<void> _editAccount(_AccountAction action) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountDialog(user: _user, action: action),
    );
    if (!mounted || result == null) {
      return;
    }
    if (action == _AccountAction.name) {
      final updated = _user.copyWith(name: result);
      setState(() => _user = updated);
      widget.onUserUpdated?.call(updated);
      _message('Nama berhasil diperbarui.');
    } else if (action == _AccountAction.email) {
      _message(
        'Link verifikasi dikirim ke $result. Email akun berubah setelah proses verifikasi selesai.',
      );
    } else {
      _message('Password berhasil diubah.');
    }
  }

  Future<void> _logout() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Keluar dari akun?'),
          content: const Text(
            'Anda dapat masuk kembali menggunakan email dan password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      final navigator = Navigator.of(context);
      await _authService.logout();
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (_) {
      _message('Belum berhasil keluar. Coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Profil'),
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CivicHeading(
                  eyebrow: 'AKUN SURVEYOR',
                  title: 'Profil & keamanan',
                  description:
                      'Kelola identitas dan akses akun untuk kegiatan survei Anda.',
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const avatar = CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.navy,
                      child: Icon(Icons.person, size: 48, color: Colors.white),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Chip(
                          avatar: Icon(
                            Icons.circle,
                            size: 10,
                            color: AppColors.leaf,
                          ),
                          label: Text('Surveyor'),
                          backgroundColor: Color(0xFFE1F3E9),
                          side: BorderSide.none,
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(14) > 21) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [avatar, const SizedBox(height: 16), details],
                      );
                    }
                    return Row(
                      children: [
                        avatar,
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                _menu(Icons.person_outline, 'Ubah Profil', _editProfile),
                const SizedBox(height: 8),
                _menu(
                  Icons.lock_outline,
                  'Ganti Password',
                  () => _editAccount(_AccountAction.password),
                ),
                const SizedBox(height: 8),
                _menu(Icons.info_outline, 'Tentang Aplikasi', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Pemetaan Pohon Kota Cirebon',
                    applicationIcon: const TreeSilhouette(
                      size: 40,
                      color: AppColors.leaf,
                    ),
                    children: const [
                      Text(
                        'Aplikasi untuk mencatat lokasi, kondisi, dan foto pohon '
                        'di Kota Cirebon. Bersama menjaga pohon untuk kota yang lebih hijau.',
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 48),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(_busy ? 'Memproses...' : 'Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(IconData icon, String label, VoidCallback onTap) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      enabled: !_busy,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.navy),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
      onTap: _busy ? null : onTap,
    ),
  );
}

enum _AccountAction { name, email, password }

class _AccountDialog extends StatefulWidget {
  final AppUser user;
  final _AccountAction action;

  const _AccountDialog({required this.user, required this.action});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _confirm = TextEditingController();
  final _authService = AuthService();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.action == _AccountAction.name) {
      _primary.text = widget.user.name;
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _title => switch (widget.action) {
    _AccountAction.name => 'Ubah Nama',
    _AccountAction.email => 'Ganti Email',
    _AccountAction.password => 'Ganti Password',
  };

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (FirebaseAuth.instance.currentUser?.uid != widget.user.uid) {
      setState(
        () => _error =
            'Sesi akun berubah. Masuk kembali sebelum mengubah profil.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String? error;
      switch (widget.action) {
        case _AccountAction.name:
          error = await _authService.updateSurveyorName(
            widget.user.uid,
            _primary.text.trim(),
          );
          break;
        case _AccountAction.email:
          error = await _authService.requestEmailChange(
            newEmail: _primary.text.trim(),
            currentPassword: _secondary.text,
          );
          break;
        case _AccountAction.password:
          error = await _authService.updateOwnPassword(
            currentPassword: _primary.text,
            newPassword: _secondary.text,
          );
          break;
      }
      if (!mounted) {
        return;
      }
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      Navigator.pop(
        context,
        widget.action == _AccountAction.password
            ? 'updated'
            : _primary.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Perubahan belum berhasil. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(_title),
        scrollable: true,
        content: SizedBox(
          width: 360,
          child: AbsorbPointer(
            absorbing: _busy,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ..._fields(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.action == _AccountAction.email
                        ? 'Kirim Verifikasi'
                        : 'Simpan',
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields() {
    if (widget.action == _AccountAction.name) {
      return [
        TextFormField(
          controller: _primary,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Isi nama lengkap.'
              : null,
        ),
      ];
    }
    if (widget.action == _AccountAction.email) {
      return [
        Text(
          'Email saat ini: ${widget.user.email}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _primary,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email Baru'),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
              return 'Masukkan email yang valid.';
            }
            if (email.toLowerCase() == widget.user.email.toLowerCase()) {
              return 'Email baru masih sama dengan email saat ini.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _passwordField(_secondary, 'Password Saat Ini'),
        const SizedBox(height: 12),
        const Text(
          'Link verifikasi akan dikirim ke email baru. Email saat ini tetap '
          'digunakan sampai verifikasi selesai.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ];
    }
    return [
      _passwordField(_primary, 'Password Saat Ini'),
      const SizedBox(height: 12),
      _passwordField(
        _secondary,
        'Password Baru',
        validator: (value) => value == null || value.length < 6
            ? 'Password minimal 6 karakter.'
            : null,
      ),
      const SizedBox(height: 12),
      _passwordField(
        _confirm,
        'Konfirmasi Password Baru',
        validator: (value) => value != _secondary.text
            ? 'Konfirmasi password tidak cocok.'
            : null,
      ),
    ];
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    validator:
        validator ??
        ((value) => value == null || value.isEmpty ? 'Isi password.' : null),
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
