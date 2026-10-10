# Pemetaan Pohon Kota Cirebon

Pohon kota perlu didata agar lokasi, jenis, dan kondisinya dapat diketahui serta ditindaklanjuti. Aplikasi ini membantu surveyor mencatat pohon, menyediakan peta dan ringkasan data yang sudah terverifikasi untuk masyarakat, serta memberi admin sarana untuk mengelola data dan permohonan perapihan.

## Gambaran Umum

Aplikasi Flutter ini menghubungkan pendataan lapangan dengan informasi publik dan alur administrasi. Pengunjung dapat menjelajahi data tanpa akun. Surveyor dan admin masuk menggunakan akun; halaman yang ditampilkan ditentukan oleh profil serta status akun mereka. Akun surveyor dibuat oleh admin, bukan melalui pendaftaran publik.

Secara umum, surveyor mencatat pohon beserta lokasi, kondisi, dan foto. Data baru berstatus menunggu verifikasi. Admin mengelola data dan surveyor, meninjau permohonan warga, serta memverifikasi data pohon. Peta dan statistik publik hanya menggunakan pohon yang berstatus terverifikasi. Data aplikasi menggunakan Firebase Authentication dan Cloud Firestore.

## Fitur Utama

### Publik

- **Beranda dan peta pohon:** Beranda menampilkan pratinjau sebaran pohon terverifikasi. Peta lengkap menyediakan pencarian, filter kecamatan, kelurahan, jenis, dan kondisi, pengurutan berdasarkan waktu, daftar hasil, serta detail pohon. Peta memakai ubin OpenStreetMap; hanya pohon dengan koordinat valid yang ditampilkan sebagai titik.
- **Statistik:** Menyajikan jumlah pohon terverifikasi, kondisi pohon, jenis, dan sebaran per kecamatan, dengan filter kecamatan. Catatan “rawan tumbang” berasal dari pendataan kondisi, bukan prediksi risiko otomatis.
- **Permohonan perapihan:** Formulir publik tanpa login mengumpulkan data pemohon, alamat dan wilayah pohon, alasan, foto pohon, serta foto KTP. Lokasi GPS bersifat opsional. Setelah berhasil, pemohon memperoleh nomor permohonan untuk disimpan; status selanjutnya ditinjau admin.
- **Informasi aplikasi:** Halaman Tentang menjelaskan tujuan pemetaan dan arti kondisi pohon.

### Surveyor

- **Ringkasan dan daftar pohon:** Dashboard merangkum pohon milik surveyor, termasuk jumlah input hari ini dan catatan pohon rawan tumbang. Daftar peta dan hasil pencarian membantu menemukan serta membuka detail data.
- **Input dan pemeliharaan data:** Formulir mencatat jenis, wilayah, jalan, ranah kewenangan, kondisi, keterangan, koordinat, dan foto pohon. Lokasi dapat diperoleh dari GPS atau dipilih pada peta. Aplikasi memperingatkan kemungkinan duplikasi dalam jarak dekat sebelum data disimpan. Surveyor dapat mengubah atau menghapus data miliknya sesuai aturan akses.
- **Profil dan keamanan akun:** Surveyor dapat mengubah nama, mengajukan perubahan email melalui verifikasi, mengganti password, dan keluar dari akun. Pengguna yang diwajibkan mengganti password harus menyelesaikannya sebelum masuk ke dashboard.

### Admin

- **Ringkasan dan pengelolaan surveyor:** Panel menampilkan ringkasan data serta antrean yang perlu ditinjau. Admin dapat membuat akun surveyor, mengaktifkan atau menonaktifkannya, mengubah nama, mengirim tautan reset password, dan menghapus profil surveyor.
- **Pengelolaan pohon:** Admin dapat menambah, mengubah, menghapus, dan memverifikasi data. Daftar mendukung pencarian atau filter dan pemilihan cakupan untuk ekspor Excel.
- **Permohonan perapihan:** Admin dapat melihat detail, foto, dan permohonan, memfilter berdasarkan status, lalu memperbarui status menjadi menunggu, diverifikasi, diproses, selesai, atau ditolak. Penolakan memerlukan alasan. Detail permohonan juga dapat diekspor sebagai dokumen Word.
- **Data contoh:** Panel menyediakan tindakan untuk membuat 30 data pohon contoh dan menghapus data contoh milik admin aktif. Data ini untuk keperluan demo, bukan pengganti data lapangan.

## Peran Pengguna

| Peran | Akses dan tanggung jawab |
|---|---|
| Publik | Tanpa login: melihat beranda, peta dan statistik pohon terverifikasi, informasi aplikasi, serta mengirim permohonan perapihan. |
| Surveyor | Login: mencatat dan mengelola data pohon miliknya, meninjau daftar serta detail pohon, dan mengelola profil sendiri. |
| Admin | Login: mengelola akun surveyor dan data pohon, memverifikasi data, meninjau permohonan, dan mengekspor laporan. |

