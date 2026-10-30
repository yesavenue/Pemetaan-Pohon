# Beranda publik ringan + aplikasi Flutter — petunjuk pemasangan

Basis kode: commit `ebd0597ac4f68c3fe900a415e2f903e56c1344ab` dari repositori yesavenue/Pemetaan-Pohon, diambil 30 Oktober 2026.

## Ikon tanpa tulisan

Ikon Flutter pada tab browser, Apple touch icon, dan ikon aplikasi web diganti simbol pohon saja. Logo lengkap di navbar/footer tetap dipertahankan. Ikon biasa transparan; ikon maskable memiliki latar terang dengan margin aman. Ukuran: 64, 180, 192, dan 512 piksel. Nama favicon baru menghindari cache ikon Flutter lama. Ikon Android/iOS native belum diganti dalam paket web ini.

Simbol dipisahkan dengan ImageGen (built-in), lalu dikemas ke ukuran ikon. Prompt: ambil hanya emblem pohon di kiri, hapus seluruh tulisan, pertahankan bentuk/warna, latar transparan.

## Hasil perubahan

- `/` menjadi halaman HTML/CSS/JavaScript dengan desain hero, warna, slogan, logo, pelacakan, kartu, ringkasan, pratinjau peta, panduan, dan footer.
- `/app/` tetap aplikasi Flutter. Tautan beranda membuka fitur yang sesuai melalui hash: peta, statistik, permohonan, pelacakan, tentang, dan login.
- Flutter dan CanvasKit tidak dimuat saat membuka beranda. Aplikasi baru dimuat saat layanan aplikasinya dibuka.
- Kartu akses cepat sama tinggi di desktop dan judulnya memiliki posisi atas yang sama. Teks tetap utuh. Perbaikan juga diterapkan pada beranda Flutter cadangan.
- Hero tetap WebP mobile/desktop dan dimuat segera. Logo diperkecil menjadi WebP lossless sekitar 22 KB. Tidak ada font eksternal pada beranda.
- Ringkasan meminta hanya koordinat, kondisi, jenis, dan status dari `public_trees` melalui REST projection. Foto Base64 tidak ikut diunduh. Data dimuat ketika bagian ringkasan mendekati viewport; ada waktu pembaruan dan tombol Perbarui data. Ringkasan bukan langganan realtime.
- Peta pratinjau baru dimuat ketika tombol Aktifkan peta ditekan. Filter kondisi dan tautan detail pohon tersedia. OpenStreetMap tetap digunakan dengan atribusi. Tidak ada data/angka contoh.
- Pengiriman kode pelacakan memakai fragmen URL, bukan query HTTP. Format 16 karakter dan format lama 64 karakter dipertahankan.
- Formulir, role admin/surveyor, pemeriksaan akun, verifikasi, dokumen dan Firestore rules tidak diubah.
- `robots.txt`, sitemap, canonical, metadata, zoom, label kontrol, keyboard, dan reduced-motion tersedia pada beranda.
- Aset statis memakai nama ber-hash dan cache immutable; HTML dan aplikasi harus revalidasi. Tidak ada catch-all yang mengubah asset/robots yang hilang menjadi HTML.
- Worker Flutter pada root lama dihentikan agar pembaruan beranda dapat terlihat. Aplikasi tetap berada di scope `/app/`.
- Build menolak gambar yang hanya berganti ekstensi menjadi `.webp` tetapi masih berformat PNG.

## Apa yang sudah diuji

- JavaScript syntax dan tes `scripts/test-public-site.mjs`: lolos.
- HTML: ID unik, satu h1, aset ada, zoom diizinkan, tidak memuat bootstrap Flutter, kode tidak dikirim sebagai form query.
- Firestore: projection, pagination 200 dokumen/halaman, kondisi lama, hasil kosong, dan error HTTP diuji.
- Pembacaan data publik sungguhan: 30 pohon, respons sekitar 20.694 byte, tanpa foto Base64.
- Browser desktop: ketiga kartu sama tinggi sekitar 137 px; filter sakit menghasilkan 6 penanda dari total 30.
- Viewport ponsel 390 px melalui iframe QA: tidak ada overflow horizontal; validasi kode salah bekerja. Ini pemeriksaan layout, bukan pengujian perangkat HP fisik.
- Parser Dart: file yang diubah tidak memiliki syntax error. Ini bukan pengganti `flutter analyze` atau widget tests.
- Flutter SDK otomatis tidak berhasil divalidasi karena pemeriksaan keamanan lingkungan menolak proses yang mengakses metadata cloud. `flutter analyze`, widget tests, dan build aplikasi harus dijalankan lokal sebelum merge.
- Latar tile OpenStreetMap ditolak oleh layanan tersebut dari browser cloud pengujian; geometri dan filter marker berjalan. Uji latar peta dari preview Vercel/perangkat Anda diperlukan.
- Tidak ada skor Lighthouse baru yang diklaim. Skor baru harus diukur pada deployment preview dan produksi.

Perkiraan jumlah ukuran file awal (sebelum gzip/Brotli dan header): mobile sekitar 202 KiB; desktop sekitar 538 KiB. Angka ini mencakup HTML, CSS, JS awal, logo, hero yang sesuai viewport, dan belum termasuk favicon/data/peta yang dimuat kemudian. Bukan waktu loading atau skor PageSpeed.

## Pasang ke branch preview

Unduh `optimasi-pohon-hybrid.patch` ke folder proyek, sejajar dengan pubspec.yaml. Patch memuat file kode dan logo biner secara utuh; jangan menyalin gambar dari preview browser.

