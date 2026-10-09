# Pemetaan Pohon Kota Cirebon

Pohon kota yang tersebar di berbagai wilayah sulit dipantau tanpa data lokasi dan kondisi yang mudah diakses. Aplikasi ini menghubungkan pendataan lapangan dengan peta dan statistik publik, sehingga masyarakat dapat mengenali pohon yang sudah terverifikasi dan petugas dapat memperbarui inventaris untuk membantu pengelolaan ruang hijau serta perhatian terhadap pohon yang tercatat rawan tumbang.

## Gambaran Umum

Aplikasi Flutter ini menyediakan halaman publik tanpa perlu masuk, serta area kerja terautentikasi untuk surveyor dan admin. Surveyor mencatat pohon di lapangan; catatan baru berstatus menunggu sampai ditinjau admin. Hanya data berstatus terverifikasi yang ditampilkan pada peta dan statistik publik. Admin juga dapat memasukkan data pohon langsung melalui alur administrasi.

Selain inventaris pohon, masyarakat dapat mengajukan permohonan perapihan tanpa login. Permohonan diterima untuk ditinjau admin, yang dapat memperbarui status dan mengekspor dokumen terkait. Data pohon dan permohonan disimpan melalui Firebase Firestore.

## Fitur Utama

### Publik

- **Beranda dan peta pohon:** menampilkan ringkasan serta pratinjau peta dari pohon terverifikasi. Peta lengkap menyediakan pengelompokan penanda, pencarian, filter kecamatan, kelurahan, jenis, dan kondisi, serta pengurutan terbaru atau terlama. Pohon tanpa koordinat valid tetap dapat dilihat melalui daftar hasil.
- **Detail pohon:** membuka informasi lokasi, jenis, kondisi, keterangan, dan foto yang tersedia. Kategori kondisi mengikuti data yang dicatat petugas; aplikasi tidak memprediksi kondisi secara otomatis.
- **Statistik:** merangkum jumlah pohon terverifikasi menurut kondisi, jenis, dan kecamatan. Pengunjung dapat memilih wilayah serta melihat penyajian grafik atau tabel, untuk membantu memahami sebaran data yang tersedia.
- **Permohonan perapihan:** formulir publik meminta data pemohon dan lokasi pohon, alasan, foto pohon, foto identitas, serta persetujuan kebenaran data. Lokasi GPS dapat digunakan bila tersedia. Setelah berhasil dikirim, aplikasi memberikan nomor permohonan untuk disimpan pemohon.
- **Informasi aplikasi:** menjelaskan alur pendataan, arti kategori kondisi, wilayah cakupan, dan jawaban atas pertanyaan umum.

### Surveyor

- **Ringkasan pekerjaan:** menampilkan jumlah pohon milik surveyor yang masuk ke akun tersebut, jumlah yang dicatat hari ini, dan catatan berstatus rawan tumbang.
- **Input dan pembaruan data:** formulir mencatat lokasi, wilayah, alamat, jenis, kondisi, keterangan, dan foto pohon. Titik dapat dipilih pada peta atau diperoleh melalui lokasi perangkat. Aplikasi memeriksa kemungkinan pohon duplikat di sekitar titik yang dipilih sebelum penyimpanan.
- **Daftar, peta, dan detail:** inventaris dapat dicari dan difilter menurut kondisi, lalu dilihat pada peta atau sebagai daftar. Surveyor dapat membuka, mengedit, dan menghapus catatan miliknya sesuai aturan akses. Perubahan data tidak menetapkan status verifikasi baru.

### Admin

- **Ringkasan dan tinjauan:** memantau antrean pohon yang menunggu verifikasi serta permohonan warga. Admin dapat meninjau informasi sebelum mengambil tindakan.
- **Pengelolaan pohon:** mencari dan memfilter inventaris, menambah atau mengedit data, mengubah status verifikasi, menghapus data, dan mengekspor data ke Excel. Status verifikasi menentukan apakah pohon muncul di peta dan statistik publik.
- **Pengelolaan surveyor:** membuat akun surveyor, memperbarui nama, mengaktifkan atau menonaktifkan akun, menghapus profil, dan mengirim tautan reset kata sandi melalui Firebase.
- **Penanganan permohonan:** meninjau informasi dan foto, memperbarui status permohonan, mencatat alasan penolakan, serta mengekspor dokumen Word.
- **Data contoh:** pada mode debug tersedia tindakan untuk membuat atau menghapus 30 catatan pohon simulasi. Data ini bukan hasil survei; penghapusan dibatasi pada data contoh yang dibuat untuk admin terkait.

## Peran Pengguna

| Peran | Akses dan tanggung jawab |
|---|---|
| Publik | Melihat peta, detail, statistik, dan informasi; mengirim permohonan perapihan tanpa login. |
| Surveyor | Masuk dengan akun aktif, mengelola catatan pohon miliknya, dan melihat ringkasan pendataan. |
| Admin | Mengelola akun surveyor, inventaris dan verifikasi pohon, serta meninjau dan menangani permohonan. |

