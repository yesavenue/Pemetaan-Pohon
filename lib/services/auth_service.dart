import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user.dart';
import '../utils/surveyor_provisioning.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return AppUser.fromMap(uid, doc.data()!);
      }
    } catch (_) {
      // Pemanggil menangani profil yang tidak tersedia.
    }

    return null;
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Terjadi kesalahan saat login';
    }
  }

  Future<String?> updateFirstPassword(
    String newPassword,
    AppUser appUser,
  ) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        await currentUser.updatePassword(newPassword);

        await _firestore.collection('users').doc(appUser.uid).update({
          'requiresPasswordChange': false,
        });

        return null;
      }

      return 'Sesi tidak ditemukan. Silakan login ulang.';
    } catch (e) {
      return 'Gagal mengganti password: ${e.toString()}';
    }
  }

  Future<String?> createSurveyorByAdmin(
    String name,
    String email,
    String defaultPassword,
  ) async {
    FirebaseApp? temporaryApp;
    FirebaseAuth? temporaryAuth;
    User? createdUser;

    return provisionSurveyor(
      createAccount: () async {
        temporaryApp = await Firebase.initializeApp(
          name:
              'SurveyorProvision-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
          options: Firebase.app().options,
        );

        temporaryAuth = FirebaseAuth.instanceFor(
          app: temporaryApp!,
        );

        final credential =
            await temporaryAuth!.createUserWithEmailAndPassword(
          email: email.trim(),
          password: defaultPassword,
        );

        createdUser = credential.user;

        if (createdUser == null) {
          throw StateError('Missing new account');
        }

        return createdUser!.uid;
      },
      writeProfile: (uid) => _firestore.collection('users').doc(uid).set(
            AppUser(
              uid: uid,
              email: email.trim(),
              role: UserRole.surveyor,
              name: name.trim(),
              requiresPasswordChange: true,
              isActive: true,
            ).toMap(),
          ),
      profileExistsOnServer: (uid) async {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));

        return snapshot.exists;
      },
      deleteNewAccount: () async {
        if (createdUser == null) {
          throw StateError('No new account to cancel');
        }

        await createdUser!.delete();
      },
      cleanup: () async {
        try {
          await temporaryAuth?.signOut();
        } finally {
          await temporaryApp?.delete();
        }
      },
    );
  }

  Stream<List<AppUser>> streamSurveyors() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((user) => user.role == UserRole.surveyor)
          .toList();

      users.sort((a, b) => a.name.compareTo(b.name));

      return users;
    });
  }

  // Mengubah status aktif profil Firestore.
  // Tidak menonaktifkan akun Firebase Authentication secara langsung.
  Future<String?> setSurveyorActiveStatus(
    String uid,
    bool isActive,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': isActive,
      });

      return null;
    } catch (e) {
      return 'Gagal mengubah status: ${e.toString()}';
    }
  }

  Future<String?> updateSurveyorName(
    String uid,
    String newName,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': newName,
      });

      return null;
    } catch (e) {
      return 'Gagal memperbarui nama: ${e.toString()}';
    }
  }

  // Menghapus profil Firestore saja.
  // Akun Firebase Authentication tidak ikut dihapus.
  Future<String?> deleteSurveyorProfile(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();

      return null;
    } catch (e) {
      return 'Gagal menghapus surveyor: ${e.toString()}';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengirim email reset password';
    }
  }

  Future<String?> updateOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.email == null) {
        return 'Sesi tidak ditemukan. Silakan login ulang.';
      }

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengganti password';
    }
  }

  Future<String?> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null || user.email == null) {
        return 'Sesi tidak ditemukan. Silakan login ulang.';
      }

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengirim verifikasi email baru';
    }
  }

  // Penanda sesi perangkat surveyor.
  // Listener aplikasi menangani pergantian sesi.
  String _generateSessionId() {
    final rand = Random();

    return '${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(999999)}';
  }

  Future<String> registerDeviceSession(String uid) async {
    final sessionId = _generateSessionId();

    await _firestore.collection('users').doc(uid).update({
      'activeSessionId': sessionId,
    });

    return sessionId;
  }

  Stream<String?> watchActiveSessionId(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['activeSessionId'] as String?);
  }

  Future<void> reconcileEmail(
    String uid,
    String currentAuthEmail,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'email': currentAuthEmail,
      });
    } catch (_) {
      // Sinkronisasi dapat dicoba kembali pada sesi berikutnya.
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}