import 'package:flutter/material.dart';
import 'public_ui.dart';

/// Shared by the navbar, hero content and dark overlay.
double publicHeroProgress(double offset) =>
    ((offset - 24) / 160).clamp(0.0, 1.0).toDouble();

/// Photo movement follows the page; no timer, autoplay or extra network asset.
class PublicHeroBackdrop extends StatelessWidget {
  final ScrollController controller;
  const PublicHeroBackdrop({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final photo = Image.asset('assets/image/hero_cirebon.png',
      key: const ValueKey('public-hero-background'),
      fit: BoxFit.cover, filterQuality: FilterQuality.high, alignment: const Alignment(.25, 0),
      excludeFromSemantics: true,
      errorBuilder: (_, error, stack) => const ColoredBox(color: PublicUi.ink));
    return ClipRect(child: AnimatedBuilder(animation: controller, child: photo,
      builder: (context, child) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final shift = reduced ? 0.0 : (offset * .07).clamp(0.0, 26.0).toDouble();
        return Transform.translate(key: const ValueKey('hero-parallax'), offset: Offset(0, shift),
          child: Transform.scale(scale: reduced ? 1 : 1.10, child: child));
      }));
  }
}

/// One brief sliced-text entrance; the readable title stays underneath.
class PublicGlitchTitle extends StatefulWidget {
  final double fontSize;
  final double exitProgress;
  const PublicGlitchTitle({super.key, required this.fontSize, this.exitProgress = 0});
  @override
  State<PublicGlitchTitle> createState() => _PublicGlitchTitleState();
}
class _PublicGlitchTitleState extends State<PublicGlitchTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _started = false;
  bool _exitPlayed = false;
  @override
  void didUpdateWidget(covariant PublicGlitchTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_exitPlayed && widget.exitProgress > 0) {
      _exitPlayed = true;
      if (!MediaQuery.of(context).disableAnimations) _animation.forward(from: 0);
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _animation.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _animation.forward();
    }
  }
  @override
  void dispose() { _animation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    Widget title(Color color) => Text('Kenali pohonnya.\nJaga kotanya.', textAlign: TextAlign.center,
      style: TextStyle(fontSize: widget.fontSize, color: color, height: 1.18,
        letterSpacing: -.8, fontWeight: FontWeight.w800));
    return Semantics(label: 'Kenali pohonnya. Jaga kotanya.', header: true,
      child: ExcludeSemantics(child: AnimatedBuilder(animation: _animation,
        builder: (context, _) {
          final t = _animation.value;
          final shift = t < .35 ? 3 * (1 - t / .35) : -2 * (1 - t) / .65;
          return Stack(alignment: Alignment.center, children: [
            title(Colors.white),
            if (t < 1) Positioned.fill(child: IgnorePointer(child: Opacity(opacity: .65 * (1 - t),
              child: ClipRect(clipper: const _TitleSlice(), child: Transform.translate(offset: Offset(shift, 0),
                child: title(const Color(0xFFBFE2CE))))))),
          ]);
        })));
  }
}
class _TitleSlice extends CustomClipper<Rect> {
  const _TitleSlice();
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, size.height * .3, size.width, size.height * .13);
  @override
  bool shouldReclip(_TitleSlice oldClipper) => false;
}

