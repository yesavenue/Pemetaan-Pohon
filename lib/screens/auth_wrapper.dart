import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'public_home_screen.dart';
import 'force_password_screen.dart';
import 'admin_dashboard.dart';
import 'surveyor_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final User? firebaseUser = snapshot.data;

        // Belum login: masuk ke Beranda publik (bisa lihat semuanya tanpa
        // akun). Tombol "Login" ada di navbar/hamburger menu di situ.
        if (firebaseUser == null) {
          return const PublicHomeScreen();
        }

        return FutureBuilder<AppUser?>(
          future: authService.getUserData(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final AppUser? appUser = userSnapshot.data;

            if (appUser == null || !appUser.isActive) {
              authService.logout();
              return const PublicHomeScreen();
            }

            // Kalau email di Firebase Auth sudah beda dari yang tersimpan
            // di Firestore (mis. surveyor baru saja verifikasi link ganti
            // email), sinkronkan otomatis di sini tanpa aksi manual.
            AppUser effectiveUser = appUser;
            if (firebaseUser.email != null && firebaseUser.email != appUser.email) {
              effectiveUser = appUser.copyWith(email: firebaseUser.email);
              authService.reconcileEmail(appUser.uid, firebaseUser.email!);
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