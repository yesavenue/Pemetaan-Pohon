# Pemetaan Pohon Kota Cirebon

Pemetaan Pohon Kota Cirebon membantu mengatasi sulitnya mengetahui lokasi, jenis, dan kondisi pohon yang tercatat di wilayah kota. Melalui peta dan pendataan terpusat, warga dapat melihat informasi pohon terverifikasi, sementara petugas dan admin dapat mencatat, meninjau, serta mengelola data untuk mendukung pemeliharaan ruang hijau dan perhatian terhadap pohon yang rawan tumbang.

## Gambaran Umum

Aplikasi Flutter ini menyediakan antarmuka publik berbasis web dan alur kerja untuk petugas survei serta admin. Pengunjung dapat menjelajahi peta dan statistik tanpa login, atau mengirim permohonan perapihan pohon. Surveyor masuk dengan akun aktif untuk mencatat pohon dan mengelola catatan miliknya. Admin mengawasi pendataan, meninjau pengajuan, mengelola surveyor, dan menangani permohonan warga.

Data pohon yang dicatat surveyor berstatus menunggu verifikasi. Admin dapat memeriksa dan mengubah statusnya; hanya pohon terverifikasi yang ditampilkan sebagai data publik. Status kondisi pohon merupakan catatan pendataan, bukan hasil prediksi otomatis.

## Fitur Utama

### Publik

- **Beranda dan peta pohon:** beranda menampilkan ringkasan serta pratinjau peta. Peta lengkap menyediakan pencarian dan filter wilayah, jenis, kondisi, serta urutan waktu. Pengunjung dapat memilih titik atau melihat daftar pohon dan detail yang tersedia. Pengelompokan penanda membantu membaca sebaran saat titik berdekatan.
- **Detail dan kondisi pohon:** informasi yang ditampilkan mencakup jenis, kondisi, lokasi, dan keterangan yang tersedia. Peta dan statistik publik menggunakan data terverifikasi, sehingga catatan yang masih menunggu atau ditolak tidak tercampur dengan inventaris publik.
- **Statistik:** ringkasan dan grafik menyajikan jumlah pohon menurut kondisi, jenis, dan kecamatan. Pengunjung dapat memfilter wilayah serta beralih ke tampilan tabel.
- **Permohonan perapihan pohon:** formulir bertahap mengumpulkan informasi pemohon, lokasi dan alasan permohonan, serta foto pohon dan KTP. Nomor permohonan diberikan setelah pengajuan. Data permohonan memuat informasi pribadi; gunakan dengan kehati-hatian dan hindari mengirim data nyata saat pengujian.

### Surveyor

- **Pendataan pohon:** surveyor mencatat jenis, kondisi, wilayah, alamat, ranah kewenangan, koordinat, keterangan kondisi, dan foto. Lokasi dapat dipilih lewat peta atau perangkat. Catatan baru dikirim untuk ditinjau admin.
- **Beranda, peta, dan detail:** dashboard merangkum catatan milik surveyor, termasuk input hari ini dan pohon rawan tumbang. Daftar serta peta membantu mencari catatan; detail menyediakan akses untuk mengubah atau menghapus data milik sendiri.
- **Tindak lanjut hasil tinjauan:** surveyor dapat melihat pohon yang ditolak beserta alasan admin, menandai pemberitahuan telah dibaca, lalu memperbaiki dan mengirim ulang catatan.
- **Profil dan keamanan akun:** tersedia pengelolaan profil, perubahan kata sandi atau email, dan logout. Akun yang diwajibkan mengganti kata sandi akan diarahkan ke langkah tersebut setelah masuk.

### Admin

- **Ringkasan dan verifikasi:** dashboard merangkum data pohon, surveyor, dan permohonan. Admin dapat menambah atau mengubah catatan, meninjau pengajuan, memverifikasi, menolak dengan alasan, mengubah status, atau menghapus data. Entri pohon manual admin langsung berstatus terverifikasi.
- **Pengelolaan surveyor:** admin dapat membuat akun surveyor, memperbarui nama, mengaktifkan atau menonaktifkan akun, mengirim instruksi reset kata sandi, dan menghapus profil.
- **Permohonan warga:** admin dapat meninjau detail dan foto, memperbarui status permohonan, mengunduh foto, serta menghasilkan dokumen surat permohonan.
- **Ekspor dan sinkronisasi peta:** data pohon dapat dipilih dan diekspor sebagai Excel. Tersedia pula tindakan untuk menyelaraskan proyeksi data pohon terverifikasi untuk pembacaan publik.
- **Data contoh:** admin memiliki tindakan untuk membuat atau menghapus 30 catatan simulasi. Lokasi dan ilustrasinya adalah data contoh, bukan pendataan lapangan; jangan memperlakukannya sebagai data nyata.