class PublicQuickActions extends StatelessWidget {
  final VoidCallback onMap;
  final VoidCallback onGuide;
  final VoidCallback onStatistics;
  const PublicQuickActions({super.key, required this.onMap, required this.onGuide, required this.onStatistics});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final columns = box.maxWidth >= 900 && MediaQuery.textScalerOf(context).scale(14) <= 18.2 ? 3 : 1;
    final width = (box.maxWidth - 16 * (columns - 1)) / columns;
    final items = [
      (Icons.park_outlined, 'Lihat kondisi pohon', 'Jelajahi data pohon terverifikasi.', onMap),
      (Icons.fact_check_outlined, 'Persiapan permohonan', 'Ketahui data dan foto yang diperlukan.', onGuide),
      (Icons.bar_chart_rounded, 'Statistik kota', 'Lihat ringkasan kondisi dan sebaran pohon.', onStatistics),
    ];
    return Wrap(spacing: 16, runSpacing: 12, children: [
      for (final item in items) SizedBox(width: width, child: _ActionCard(
        icon: item.$1, title: item.$2, description: item.$3, onTap: item.$4)),
    ]);
  });
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.description, required this.onTap});
  @override
  State<_ActionCard> createState() => _ActionCardState();
}
class _ActionCardState extends State<_ActionCard> {
  bool _hover = false;
  bool _focus = false;
  @override
  Widget build(BuildContext context) {
    final active = _hover || _focus;
    return AnimatedContainer(duration: PublicUi.duration(context, 180),
      transform: Matrix4.translationValues(0, active && !MediaQuery.of(context).disableAnimations ? -4 : 0, 0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: PublicUi.ink.withValues(alpha: active ? .10 : .035), blurRadius: active ? 20 : 8, offset: const Offset(0, 4))]),
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(20),
        child: InkWell(onTap: widget.onTap,
          onHover: (value) => setState(() => _hover = value),
          onFocusChange: (value) => setState(() => _focus = value),
          borderRadius: BorderRadius.circular(20),
          child: Container(padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? PublicUi.green : PublicUi.border)),
            child: Row(children: [
              Icon(widget.icon, size: 28, color: PublicUi.green), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, color: PublicUi.ink)),
                const SizedBox(height: 6), Text(widget.description, style: const TextStyle(color: PublicUi.muted, fontSize: 13)),
              ])),
              const SizedBox(width: 8), const Icon(Icons.arrow_forward, size: 18, color: PublicUi.green),
            ])))));
  }
}

class PublicApplicationGuide extends StatefulWidget {
  final VoidCallback onApply;
  final VoidCallback onTrack;
  const PublicApplicationGuide({super.key, required this.onApply, required this.onTrack});
  @override
  State<PublicApplicationGuide> createState() => _PublicApplicationGuideState();
}
class _PublicApplicationGuideState extends State<PublicApplicationGuide> {
  int _step = 0;
  static const _steps = [
    ('Siapkan data', 'Data pemohon yang dapat dihubungi',
      'Siapkan nama, alamat pemohon, nomor HP, email, dan NIK. Data ini diperlukan untuk verifikasi permohonan.'),
    ('Tentukan pohon', 'Pastikan lokasi pohon sesuai',
      'Isi alamat pohon, kecamatan, dan kelurahan. Gunakan GPS saat berada di dekat pohon atau tentukan titik melalui peta. Sertakan foto pohon, foto KTP, dan alasan permohonan.'),
    ('Kirim & pantau', 'Simpan bukti dan kode akses',
      'Periksa kembali isian sebelum mengirim. Simpan kode akses 16 karakter untuk memantau status. Kode lama tetap berlaku. Pengajuan belum berarti perapihan telah disetujui.'),
  ];
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Bagaimana mengajukan permohonan?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Pilih langkah untuk melihat persiapannya.', style: TextStyle(color: PublicUi.muted)),
    const SizedBox(height: 20),
    Wrap(spacing: 10, runSpacing: 10, children: [
      for (var i = 0; i < _steps.length; i++) ChoiceChip(
        key: ValueKey('guide-step-$i'), selected: i == _step,
        label: Text('${i + 1}. ${_steps[i].$1}'), onSelected: (_) => setState(() => _step = i)),
    ]),
    const SizedBox(height: 16),
    AnimatedSize(duration: PublicUi.duration(context, 220), alignment: Alignment.topLeft,
      child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: PublicUi.mint, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(liveRegion: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_steps[_step].$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: PublicUi.ink)),
            const SizedBox(height: 12), Text(_steps[_step].$3, style: const TextStyle(height: 1.6, color: PublicUi.ink)),
          ])),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (_step < 2) FilledButton.icon(onPressed: () => setState(() => _step++),
              icon: const Icon(Icons.arrow_forward), label: const Text('Langkah berikutnya'))
            else FilledButton.icon(onPressed: widget.onApply, icon: const Icon(Icons.edit_note), label: const Text('Mulai permohonan')),
            if (_step == 2) OutlinedButton.icon(onPressed: widget.onTrack,
              icon: const Icon(Icons.manage_search), label: const Text('Sudah mengajukan? Lacak')),
          ]),
        ]))),
  ]);
}