Aplikasi mengarahkan pengunjung yang belum masuk, akun yang tidak aktif, atau profil yang tidak tersedia ke halaman publik. Pengguna yang diwajibkan mengganti kata sandi diarahkan ke layar penggantian sebelum memasuki area kerja. Akses data juga dibatasi oleh aturan Firestore, bukan hanya navigasi layar.

## Teknologi

Versi paket berikut adalah batas versi yang dideklarasikan di `pubspec.yaml`, bukan jaminan versi yang terpasang pada mesin.

| Teknologi atau paket | Penggunaan |
|---|---|
| Flutter dan Dart `^3.7.2` | Kerangka aplikasi dan bahasa implementasi. |
| `firebase_core ^3.12.1`, `firebase_auth ^5.5.1`, `cloud_firestore ^5.6.2` | Inisialisasi Firebase, autentikasi, dan penyimpanan data Firestore. |
| `flutter_map ^8.3.2`, `flutter_map_marker_cluster ^8.2.2`, `latlong2 0.9.1` | Peta, koordinat, serta pengelompokan penanda. |
| `geolocator ^14.0.2`, `image_picker ^1.2.1` | Lokasi perangkat dan pemilihan atau pengambilan foto. |
| `fl_chart 0.69.2` | Grafik statistik. |
| `excel ^4.0.6`, `archive ^3.6.1`, `web ^1.1.1` | Pembuatan ekspor Excel dan dokumen, termasuk kebutuhan unduhan web. |
| `url_launcher ^6.3.2`, `google_fonts ^6.3.2`, `cupertino_icons ^1.0.8` | Tautan, tipografi, dan ikon pendukung. |
| `flutter_test`, `flutter_lints ^5.0.0` | Pengujian dan aturan lint saat pengembangan. |

## Struktur Proyek

```text
lib/
  models/       Model akun, data pohon, dan permohonan
  screens/      Halaman publik, login, surveyor, dan admin
  services/     Akses autentikasi dan Firestore
  view_models/  Penyaringan dan agregasi data untuk tampilan
  utils/        Ekspor, geolokasi, wilayah, dan utilitas
  widgets/      Komponen antarmuka publik, surveyor, dan admin
  theme/        Tema aplikasi
test/           Pengujian unit dan widget
assets/image/   Aset gambar dan logo yang dideklarasikan aplikasi
android/        Proyek platform Android
ios/            Proyek platform iOS
web/            Berkas platform web
firestore.rules Aturan akses Firestore
pubspec.yaml    Dependensi dan konfigurasi Flutter
```

## Persiapan dan Instalasi

Siapkan Flutter SDK yang mendukung batas Dart pada `pubspec.yaml`, Git, dan proyek Firebase dengan Firebase Authentication serta Cloud Firestore yang dikonfigurasi. Untuk menjalankan versi web, siapkan Google Chrome; untuk perangkat, siapkan toolchain platform terkait dan perangkat atau emulator.

```bash
git clone https://github.com/yesavenue/Pemetaan-Pohon.git
cd Pemetaan-Pohon
flutter pub get
```

Hubungkan aplikasi ke proyek Firebase milik Anda melalui konfigurasi platform FlutterFire yang sesuai sebelum menjalankan aplikasi. Jika konfigurasi belum tersedia, gunakan FlutterFire CLI pada lingkungan pengembangan yang tepercaya untuk memilih proyek dan platform. Jangan menaruh kunci privat, kredensial akun layanan, kata sandi, atau rahasia lain di README maupun repositori. Tinjau dan terapkan `firestore.rules` pada proyek Firebase yang benar, lalu siapkan akun dengan peran yang sesuai melalui proses administrasi proyek Anda.

## Menjalankan Aplikasi

Untuk menjalankan aplikasi web di Chrome:

```bash
flutter run -d chrome
```

Untuk perangkat atau emulator yang terdeteksi Flutter:

```bash
flutter devices
flutter run -d <id-perangkat>
```

Ganti `<id-perangkat>` dengan ID yang ditampilkan oleh `flutter devices`. Proyek menyediakan direktori platform Android dan iOS; ketersediaan menjalankan aplikasi bergantung pada toolchain, perangkat, serta konfigurasi Firebase platform yang telah disiapkan.

## Pengujian

Jalankan analisis statis dan pengujian Flutter dari direktori proyek:

```bash
flutter analyze
flutter test
```

Pengujian yang tersedia mencakup model dan agregasi data pohon, filter peta dan penanda, alur permohonan publik, statistik, navigasi dan tampilan publik, perilaku antarmuka surveyor, pengelolaan admin, transisi peran, serta perlindungan perubahan yang belum disimpan. Perintah di atas menjalankan pemeriksaan; hasilnya perlu ditinjau pada lingkungan masing-masing.
