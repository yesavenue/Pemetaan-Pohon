import 'package:flutter/material.dart';
import '../widgets/public_navbar.dart';

import '../theme/app_theme.dart';
import '../utils/branding.dart';
import '../utils/cirebon_regions.dart';

class PublicTentangScreen extends StatelessWidget {
  const PublicTentangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      currentPage: PublicPage.tentang,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            color: AppColors.navy,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    appLogoAsset,
                    width: 64,
                    height: 64,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.location_city,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  appSystemName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  appInstansiUnit,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(
                  title: 'Deskripsi Sistem',
                  child: const Text(
                    'Sistem ini digunakan untuk mendata, memetakan, dan memantau kondisi '
                    'pohon di wilayah Kota Cirebon secara digital. Petugas survei mencatat '
                    'lokasi, jenis, dan kondisi kesehatan tiap pohon menggunakan GPS dan '
                    'kamera dari lapangan, yang kemudian diverifikasi oleh admin sebelum '
                    'ditampilkan kepada masyarakat.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Tujuan Pemetaan',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _BulletPoint(
                        'Menyediakan data sebaran pohon yang akurat dan mutakhir.',
                      ),
                      _BulletPoint(
                        'Memantau kondisi kesehatan pohon secara berkala.',
                      ),
                      _BulletPoint(
                        'Mendukung mitigasi risiko pohon rawan tumbang bagi keselamatan warga.',
                      ),
                      _BulletPoint(
                        'Menjadi dasar perencanaan perawatan dan penanaman pohon kota.',
                      ),
                      _BulletPoint(
                        'Memberikan akses informasi terbuka kepada masyarakat.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Wilayah Pemetaan',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cakupan saat ini meliputi 5 kecamatan di Kota Cirebon:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ...cirebonKecamatanKelurahan.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kec. ${entry.key}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.value.join(', '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Kontak',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ContactRow(
                        icon: Icons.email_outlined,
                        text: appContactEmail,
                      ),
                      SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        text: appContactPhone,
                      ),
                      SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.location_on_outlined,
                        text: appContactAddress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.navy),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}