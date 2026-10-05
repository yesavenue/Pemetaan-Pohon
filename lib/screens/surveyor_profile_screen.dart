import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SurveyorProfileScreen extends StatefulWidget {
  final AppUser surveyorUser;
  const SurveyorProfileScreen({super.key, required this.surveyorUser});

  @override
  State<SurveyorProfileScreen> createState() => _SurveyorProfileScreenState();
}

class _SurveyorProfileScreenState extends State<SurveyorProfileScreen> {
  final _authService = AuthService();
  late final _nameController = TextEditingController(text: widget.surveyorUser.name);
  bool _isSavingName = false;

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSavingName = true);
    final error = await _authService.updateSurveyorName(widget.surveyorUser.uid, newName);
    if (!mounted) return;
    setState(() => _isSavingName = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama diperbarui.'), backgroundColor: Colors.green),
      );
    }
  }

  void _showChangeEmailDialog() {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscure = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ganti Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email saat ini: ${widget.surveyorUser.email}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Baru'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password Saat Ini',
                      helperText: 'Diperlukan untuk konfirmasi keamanan',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Link verifikasi akan dikirim ke email baru. Email lama tetap dipakai '
                    'untuk login sampai Anda mengklik link tersebut.',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newEmail = newEmailController.text.trim();
                          final password = passwordController.text;
                          if (newEmail.isEmpty || password.isEmpty) return;

                          setDialogState(() => isSaving = true);
                          final error = await _authService.requestEmailChange(
                            newEmail: newEmail,
                            currentPassword: password,
                          );
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);

                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link verifikasi dikirim ke $newEmail. Cek email tersebut.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim Verifikasi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ganti Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password Saat Ini'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password Baru', helperText: 'Minimal 6 karakter'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final current = currentController.text;
                          final newPass = newController.text;
                          final confirm = confirmController.text;

                          if (current.isEmpty || newPass.isEmpty) return;
                          if (newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password baru minimal 6 karakter.')),
                            );
                            return;
                          }
                          if (newPass != confirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Konfirmasi password tidak cocok.')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final error = await _authService.updateOwnPassword(
                            currentPassword: current,
                            newPassword: newPass,
                          );
                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);

                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password berhasil diubah.'), backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Saya')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppColors.leaf.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.person, size: 44, color: AppColors.leaf),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingName ? null : _saveName,
                      child: _isSavingName
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan Nama'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email & Keamanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: Text(widget.surveyorUser.email),
                    subtitle: const Text('Email login saat ini', style: TextStyle(fontSize: 11)),
                    trailing: TextButton(onPressed: _showChangeEmailDialog, child: const Text('Ganti')),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Password'),
                    subtitle: const Text('••••••••', style: TextStyle(fontSize: 11)),
                    trailing: TextButton(onPressed: _showChangePasswordDialog, child: const Text('Ganti')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}