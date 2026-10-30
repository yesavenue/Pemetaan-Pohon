# Pemetaan Pohon Kota Cirebon

Aplikasi ini membantu mendata pohon dan memantau kondisinya dalam satu sistem, sehingga informasi lokasi dan kondisi pohon dapat ditinjau oleh petugas serta disajikan kepada publik. Warga juga dapat mengajukan perapihan pohon dan melacak perkembangannya, sementara data yang belum diverifikasi tidak ditampilkan sebagai data publik.

## Gambaran Umum

Aplikasi menyediakan layanan publik berbasis web dan ruang kerja untuk surveyor serta admin. Alur pendataan dimulai dari surveyor yang mencatat lokasi, jenis, kondisi, dan foto pohon. Admin meninjau catatan tersebut; hanya data berstatus terverifikasi yang dipublikasikan. Warga dapat menjelajahi peta dan statistik pohon, lalu mengirim permohonan perapihan secara terpisah dari proses pendataan pohon.

Aplikasi menggunakan Firebase Authentication untuk sesi akun dan Cloud Firestore untuk data. Mode awal ditentukan oleh platform: build web membuka halaman publik, sedangkan build native membuka alur aplikasi surveyor. Mode surveyor juga dapat dipilih saat menjalankan versi web untuk keperluan uji coba.

## Fitur Utama

### Publik

- **Beranda dan peta pohon:** beranda menampilkan ringkasan pohon terverifikasi serta pratinjau peta. Peta lengkap menyediakan pencarian dan filter berdasarkan kecamatan, kelurahan, jenis, dan kondisi, serta pengurutan data. Marker menggunakan pengelompokan agar sebaran pohon lebih mudah dijelajahi. Daftar tetap dapat menampilkan catatan yang koordinatnya belum valid.
- **Detail pohon:** warga dapat melihat informasi yang dipublikasikan, seperti jenis, kondisi, alamat, kecamatan, kelurahan, dan koordinat. Dari detail, warga dapat membuka formulir permohonan untuk pohon tersebut atau menyalin tautan lokasi.
- **Statistik:** ringkasan dan grafik menyajikan jumlah pohon berdasarkan kondisi, jenis, dan kecamatan; statistik dapat difokuskan ke kecamatan tertentu.
- **Permohonan perapihan dan pelacakan:** formulir mengumpulkan data pemohon, keterangan pohon, lokasi, serta foto pohon dan identitas. Setelah pengajuan, aplikasi memberikan nomor permohonan dan kode akses untuk melihat status serta riwayat pembaruan. Kode akses perlu dijaga karena digunakan untuk membuka informasi pelacakan.
- **Informasi layanan:** halaman Tentang memuat penjelasan dan informasi layanan publik.

### Surveyor

- **Pendataan pohon:** surveyor dapat membuat atau memperbarui catatan yang mencakup lokasi, jenis pohon, kondisi, keterangan, ranah kewenangan, dan foto. Lokasi dapat ditentukan pada peta; aplikasi juga memeriksa kedekatan dengan data pohon lain untuk membantu menghindari pencatatan ganda.
- **Peta dan daftar inventaris:** surveyor dapat mencari serta memfilter pohonnya berdasarkan kondisi dan informasi lokasi, lalu membuka detail catatan.
- **Tinjauan admin:** catatan memiliki status menunggu verifikasi, terverifikasi, atau perlu perbaikan. Catatan yang ditolak dapat disertai alasan; surveyor dapat membaca umpan balik, memperbaiki data, dan mengirimkannya kembali untuk ditinjau.
- **Beranda dan profil:** beranda merangkum data milik surveyor, termasuk jumlah pohon dan pohon yang rawan tumbang. Profil menyediakan pengelolaan informasi akun.

### Admin

- **Ringkasan dan pengelolaan surveyor:** admin dapat melihat ringkasan, menambahkan akun surveyor, memperbarui nama, mengubah status aktif, dan menghapus profil.
- **Verifikasi data pohon:** admin meninjau catatan, menyetujui atau menolak dengan alasan, serta mengelola data pohon. Data terverifikasi dipublikasikan; catatan yang tidak terverifikasi tidak masuk ke tampilan publik.
- **Ekspor laporan:** admin dapat memilih data pohon untuk diekspor sebagai Excel. Data permohonan dapat dibuat menjadi dokumen Word.
- **Pengelolaan permohonan:** admin meninjau pengajuan, memperbarui status penanganan, memberi alasan jika menolak, dan melihat riwayat perubahan. Pengajuan tidak otomatis berarti pekerjaan telah disetujui.
- **Data contoh:** tersedia tindakan khusus untuk menambahkan atau menghapus data contoh yang ditandai aplikasi. Data tersebut adalah data demonstrasi, bukan hasil survei lapangan.

## Peran Pengguna

| Peran | Akses dan tanggung jawab |
|---|---|
| Publik | Mengakses halaman web tanpa masuk akun; melihat pohon terverifikasi, statistik, dan informasi layanan; mengajukan serta melacak permohonan dengan kode akses. |
| Surveyor | Masuk dengan akun surveyor aktif; mendata dan mengelola catatan pohon miliknya, serta menindaklanjuti hasil verifikasi admin. |
| Admin | Masuk melalui web dengan akun admin aktif; mengelola surveyor, meninjau data pohon, menangani permohonan, dan mengekspor laporan. |