## Peran Pengguna

| Peran | Akses dan tanggung jawab |
|---|---|
| Pengunjung publik | Tanpa login; melihat peta, detail, statistik, informasi aplikasi, dan mengajukan permohonan perapihan. |
| Surveyor | Akun aktif diperlukan; mendata dan mengelola pohon miliknya serta menindaklanjuti hasil tinjauan. |
| Admin | Akun aktif diperlukan; mengelola surveyor, pohon, verifikasi, permohonan, dan ekspor. |

## Teknologi

| Teknologi atau paket | Penggunaan |
|---|---|
| Flutter dan Dart | Antarmuka lintas platform; batas SDK Dart pada manifest adalah `^3.7.2`. |
| `firebase_core`, `firebase_auth`, `cloud_firestore` | Inisialisasi Firebase, autentikasi, dan penyimpanan serta aliran data Firestore. |
| `flutter_map`, `latlong2`, `flutter_map_marker_cluster` | Peta, koordinat, dan pengelompokan penanda. Peta menggunakan tile OpenStreetMap. |
| `fl_chart` | Grafik statistik. |
| `image_picker`, `image` | Pemilihan dan pengolahan gambar. |
| `geolocator` | Akses lokasi perangkat. |
| `excel`, `archive`, `xml` | Ekspor Excel serta penyusunan dokumen arsip. |
| `web`, `url_launcher` | Integrasi fitur unduhan web dan pembukaan tautan. |
| `crypto`, `google_fonts`, `package_info_plus`, `cupertino_icons` | Utilitas pendukung, font, informasi aplikasi, dan ikon. |

Versi paket mengikuti batas versi yang dicantumkan di `pubspec.yaml`; paket pengujian dan lint mencakup `flutter_test` serta `flutter_lints`.

## Struktur Proyek

```text
lib/
  main.dart
  models/          Model pengguna, pohon, dan permohonan
  screens/         Layar publik, autentikasi, admin, dan surveyor
  services/        Akses autentikasi dan Firebase
  view_models/     Agregasi serta state untuk tampilan
  widgets/         Komponen UI publik, admin, dan surveyor
  utils/           Peta, lokasi, ekspor, gambar, dan utilitas
  theme/           Tema aplikasi
assets/image/      Aset logo dan hero
test/              Pengujian widget dan logika
android/ ios/ web/ linux/ macos/ windows/
firestore.rules    Aturan akses Firestore
pubspec.yaml       SDK, dependensi, dan aset
```

## Persiapan dan Instalasi

Prasyarat: Flutter yang mendukung batas Dart pada `pubspec.yaml`, Git, dan proyek Firebase yang dapat digunakan. Untuk web, siapkan Chrome; untuk menjalankan di perangkat, siapkan perangkat atau emulator yang dikenali Flutter.

```bash
git clone https://github.com/yesavenue/Pemetaan-Pohon.git
cd Pemetaan-Pohon
flutter pub get
```

Aplikasi menginisialisasi Firebase menggunakan `DefaultFirebaseOptions.currentPlatform`. Siapkan konfigurasi platform untuk proyek Firebase yang diotorisasi melalui alur resmi FlutterFire, lalu aktifkan Firebase Authentication dan Cloud Firestore. Pastikan aturan Firestore proyek ditinjau dan dipasang sesuai kebutuhan aplikasi. Jangan menaruh kredensial atau rahasia di README, membagikannya, atau memasukkannya ke repositori publik.

## Menjalankan Aplikasi

Pada web, mode bawaan adalah aplikasi publik:

```bash
flutter run -d chrome
```

Mode surveyor dapat dijalankan di web dengan akun surveyor yang sesuai:

```bash
flutter run -d chrome --dart-define=SURVEYOR_APP=true
```

Pada platform non-web, mode bawaan adalah aplikasi surveyor dan memerlukan login:

```bash
flutter devices
flutter run -d <device-id>
```

## Pengujian

Jalankan analisis statis dan pengujian Flutter dengan:

```bash
flutter analyze
flutter test
```

Pengujian yang tersedia mencakup widget dan navigasi publik, peta dan pencarian, statistik, formulir permohonan, tampilan admin, penelusuran pohon surveyor, model data, ekspor Excel, pengelolaan sesi, serta utilitas seperti pengelompokan titik dan pemrosesan foto. Perintah tersebut menjalankan pemeriksaan; dokumentasi ini tidak menyatakan hasil tes tertentu atau kesiapan produksi.
