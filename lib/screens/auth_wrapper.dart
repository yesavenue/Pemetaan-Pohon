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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? firebaseUser = snapshot.data;

        // Belum login: masuk ke Beranda publik (bisa lihat semuanya tanpa
        // akun). Tombol "Login" ada di navbar/hamburger menu di situ.
        if (firebaseUser == null) {
          return isSurveyorApp
              ? const LoginScreen(standalone: true)
              : const PublicHomeScreen();
        }

        return FutureBuilder<AppUser?>(
          future: authService.getUserData(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final AppUser? appUser = userSnapshot.data;

            if (appUser == null || !appUser.isActive) {
              authService.logout();
              return isSurveyorApp
                  ? const LoginScreen(standalone: true)
                  : const PublicHomeScreen();
            }

            // Kalau email di Firebase Auth sudah beda dari yang tersimpan
            // di Firestore (mis. surveyor baru saja verifikasi link ganti
            // email), sinkronkan otomatis di sini tanpa aksi manual.
            AppUser effectiveUser = appUser;
            if (firebaseUser.email != null &&
                firebaseUser.email != appUser.email) {
              effectiveUser = appUser.copyWith(email: firebaseUser.email);
              authService.reconcileEmail(appUser.uid, firebaseUser.email!);
            }

            if (isSurveyorApp && effectiveUser.role != UserRole.surveyor) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Aplikasi khusus surveyor',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Gunakan akun surveyor untuk melanjutkan. Akun admin digunakan melalui website.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => authService.logout(),
                            child: const Text('Keluar dan ganti akun'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (effectiveUser.requiresPasswordChange) {
              return ForcePasswordScreen(appUser: effectiveUser);
            }

            if (effectiveUser.role == UserRole.admin) {
              return AdminDashboard(adminUser: effectiveUser);
            } else {
              return SurveyorDashboard(surveyorUser: effectiveUser);
            }
          },
        );
      },
    );
  }
}