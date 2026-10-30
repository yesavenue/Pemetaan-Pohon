String authMessage(String code) => switch (code) {
  'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' =>
    'Email atau password tidak sesuai. Periksa kembali lalu coba lagi.',
  'invalid-email' => 'Masukkan alamat email yang valid.',
  'user-disabled' => 'Akun dinonaktifkan. Hubungi pengelola untuk bantuan.',
  'too-many-requests' => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
  'network-request-failed' => 'Koneksi terputus. Periksa internet lalu coba lagi.',
  _ => 'Permintaan belum berhasil. Coba lagi atau hubungi pengelola.',
};
