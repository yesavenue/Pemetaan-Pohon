# Pemetaan Pohon Kota Cirebon

Pemetaan Pohon Kota Cirebon membantu mengatasi sulitnya menemukan dan memahami sebaran serta kondisi pohon kota melalui pencatatan terpusat yang ditampilkan pada peta. Warga dapat melihat data pohon yang telah diverifikasi dan mengajukan permohonan pemangkasan, sementara petugas dan admin mengelola pendataan serta peninjauannya.

## Gambaran Umum

Aplikasi menyediakan layanan publik tanpa perlu masuk akun dan area kerja petugas yang memerlukan autentikasi. Data pohon dicatat oleh surveyor, lalu ditinjau admin sebelum muncul pada peta dan statistik publik. Alur ini memisahkan data yang masih menunggu pemeriksaan dari informasi yang dapat dilihat masyarakat.

Aplikasi dapat dijalankan sebagai situs publik di Flutter Web. Build non-Web diarahkan ke aplikasi surveyor; admin menggunakan area admin melalui website. Layanan publik mencakup beranda, peta, statistik, formulir permohonan pemangkasan, dan informasi tentang pemetaan.

## Fitur Utama

### Publik

- **Beranda dan peta pohon:** beranda menampilkan ringkasan serta pratinjau peta. Peta lengkap menyajikan pohon terverifikasi sebagai penanda yang dapat dikelompokkan, dengan tampilan daftar untuk menjelajahi hasil.
- **Pencarian, filter, dan detail:** warga dapat mencari serta menyaring data berdasarkan informasi wilayah dan kondisi, lalu melihat detail pohon seperti jenis, kondisi, lokasi, dan keterangan yang tersedia. Peta menyediakan kontrol tampilan dan opsi untuk menampilkan lokasi perangkat.
- **Statistik:** ringkasan dan grafik menghitung pohon terverifikasi menurut kondisi, jenis, dan kecamatan. Statistik dapat difilter per kecamatan dan ditampilkan sebagai grafik atau tabel; catatan kondisi rawan tumbang bukan prediksi risiko otomatis.
- **Permohonan pemangkasan:** formulir bertahap menerima informasi pemohon dan lokasi pohon, foto pendukung, serta lokasi GPS opsional. Alamat tetap dapat diisi manual. Setelah pengajuan berhasil, aplikasi menampilkan nomor permohonan. Data permohonan hanya dapat dibaca dan ditinjau admin sesuai aturan Firestore.

### Surveyor

- **Pendataan pohon:** surveyor mengisi jenis, lokasi administratif, alamat jalan, ranah kewenangan, kondisi, keterangan, koordinat, dan foto. Lokasi dapat dipilih pada peta atau menggunakan lokasi perangkat. Data baru dikirim dengan status menunggu verifikasi.
- **Daftar, detail, dan tindak lanjut:** dashboard menampilkan data milik surveyor, dengan pencarian, filter, dan tampilan peta/daftar. Surveyor dapat membuka detail, mengubah atau menghapus data sesuai aturan akses, serta memperbaiki dan mengirim ulang data yang ditolak. Pesan peninjauan membantu surveyor membaca alasan perbaikan.
- **Akun:** profil menyediakan pengelolaan nama, email, dan kata sandi serta opsi keluar. Akun yang diwajibkan mengganti kata sandi diarahkan ke layar perubahan kata sandi.

### Admin

- **Ringkasan dan pengelolaan surveyor:** admin dapat membuat akun surveyor serta mengelola profil dan status aktifnya.
- **Peninjauan data pohon:** admin memeriksa data, menyetujui atau meminta perbaikan dengan alasan, mengelola data pohon, dan menyinkronkan data terverifikasi ke koleksi publik.
- **Pengelolaan permohonan:** admin meninjau permohonan pemangkasan, memperbarui status dan alasan penolakan, melihat atau mengunduh foto pendukung, serta mengekspor dokumen Word.
- **Ekspor data pohon:** admin dapat memilih data untuk dibuat menjadi laporan Excel. Tersedia pula alat untuk mengisi atau menghapus data contoh; alat tersebut merupakan utilitas demo, bukan data hasil survei sebenarnya.

## Peran Pengguna

| Peran | Akses dan tanggung jawab |
| --- | --- |
| Pengunjung publik | Tanpa login; melihat pohon terverifikasi, peta, statistik, informasi aplikasi, dan mengirim permohonan pemangkasan. |
| Surveyor | Login dengan akun aktif; mencatat serta mengelola data pohon miliknya dan menindaklanjuti hasil pemeriksaan. |
| Admin | Login melalui website; mengelola surveyor, meninjau data pohon dan permohonan, serta mengekspor laporan. |

