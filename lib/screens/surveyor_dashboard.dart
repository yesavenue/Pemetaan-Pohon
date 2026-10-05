import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'surveyor_profile_screen.dart';
import 'tree_input_screen.dart';

class SurveyorDashboard extends StatefulWidget {
  final AppUser surveyorUser;

  const SurveyorDashboard({
    super.key,
    required this.surveyorUser,
  });

  @override
  State<SurveyorDashboard> createState() => _SurveyorDashboardState();
}

class _SurveyorDashboardState extends State<SurveyorDashboard> {
  final _authService = AuthService();
  String? _mySessionId;
  StreamSubscription<String?>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _registerSession();
  }

  // Setiap kali dashboard ini dibuka (login baru ATAU sekadar refresh
  // halaman), device/tab ini "mengklaim" jadi sesi aktif. Kalau nanti
  // ada device/tab lain yang login dan mengklaim ulang, listener di
  // bawah akan mendeteksi perubahan dan logout otomatis di sini.
  Future<void> _registerSession() async {
    final sessionId = await _authService.registerDeviceSession(widget.surveyorUser.uid);
    if (!mounted) return;
    _mySessionId = sessionId;

    _sessionSub = _authService.watchActiveSessionId(widget.surveyorUser.uid).listen((remoteId) {
      if (_mySessionId != null && remoteId != null && remoteId != _mySessionId) {
        _handleKickedOut();
      }
    });
  }

  Future<void> _handleKickedOut() async {
    _sessionSub?.cancel();
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sesi Berakhir'),
        content: const Text(
          'Akun ini baru saja login di perangkat/tab lain. Anda akan keluar dari sesi ini.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _authService.logout();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemetaan Pohon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile Saya',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SurveyorProfileScreen(surveyorUser: widget.surveyorUser)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _authService.logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.leaf.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.park, size: 48, color: AppColors.leaf),
            ),
            const SizedBox(height: 20),
            Text(
              'Selamat bertugas, ${widget.surveyorUser.name}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol di bawah untuk mulai mendata pohon di lapangan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TreeInputScreen(surveyorUser: widget.surveyorUser),
                    ),
                  );
                },
                icon: const Icon(Icons.add_a_photo, size: 26),
                label: const Text(
                  'INPUT DATA POHON',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}