Jalankan satu per satu di PowerShell. Pastikan perubahan pribadi sudah disimpan/di-commit dan Anda berada pada main terbaru. Jangan timpa perubahan lokal jika `git apply --check` gagal.

```powershell
git status
git switch -c perf/public-hybrid
git apply --ignore-space-change --check .\optimasi-pohon-hybrid.patch
git apply --ignore-space-change .\optimasi-pohon-hybrid.patch
```

Jika check gagal, berhenti dan kirim pesan error. Jangan gunakan `--reject` atau menimpa seluruh proyek.

Node.js 20.11+ diperlukan (Node.js 22 cocok). Cek `node --version`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=SURVEYOR_APP=false --base-href /app/
node scripts/assemble-site.mjs
node scripts/test-public-site.mjs
```

Hanya lanjut bila setiap perintah sebelumnya berhasil. Tes tambahan `test/hybrid_public_entry_test.dart` menguji pemetaan tautan, auth gate, kartu sejajar, dan teks besar di layar sempit.

Paket siap deploy berada di `build/site`, bukan `build/web`. Jangan commit folder build. Perintah `flutter run` sendiri masih menjalankan aplikasi Flutter; beranda HTML tampil dari folder hasil rakitan/deployment.

Commit file yang relevan saja:

```powershell
git add lib/main.dart lib/screens/auth_wrapper.dart lib/utils/public_entry.dart lib/widgets/public_navbar.dart lib/widgets/public/public_home_interactions.dart
git add public-site scripts/assemble-site.mjs scripts/test-public-site.mjs scripts/vercel-build.sh vercel.json web/index.html web/manifest.json web/favicon.png web/favicon-pohon.png web/icons test/hybrid_public_entry_test.dart docs/PERFORMANCE_RELEASE.md
git commit -m "Pisahkan beranda ringan dan perbaiki kartu serta pemuatan data"
git push -u origin perf/public-hybrid
```

Vercel Git integration biasanya membuat deployment Preview untuk branch ini. Buka deployment branch `perf/public-hybrid`, pastikan Output Directory mengikuti `vercel.json` yaitu `build/site`, dan Build Command tetap `bash scripts/vercel-build.sh`. Versi Flutter tetap 3.29.3. Jika ada override proyek yang tidak mengikuti file konfigurasi, samakan dengan nilai tersebut.

## Uji Preview sebelum produksi

1. Beranda: hero, logo, tiga kartu, navbar, scroll, serta input pelacakan terlihat baik di desktop dan HP.
2. Klik Jelajahi Peta: membuka `/app/#/peta`, peta dan daftar pohon tampil.
3. Pilih marker pratinjau lalu Lihat detail pohon: aplikasi membuka pohon yang sesuai.
4. Statistik dan Tentang menuju halaman yang sesuai.
5. Ajukan permohonan: formulir tampil; mencoba keluar dari formulir berisi data tetap memunculkan konfirmasi. Hindari mengirim permohonan percobaan ke produksi tanpa kebutuhan.
6. Lacak: gunakan kode uji yang Anda miliki; kode harus berada setelah `#`, bukan sebelum `#`.
7. Masuk: login admin diarahkan sesuai peran; akun nonaktif dan akun yang harus mengganti sandi tetap mengikuti pemeriksaan lama. Logout berjalan.
8. Klik Beranda dari aplikasi: kembali ke HTML di `/`.
9. Refresh `/app/#/peta` dan `/app/#/login`: aplikasi tetap dapat dibuka.
10. Aktifkan peta: tile tampil, marker dan filter sesuai ringkasan; refresh data tidak mengubah kosong menjadi angka palsu.
11. `/robots.txt` berupa teks, bukan HTML. URL asset yang sengaja tidak ada harus 404.
12. Coba tab lama dari deployment sebelum migrasi: setelah worker lama diperbarui, halaman root beralih ke beranda baru. Jika belum terlihat, tutup tab lalu buka kembali.
13. Jalankan PageSpeed untuk mobile dan desktop pada URL yang dapat diakses publik; preview yang memakai proteksi login tidak bisa diukur oleh PageSpeed.

Setelah semua lolos, merge branch ke main lewat GitHub (atau workflow Git Anda). Jangan merge hanya karena preview berstatus Ready: Ready membuktikan build, bukan semua alur telah diuji.

## Batas lingkup dan audit lanjutan

- Migrasi foto Base64 ke penyimpanan berkas belum dilakukan. Beranda sudah menghindari pengunduhan foto lewat projection; peta penuh/aplikasi Flutter masih mengikuti model data lama.
- Ini mengoptimalkan halaman masuk publik. Nilai 100 pada beranda tidak berarti nilai 100 pada setiap halaman aplikasi.
- Perlu ukur ulang LCP, CLS, TBT, Accessibility, Best Practices, dan SEO setelah deploy, bukan membandingkan laporan lama.
- Foto 156/492 KiB dipertahankan. Tidak mengurangi kualitas lagi demi mengejar skor.
- Perlu periksa kebijakan/kapasitas tile provider untuk pemakaian operasional yang meningkat. Paket tidak menambahkan penyedia berbayar atau credential baru.
- Tidak ada database migration, perubahan Firestore rules, upgrade dependency mayor, atau akses admin baru pada patch ini.

## Jika perlu membatalkan

Sebelum merge, situs produksi tetap memakai main. Cukup jangan merge branch preview. Setelah merge, gunakan revert commit perubahan ini dan deploy kembali; jangan menghapus database atau mengubah aturan akses. File beranda Flutter lama tetap tersedia sebagai fallback `/app/#/beranda`.
