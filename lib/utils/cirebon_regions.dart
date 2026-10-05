// Data resmi Kecamatan → Kelurahan Kota Cirebon, sumber: BPS 2025
// (luas_wilayah_administrasi_kota_cirebon_3.xlsx, diberikan pengguna).
// 5 kecamatan, 22 kelurahan.
const Map<String, List<String>> cirebonKecamatanKelurahan = {
  'Harjamukti': ['Harjamukti', 'Kalijaga', 'Kecapi', 'Larangan', 'Argasunya'],
  'Kesambi': ['Kesambi', 'Drajat', 'Karyamulya', 'Sunyaragi', 'Pekiringan'],
  'Lemahwungkuk': ['Lemahwungkuk', 'Pegambiran', 'Kesepuhan', 'Panjunan'],
  'Kejaksan': ['Kejaksan', 'Kebonbaru', 'Kesenden', 'Sukapura'],
  'Pekalipan': ['Pekalipan', 'Pulasaren', 'Pekalangan', 'Jagasatru'],
};

List<String> get cirebonKecamatanList => cirebonKecamatanKelurahan.keys.toList();

List<String> kelurahanFor(String? kecamatan) {
  if (kecamatan == null) return [];
  return cirebonKecamatanKelurahan[kecamatan] ?? [];
}