## Teknologi

| Teknologi atau paket | Penggunaan |
|---|---|
| Flutter dan Dart `^3.7.2` | Aplikasi lintas platform; versi minimum SDK Dart mengikuti batasan di `pubspec.yaml`. |
| `firebase_core ^3.12.1`, `firebase_auth ^5.5.1`, `cloud_firestore ^5.6.2` | Inisialisasi Firebase, autentikasi, dan penyimpanan data. |
| `flutter_map ^8.3.2`, `flutter_map_marker_cluster ^8.2.2`, `latlong2 0.9.1` | Peta, pengelompokan marker, dan koordinat. |
| `geolocator ^14.0.2`, `image_picker ^1.2.1` | Lokasi perangkat dan pengambilan foto. |
| `fl_chart 0.69.2` | Visualisasi statistik. |
| `excel ^4.0.6`, `archive ^3.6.1`, `xml ^6.5.0` | Pembuatan dan pemrosesan berkas laporan. |
| `web ^1.1.1`, `url_launcher ^6.3.2` | Dukungan operasi web dan tautan. |
| `google_fonts ^6.3.2`, `cupertino_icons ^1.0.8` | Tipografi dan ikon antarmuka. |

## Struktur Proyek

```text
.
├── android/, ios/, linux/, macos/, web/, windows/  # konfigurasi target platform
├── assets/image/                                   # logo dan gambar beranda
├── lib/
│   ├── models/                                     # model pengguna, pohon, dan permohonan
│   ├── screens/                                    # layar publik, surveyor, dan admin
│   ├── services/                                   # autentikasi dan operasi data Firebase
│   ├── view_models/                                # filter dan agregasi data untuk tampilan
│   ├── utils/                                      # peta, wilayah, lokasi, dan ekspor
│   ├── widgets/                                    # komponen antarmuka yang digunakan ulang
│   └── theme/                                      # tema aplikasi
├── test/                                           # pengujian Flutter
├── rules_test/                                     # pengujian Firestore Rules
├── firestore.rules                                 # aturan akses Firestore
└── pubspec.yaml                                    # SDK, dependensi, dan aset Flutter
```

## Persiapan dan Instalasi

Prasyarat: Flutter SDK yang kompatibel dengan batasan Dart proyek, Git, serta Chrome atau perangkat yang didukung Flutter. Untuk menjalankan aplikasi dengan data nyata, siapkan project Firebase dengan Firebase Authentication dan Cloud Firestore.

```bash
git clone https://github.com/yesavenue/Pemetaan-Pohon.git
cd Pemetaan-Pohon
flutter pub get
```

Hubungkan aplikasi ke project Firebase milik Anda menggunakan FlutterFire CLI dan konfigurasi platform yang sesuai; `main.dart` menginisialisasi Firebase sebelum menjalankan aplikasi. Aktifkan metode masuk email/password, siapkan Firestore, lalu tinjau dan terapkan `firestore.rules` pada project tersebut. Aturan membatasi akses berdasarkan peran dan status akun; data pohon dapat dibaca publik, sedangkan isi permohonan dibatasi untuk admin. Jangan memasukkan kredensial Admin SDK, password, atau rahasia server ke repositori. Admin pertama perlu disiapkan melalui jalur tepercaya; aplikasi tidak menyediakan pendaftaran publik.

## Menjalankan Aplikasi

Untuk Web menggunakan Chrome:

```bash
flutter run -d chrome
```

Untuk perangkat yang terhubung, lihat ID perangkat lalu jalankan:

```bash
flutter devices
flutter run -d <device-id>
```

Lokasi perangkat memerlukan izin lokasi dan layanan lokasi aktif. Peta memuat ubin OpenStreetMap melalui internet; ketersediaan peta dan fitur perangkat bergantung pada koneksi serta konfigurasi platform.

## Pengujian

Jalankan analisis statis dan pengujian Flutter dengan:

```bash
flutter analyze
flutter test
```

Suite Flutter mencakup pengujian widget dan logika untuk navigasi publik, peta dan filter, statistik, formulir permohonan, dashboard admin, pengelolaan pohon, model data, ekspor, serta penjagaan perubahan formulir. Pengujian aturan Firestore terpisah tersedia di `rules_test/`; paketnya mensyaratkan Node.js 20 atau lebih baru dan Firebase Emulator:

```bash
cd rules_test
npm ci
npm test
```

Perintah-perintah tersebut menjalankan pemeriksaan dan pengujian; dokumentasi ini tidak menyatakan bahwa semuanya telah lulus atau bahwa aplikasi siap produksi.