Akun surveyor dibuat oleh admin. Aplikasi membedakan akses berdasarkan peran dan status akun; aturan Firestore juga membatasi operasi data sesuai peran. Permohonan tidak dapat dibaca surveyor.

## Teknologi

Versi di bawah adalah batasan yang tercantum di `pubspec.yaml`; tanda `^` menunjukkan batasan versi, bukan klaim versi terpasang.

| Teknologi atau paket | Batasan versi | Penggunaan |
| --- | --- | --- |
| Flutter dan Dart | Dart SDK `^3.7.2`; versi Flutter tidak ditetapkan di berkas | Aplikasi lintas platform |
| `firebase_core` | `^3.12.1` | Inisialisasi Firebase |
| `firebase_auth` | `^5.5.1` | Autentikasi pengguna |
| `cloud_firestore` | `^5.6.2` | Penyimpanan dan aliran data Firestore |
| `flutter_map`, `latlong2`, `flutter_map_marker_cluster` | `^8.3.2`, `0.9.1`, `^8.2.2` | Peta, koordinat, dan pengelompokan penanda |
| `geolocator` | `^14.0.2` | Lokasi perangkat |
| `fl_chart` | `0.69.2` | Grafik statistik |
| `image_picker`, `image` | `^1.2.1`, `4.2.0` | Pemilihan dan pengolahan foto |
| `excel` | `^4.0.6` | Pembuatan laporan Excel |
| `archive`, `xml` | `^3.6.1`, `^6.5.0` | Penyusunan dokumen Word |
| `web`, `url_launcher`, `google_fonts` | `^1.1.1`, `^6.3.2`, `^6.3.2` | Unduhan web, tautan, dan tipografi |
| `crypto` | `^3.0.6` | Utilitas kriptografi |

## Struktur Proyek

```text
.
├── assets/image/       # Logo dan gambar aplikasi
├── lib/
│   ├── models/         # Model pengguna, pohon, dan permohonan
│   ├── screens/        # Layar publik, admin, dan surveyor
│   ├── services/       # Autentikasi dan operasi data Firebase
│   ├── view_models/    # Pengolahan data tampilan dan statistik
│   ├── widgets/        # Komponen UI bersama per area
│   ├── utils/          # Peta, lokasi, ekspor, dan utilitas
│   └── theme/          # Tema aplikasi
├── test/               # Pengujian unit dan widget Flutter
├── web/                # Berkas aplikasi web
├── android/, ios/      # Berkas target perangkat
├── linux/, macos/, windows/ # Berkas target desktop
├── firestore.rules     # Aturan akses Cloud Firestore
└── pubspec.yaml        # Konfigurasi dan dependensi Flutter
```

## Persiapan dan Instalasi

Prasyarat: Flutter SDK yang menyertakan Dart sesuai batasan proyek, Git, serta Chrome untuk menjalankan versi web. Untuk fitur berbasis Firebase, siapkan proyek Firebase sendiri dengan Firebase Authentication dan Cloud Firestore. Siapkan juga FlutterFire CLI untuk menghubungkan konfigurasi aplikasi dengan proyek tersebut.

```bash
git clone https://github.com/yesavenue/Pemetaan-Pohon.git
cd Pemetaan-Pohon
flutter pub get
```

Jalankan `flutterfire configure` untuk menghubungkan proyek dengan konfigurasi Firebase milik Anda. Terapkan dan tinjau `firestore.rules` pada proyek Firebase yang digunakan; akses fitur bergantung pada konfigurasi layanan dan aturan tersebut. Jangan menyalin atau membagikan kredensial pribadi, kunci server, token, atau konfigurasi rahasia ke repositori maupun kanal publik. Proyek tidak menggunakan konfigurasi `.env` sebagai langkah setup.

## Menjalankan Aplikasi

Jalankan versi publik di Chrome:

```bash
flutter run -d chrome
```

Pratinjau aplikasi surveyor di Chrome:

```bash
flutter run -d chrome --dart-define=SURVEYOR_APP=true
```

Untuk perangkat yang terdeteksi Flutter, lihat ID perangkat lalu jalankan:

```bash
flutter devices
flutter run -d <device-id>
```

Pada build non-Web, aplikasi diarahkan ke alur surveyor. Fitur lokasi memerlukan izin lokasi pada perangkat.

## Pengujian

Jalankan analisis statis dan seluruh pengujian Flutter dengan:

```bash
flutter analyze
flutter test
```

Folder `test/` mencakup pengujian model dan logika data, peta serta pencarian/filter, statistik, formulir permohonan, alur navigasi dan peran, pengelolaan admin, ekspor, serta perilaku antarmuka surveyor. Perintah di atas menjalankan pemeriksaan; hasilnya bergantung pada kondisi lingkungan dan konfigurasi Firebase yang digunakan.
