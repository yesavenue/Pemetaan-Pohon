import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(uid, doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      // Diabaikan untuk production linter
    }
    return null;
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; 
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Terjadi kesalahan saat login';
    }
  }

  Future<String?> updateFirstPassword(String newPassword, AppUser appUser) async {
    try {
      User? currentUser = _auth.currentUser;
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

  // DIPERBARUI: Otomatis mendaftarkan data ke Auth DAN Cloud Firestore sekaligus
  Future<String?> createSurveyorByAdmin(String name, String email, String defaultPassword) async {
    try {
      // 1. Buat instance Firebase sekunder agar sesi Admin utama tidak ter-logout
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TemporaryApp',
        options: Firebase.app().options,
      );

      // 2. Buat akun di Firebase Authentication
      UserCredential credential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: defaultPassword);

      String newUid = credential.user!.uid;

      // 3. Simpan profil data Surveyor ke Cloud Firestore menggunakan UID yang sama persis
      AppUser newUser = AppUser(
        uid: newUid,
        email: email,
        role: UserRole.surveyor,
        name: name,
        requiresPasswordChange: true, // Wajib ganti password saat login pertama
        isActive: true,
      );

      await _firestore.collection('users').doc(newUid).set(newUser.toMap());

      // 4. Hapus instance sementara
      await tempApp.delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // BARU: Stream real-time daftar surveyor untuk halaman List Surveyor.
  // Sengaja filter dilakukan SETELAH parsing ke AppUser (bukan lewat query
  // Firestore where('role', ...)) supaya tidak bergantung pada format
  // string/enum persis yang dipakai toMap()/fromMap() di app_user.dart.
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

  // BARU: Aktifkan / nonaktifkan akun surveyor. Ini hanya menonaktifkan
  // di sisi Firestore (dipakai untuk memblokir akses fitur), BUKAN
  // menghapus/menonaktifkan akun Firebase Auth-nya — itu perlu Cloud
  // Function dengan Admin SDK karena client tidak bisa mengelola akun
  // pengguna lain secara langsung.
  Future<String?> setSurveyorActiveStatus(String uid, bool isActive) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': isActive,
      });
      return null;
    } catch (e) {
      return 'Gagal mengubah status: ${e.toString()}';
    }
  }

  // Hanya mengubah nama tampilan di Firestore. Email TIDAK bisa diubah
  // dari sini karena itu terhubung ke kredensial login Firebase Auth
  // milik surveyor tersebut (ubah email butuh Admin SDK/Cloud Function).
  Future<String?> updateSurveyorName(String uid, String newName) async {
    try {
      await _firestore.collection('users').doc(uid).update({'name': newName});
      return null;
    } catch (e) {
      return 'Gagal memperbarui nama: ${e.toString()}';
    }
  }

  // CATATAN PENTING: ini hanya menghapus profil di Firestore. Akun
  // Firebase Authentication milik surveyor SECARA TEKNIS masih ada
  // (client SDK tidak bisa menghapus akun Auth milik orang lain, itu
  // perlu Admin SDK/Cloud Function). Tapi karena AuthWrapper mem-force
  // logout siapa pun yang profil Firestore-nya tidak ditemukan, efeknya
  // surveyor itu tidak akan bisa lagi mengakses fitur apa pun — jadi
  // secara praktis setara dengan dinonaktifkan permanen.
  Future<String?> deleteSurveyorProfile(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus surveyor: ${e.toString()}';
    }
  }

  // Mengirim email reset password resmi dari Firebase ke surveyor.
  // Ini pengganti "reset ke password default" — client SDK tidak bisa
  // mengubah password akun orang lain secara langsung (itu perlu Admin
  // SDK/Cloud Function). Link di email memungkinkan surveyor membuat
  // password barunya sendiri dengan aman.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengirim email reset password';
    }
  }

  // Mengganti password akun SENDIRI (beda dari reset password admin untuk
  // orang lain — ini diizinkan Firebase karena user mengubah akunnya
  // sendiri). Perlu re-autentikasi dulu (masukkan password lama) karena
  // Firebase mewajibkan sesi login yang masih "segar" untuk aksi sensitif.
  Future<String?> updateOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'Sesi tidak ditemukan. Silakan login ulang.';
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengganti password';
    }
  }

  // Mengganti email akun SENDIRI. Firebase modern mewajibkan verifikasi
  // ke email BARU dulu (klik link) sebelum email benar-benar berubah —
  // jadi ini TIDAK langsung mengubah email saat ini, cuma mengirim link
  // konfirmasi. Firestore baru disinkronkan otomatis setelah verifikasi
  // selesai (lihat pengecekan di AuthWrapper).
  Future<String?> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'Sesi tidak ditemukan. Silakan login ulang.';
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Gagal mengirim verifikasi email baru';
    }
  }

  // ---- Single-device session untuk Surveyor ----
  // Setiap kali surveyor login/membuka dashboard, dibuat "tiket sesi"
  // acak dan ditulis ke Firestore. Device/tab lain yang sedang aktif
  // memantau field ini; begitu nilainya berubah (berarti ada login baru
  // di tempat lain), device lama otomatis logout. Ini penegakan dari
  // sisi aplikasi (Firestore + listener), BUKAN pencabutan token di
  // level server — untuk itu perlu Cloud Function dengan Admin SDK.
  String _generateSessionId() {
    final rand = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${rand.nextInt(999999)}';
  }

  Future<String> registerDeviceSession(String uid) async {
    final sessionId = _generateSessionId();
    await _firestore.collection('users').doc(uid).update({'activeSessionId': sessionId});
    return sessionId;
  }

  Stream<String?> watchActiveSessionId(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['activeSessionId'] as String?);
  }

  // Dipanggil otomatis oleh AuthWrapper saat mendeteksi email Firebase
  // Auth sudah berubah (surveyor baru verifikasi ganti email) tapi
  // Firestore belum tahu — menyamakan keduanya secara diam-diam.
  Future<void> reconcileEmail(String uid, String currentAuthEmail) async {
    try {
      await _firestore.collection('users').doc(uid).update({'email': currentAuthEmail});
    } catch (_) {
      // Gagal sinkron di sini tidak fatal — akan dicoba lagi di sesi berikutnya.
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}