import 'package:flutter/material.dart';
import '../widgets/civic_design.dart';
import '../theme/app_theme.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/public/public_visuals.dart';
import '../widgets/public/public_footer.dart';
import '../utils/cirebon_regions.dart';
import '../widgets/public_navbar.dart';

class PublicTentangScreen extends StatelessWidget {
  const PublicTentangScreen({super.key});
  @override
  Widget build(BuildContext context) => PublicScaffold(
    currentPage: PublicPage.tentang,
    body: PublicPageScroll(
      children: [
        PublicContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PublicReveal(milliseconds: 320, child: _hero(context)),
              const SizedBox(height: 48),
              const Text(
                'Ruang hijau yang kita kenali dan rawat',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pemetaan pohon membantu masyarakat mengenali lokasi, jenis, dan kondisi pohon di Kota Cirebon. Data mendukung pengelolaan ruang hijau, perawatan, serta perhatian terhadap pohon yang tercatat rawan tumbang.',
                style: TextStyle(color: PublicUi.muted),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, box) {
                  final cards = [
                    _benefit(
                      Icons.map_outlined,
                      'Kenali sebaran',
                      'Lihat lokasi pohon yang sudah terverifikasi pada peta.',
                    ),
                    _benefit(
                      Icons.health_and_safety_outlined,
                      'Pahami kondisi',
                      'Baca kondisi sehat, sakit, atau rawan tumbang beserta keterangannya.',
                    ),
                    _benefit(
                      Icons.volunteer_activism_outlined,
                      'Ikut merawat',
                      'Ajukan permohonan perapihan dengan data dan foto yang lengkap.',
                    ),
                  ];
                  return box.maxWidth >= 850 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 18.2
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 32),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        )
                      : Column(children: cards);
                },
              ),
              const SizedBox(height: 48),
              PublicReveal(
                child: PublicPanel(
                  color: PublicUi.mint,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bagaimana data sampai ke peta?',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, box) {
                          final steps = [
                            _step(
                              '1',
                              'Pendataan',
                              'Pohon didata oleh petugas lapangan.',
                            ),
                            _step(
                              '2',
                              'Verifikasi',
                              'Data diperiksa sebelum ditampilkan.',
                            ),
                            _step(
                              '3',
                              'Peta publik',
                              'Data terverifikasi ditampilkan pada peta.',
                            ),
                          ];
                          return box.maxWidth >= 800 &&
                                  MediaQuery.textScalerOf(context).scale(14) <=
                                      18.2
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < steps.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 24),
                                      Expanded(child: steps[i]),
                                    ],
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: steps,
                                );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin juga dapat menambahkan data pohon terverifikasi melalui alur administrasi yang tersedia.',
                        style: TextStyle(fontSize: 14, color: PublicUi.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              PublicPanel(
                color: PublicUi.mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Wilayah pemetaan',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lima kecamatan di Kota Cirebon. Jumlah pohon yang tampil mengikuti data terverifikasi yang tersedia.',
                    ),
                    const SizedBox(height: 16),
                    for (final entry in cirebonKecamatanKelurahan.entries)
                      ExpansionTile(
                        title: Text(entry.key),
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: PublicUi.green,
                        ),
                        expansionAnimationStyle: AnimationStyle(
                          duration: PublicUi.duration(context, 180),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(entry.value.join(', ')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Pertanyaan yang sering diajukan',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  _faq(
                    context,
                    'Apakah saya wajib login?',
                    'Tidak. Peta dan statistik dapat dilihat tanpa login. Permohonan perapihan juga dapat diajukan oleh publik tanpa login. Login Petugas dipakai untuk pekerjaan surveyor/admin.',
                  ),
                  _faq(
                    context,
                    'Apa arti warna kondisi pohon?',
                    'Hijau berarti sehat, kuning berarti sakit, dan merah berarti rawan tumbang. Kondisi ini berasal dari catatan data pohon, bukan prediksi otomatis.',
                  ),
                  _faq(
                    context,
                    'Mengapa suatu pohon belum terlihat?',
                    'Data mungkin belum tersedia atau belum terverifikasi. Periksa juga pencarian dan filter peta. Aplikasi tidak dapat memastikan alasan untuk satu pohon tanpa memeriksa datanya.',
                  ),
                  _faq(
                    context,
                    'Apa yang diperlukan untuk permohonan?',
                    'Lengkapi data pemohon, alamat pohon, wilayah, alasan, foto pohon dan foto KTP, serta pernyataan kebenaran data. Simpan nomor yang muncul setelah pengiriman berhasil.',
                  ),
                ],
              ),
            ],
          ),
        ),
        const PublicFooter(currentPage: PublicPage.tentang),
      ],
    ),
  );
  Widget _hero(BuildContext context) => CivicHeading(
    eyebrow: 'TENTANG APLIKASI',
    title: 'Mengenal pohon. Merawat kehidupan kota.',
    description:
        'Informasi pohon yang mudah diakses untuk mendukung kepedulian terhadap ruang hijau Kota Cirebon.',
    action: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
      onPressed: () =>
          navigateToPublicPage(context, PublicPage.peta, PublicPage.tentang),
      icon: const Icon(Icons.map_outlined),
      label: const Text('Jelajahi peta pohon'),
    ),
  );
  Widget _benefit(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PublicIconTile(icon: icon),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: PublicUi.muted)),
      ],
    ),
  );
  Widget _step(String number, String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE1F3E9),
          child: Text(number, style: const TextStyle(color: AppColors.leaf)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _faq(BuildContext context, String question, String answer) =>
      ExpansionTile(
        expansionAnimationStyle: AnimationStyle(
          duration: Duration(
            milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 180,
          ),
        ),
        title: Text(question),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Align(alignment: Alignment.centerLeft, child: Text(answer))],
      );
}