Aplikasi memeriksa profil dan status aktif akun. Akun yang diwajibkan mengganti kata sandi diarahkan ke layar penggantian sebelum masuk ke dashboard. Aplikasi native dibatasi untuk akun surveyor; akun admin digunakan melalui web.

## Teknologi

Versi di bawah mengikuti deklarasi pada `pubspec.yaml`; tanda `^` dipertahankan sebagaimana tercantum di sana.

| Teknologi atau paket | Versi yang dideklarasikan | Penggunaan |
|---|---:|---|
| Flutter dan Dart | Dart `^3.7.2` | Antarmuka dan logika aplikasi; Flutter menggunakan SDK yang dipasang di lingkungan pengembang. |
| `firebase_core`, `firebase_auth`, `cloud_firestore` | `^3.12.1`, `^5.5.1`, `^5.6.2` | Inisialisasi Firebase, autentikasi, dan penyimpanan serta aliran data Firestore. |
| `flutter_map`, `latlong2`, `flutter_map_marker_cluster` | `^8.3.2`, `0.9.1`, `^8.2.2` | Peta, koordinat, dan pengelompokan marker; tile peta menggunakan OpenStreetMap. |
| `fl_chart` | `0.69.2` | Grafik statistik publik. |
| `image_picker`, `image`, `geolocator` | `^1.2.1`, `4.2.0`, `^14.0.2` | Pemilihan dan pemrosesan foto serta akses lokasi perangkat. |
| `excel`, `archive`, `xml` | `^4.0.6`, `^3.6.1`, `^6.5.0` | Pembuatan ekspor Excel dan dokumen permohonan. |
| `web`, `url_launcher` | `^1.1.1`, `^6.3.2` | Integrasi fungsi web dan pembukaan tautan. |
| Paket pendukung lain | `crypto ^3.0.6`, `google_fonts ^6.3.2`, `package_info_plus 8.3.1`, `cupertino_icons ^1.0.8` | Fungsi kriptografi, tipografi, informasi paket, dan ikon. |

## Struktur Proyek

```text
lib/
  main.dart
  models/          Model akun, data pohon, dan permohonan
  screens/         Layar publik, admin, autentikasi, dan input pohon
    surveyor/      Beranda, peta, daftar, dan detail surveyor
  services/        Akses autentikasi dan operasi data Firebase
  theme/           Tema aplikasi
  utils/           Pemetaan wilayah, lokasi, ekspor, dan fungsi pendukung
  view_models/     Pengolahan data untuk ringkasan, peta, dan statistik
  widgets/         Komponen bersama serta komponen publik/admin/surveyor
test/              Pengujian unit dan widget
assets/             Aset visual aplikasi
android/, ios/,
linux/, macos/,
web/, windows/      Berkas target platform Flutter
firestore.rules     Aturan akses Cloud Firestore
pubspec.yaml        SDK dan dependensi proyek
```

## Persiapan dan Instalasi

**Prasyarat:** Flutter SDK yang mendukung batas Dart `^3.7.2`, Git, dan browser Chrome untuk menjalankan web. Siapkan pula proyek Firebase yang akan digunakan oleh aplikasi.

```bash
git clone https://github.com/yesavenue/Pemetaan-Pohon.git
cd Pemetaan-Pohon
flutter pub get
```

Konfigurasikan Firebase untuk target platform yang akan dijalankan menggunakan perangkat dan alur konfigurasi Firebase/FlutterFire resmi. Konfigurasi aplikasi harus dibuat secara lokal untuk proyek Firebase milik Anda. Aktifkan metode masuk email dan kata sandi serta siapkan Cloud Firestore dengan aturan akses yang sesuai sebelum menguji operasi data. Jangan menaruh kredensial, kunci privat, atau data sensitif di repositori maupun membagikannya melalui tangkapan layar atau log.

## Menjalankan Aplikasi

Jalankan layanan publik di Chrome:

```bash
flutter run -d chrome
```

Untuk melihat mode surveyor di Chrome:

```bash
flutter run -d chrome --dart-define=SURVEYOR_APP=true
```

Untuk menjalankan pada perangkat atau emulator yang terdeteksi Flutter:

```bash
flutter devices
flutter run -d <device_id>
```

Build native secara default menggunakan mode surveyor. Akun admin harus masuk melalui web, sedangkan dashboard berfitur masuk memerlukan akun yang sudah disiapkan di Firebase.

## Pengujian

Jalankan analisis statis dan pengujian Flutter dengan:

```bash
flutter analyze
flutter test
```

Pengujian yang tersedia mencakup model dan status pohon, pemisahan data publik dan privat, filter serta pencarian peta, statistik, alur permohonan dan pelacakan, pengelolaan admin, ekspor Excel, serta widget dan interaksi publik maupun surveyor. Perintah di atas menjalankan pemeriksaan; dokumentasi ini tidak menyatakan hasil lulus atau kesiapan produksi.
