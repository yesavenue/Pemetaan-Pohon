/// Coordinates compensating actions without depending on Firebase in tests.
/// Null means success; an error message means the admin must inspect/retry.
Future<String?> provisionSurveyor({
  required Future<String> Function() createAccount,
  required Future<void> Function(String uid) writeProfile,
  required Future<bool?> Function(String uid) profileExistsOnServer,
  required Future<void> Function() deleteNewAccount,
  required Future<void> Function() cleanup,
}) async {
  String? uid;
  try {
    uid = await createAccount();
    try {
      await writeProfile(uid);
      return null;
    } catch (_) {
      bool? exists;
      try {
        exists = await profileExistsOnServer(uid);
      } catch (_) {
        exists = null;
      }
      if (exists == true) return null;
      if (exists == false) {
        try {
          await deleteNewAccount();
          return 'Profil gagal disimpan. Akun baru sudah dibatalkan; periksa koneksi dan coba lagi.';
        } catch (_) {
          return 'Profil gagal disimpan dan akun baru belum berhasil dibatalkan. '
              'Periksa akun UID $uid di Firebase sebelum mencoba lagi.';
        }
      }
      // Never delete an account when the server outcome is unknown.
      return 'Status penyimpanan profil belum dapat dipastikan. '
          'Periksa akun dan profil UID $uid di Firebase sebelum membuat ulang.';
    }
  } catch (_) {
    return 'Akun surveyor belum berhasil dibuat. Periksa email, persyaratan password, dan koneksi; '
        'pastikan email belum terdaftar sebelum mencoba lagi.';
  } finally {
    try {
      await cleanup();
    } catch (_) {
      // Cleanup cannot turn a committed account/profile into a failed creation.
    }
  }
}