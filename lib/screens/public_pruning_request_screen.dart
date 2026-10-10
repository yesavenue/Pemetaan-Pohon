import 'dart:convert';

import 'package:flutter/material.dart';
import '../widgets/civic_design.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/tree_pruning_request.dart';
import '../services/pruning_request_service.dart';
import '../theme/app_theme.dart';
import '../utils/cirebon_regions.dart';
import 'public_home_screen.dart';
import '../widgets/public_navbar.dart';
import '../widgets/public/public_ui.dart';
import '../widgets/public/public_visuals.dart';
import '../widgets/public/public_footer.dart';

const _alasanOptions = [
  'Pohon terlalu rimbun',
  'Dahan mengganggu jalan',
  'Dahan mendekati kabel',
  'Pohon terlalu dekat dengan bangunan',
  'Pohon berpotensi membahayakan',
  'Pohon membutuhkan perapihan',
  'Lainnya',
];

class PublicPruningRequestScreen extends StatefulWidget {
  // Optional adapters allow UI regression tests without Firebase or a camera.
  final Future<String> Function(TreePruningRequest)? createRequest;
  final Future<XFile?> Function(ImageSource)? pickImage;
  final WidgetBuilder? homeBuilder;
  final Future<Position> Function()? locate;
  final Future<void> Function(String)? copyNumber;

  const PublicPruningRequestScreen({
    super.key,
    this.createRequest,
    this.pickImage,
    this.homeBuilder,
    this.locate,
    this.copyNumber,
  });

  @override
  State<PublicPruningRequestScreen> createState() =>
      _PublicPruningRequestScreenState();
}

class _PublicPruningRequestScreenState
    extends State<PublicPruningRequestScreen> {
  late final _createRequest =
      widget.createRequest ?? PruningRequestService().createRequest;
  final _picker = ImagePicker();

  final _namaController = TextEditingController();
  final _alamatPemohonController = TextEditingController();
  final _hpController = TextEditingController();
  final _emailController = TextEditingController();
  final _nikController = TextEditingController();
  final _alamatPohonController = TextEditingController();
  final _alasanLainnyaController = TextEditingController();

  String? _selectedKecamatan;
  String? _selectedKelurahan;
  String? _selectedAlasan;

  Position? _position;
  bool _isFetchingLocation = false;
  String? _locationError;

  Uint8List? _fotoPohonBytes;
  String? _fotoPohonBase64;
  Uint8List? _fotoKtpBytes;
  String? _fotoKtpBase64;

  bool _pernyataanBenar = false;
  bool _isSubmitting = false;
  String? _submittedNumber;

  int _step = 0;
  double _stepDirection = 1;
  final _attempted = [false, false, false];
  final _scroll = ScrollController();
  final _stepAnchor = GlobalKey();
  final _fieldKeys = <TextEditingController, GlobalKey>{};
  final _fieldFocus = <TextEditingController, FocusNode>{};
  final _controlKeys = List.generate(5, (_) => GlobalKey());
  final _controlFocus = List.generate(5, (_) => FocusNode());
  bool _isPickingPhoto = false;
  bool _isCopyingNumber = false;
  String? _copyNotice;
  String? _submitError;
  bool get _busy => _isSubmitting || _isFetchingLocation || _isPickingPhoto;
  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  String get _effectiveAlasan => _selectedAlasan == 'Lainnya'
      ? _alasanLainnyaController.text.trim()
      : (_selectedAlasan ?? '');
  String? _required(TextEditingController controller, int max) {
    final value = controller.text.trim();
    if (value.isEmpty) return 'Wajib diisi';
    if (value.length > max) return 'Maksimal $max karakter';
    return null;
  }

  String? get _emailError =>
      _required(_emailController, 320) ??
      (_emailRegex.hasMatch(_emailController.text.trim())
          ? null
          : 'Format email tidak valid');
  String? get _hpError =>
      _required(_hpController, 30) ??
      (RegExp(r'^[0-9]+$').hasMatch(_hpController.text.trim())
          ? null
          : 'Gunakan angka saja');
  String? get _nikError =>
      RegExp(r'^[0-9]{16}$').hasMatch(_nikController.text.trim())
      ? null
      : 'Isi 16 digit sesuai KTP';
  bool get _applicantValid =>
      _required(_namaController, 200) == null &&
      _required(_alamatPemohonController, 2000) == null &&
      _hpError == null &&
      _emailError == null &&
      _nikError == null;
  bool get _locationValid =>
      _required(_alamatPohonController, 2000) == null &&
      cirebonKecamatanList.contains(_selectedKecamatan) &&
      kelurahanFor(_selectedKecamatan).contains(_selectedKelurahan) &&
      _effectiveAlasan.isNotEmpty &&
      _effectiveAlasan.length <= 4000 &&
      (_fotoPohonBase64?.isNotEmpty ?? false) &&
      (_fotoKtpBase64?.isNotEmpty ?? false);
  bool get _canSubmit =>
      _step == 2 &&
      !_busy &&
      _submittedNumber == null &&
      _applicantValid &&
      _locationValid &&
      _pernyataanBenar;
  void _changed() => setState(() {
    _pernyataanBenar = false;
    _submitError = null;
  });
  void _changeStep(int value) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _stepDirection = value >= _step ? 1 : -1;
      _step = value;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _stepAnchor.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final target =
          (_scroll.offset +
                  box.localToGlobal(Offset.zero).dy -
                  PublicUi.headerHeight(context) -
                  MediaQuery.paddingOf(context).top -
                  12)
              .clamp(0.0, _scroll.position.maxScrollExtent)
              .toDouble();
      if (MediaQuery.of(context).disableAnimations) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: PublicUi.duration(context, 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _revealInvalid(GlobalKey key, FocusNode focus) {
    final step = _step;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _step != step) return;
      final target = key.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0,
          duration: Duration(
            milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 200,
          ),
        );
      }
      if (mounted && _step == step) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
            (_scroll.offset - PublicUi.headerHeight(context) - 24).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
        focus.requestFocus();
      }
    });
  }

  void _next() {
    if (_busy || _step >= 2) return;
    setState(() => _attempted[_step] = true);
    if (_step == 0 ? _applicantValid : _locationValid) {
      _changeStep(_step + 1);
      return;
    }
    final errors = _step == 0
        ? <TextEditingController, String?>{
            _namaController: _required(_namaController, 200),
            _alamatPemohonController: _required(_alamatPemohonController, 2000),
            _hpController: _hpError,
            _emailController: _emailError,
            _nikController: _nikError,
          }
        : <TextEditingController, String?>{
            _alamatPohonController: _required(_alamatPohonController, 2000),
          };
    for (final entry in errors.entries) {
      if (entry.value != null) {
        _revealInvalid(_fieldKeys[entry.key]!, _fieldFocus[entry.key]!);
        return;
      }
    }
    int? index;
    if (_selectedKecamatan == null) {
      index = 0;
    } else if (_selectedKelurahan == null) {
      index = 1;
    } else if (_effectiveAlasan.isEmpty) {
      if (_selectedAlasan == 'Lainnya') {
        _revealInvalid(
          _fieldKeys[_alasanLainnyaController]!,
          _fieldFocus[_alasanLainnyaController]!,
        );
        return;
      }
      index = 2;
    } else if (_fotoPohonBase64 == null) {
      index = 3;
    } else if (_fotoKtpBase64 == null) {
      index = 4;
    }
    if (index != null) {
      _revealInvalid(_controlKeys[index], _controlFocus[index]);
    }
  }

  Future<void> _pickPhoto({required bool isKtp}) async {
    if (_busy) return;
    setState(() => _isPickingPhoto = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => Theme(
          data: PublicUi.theme(context),
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Ambil dari Kamera'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || source == null) return;
      final photo =
          await (widget.pickImage?.call(source) ??
              _picker.pickImage(
                source: source,
                imageQuality: 40,
                maxWidth: 900,
              ));
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      final value = base64Encode(bytes);
      if (value.isEmpty || value.length > 350000) {
        _notice('Foto kosong atau terlalu besar. Coba pilih/ambil ulang.');
        return;
      }
      setState(() {
        _pernyataanBenar = false;
        if (isKtp) {
          _fotoKtpBytes = bytes;
          _fotoKtpBase64 = value;
        } else {
          _fotoPohonBytes = bytes;
          _fotoPohonBase64 = value;
        }
      });
    } catch (_) {
      if (mounted) {
        _notice(
          'Foto belum berhasil dipilih. Foto sebelumnya tetap tersedia; coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _fetchLocation() async {
    if (_busy) return;
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
      _position = null;
      _pernyataanBenar = false;
    });
    try {
      final Position position;
      if (widget.locate != null) {
        position = await widget.locate!();
      } else {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw StateError('GPS tidak aktif');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw StateError('Izin ditolak');
        }
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      }
      if (!mounted) return;
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        throw StateError('Koordinat tidak valid');
      }
      setState(() {
        _position = position;
        _pernyataanBenar = false;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError =
              'Lokasi GPS tidak digunakan. Anda tetap dapat mengisi alamat secara manual.',
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final String requestNumber;
    try {
      final request = TreePruningRequest(
        id: '',
        requestNumber: '',
        namaPemohon: _namaController.text.trim(),
        alamatPemohon: _alamatPemohonController.text.trim(),
        nomorHp: _hpController.text.trim(),
        emailPemohon: _emailController.text.trim(),
        nik: _nikController.text.trim(),
        alamatPohon: _alamatPohonController.text.trim(),
        kecamatan: _selectedKecamatan ?? '',
        kelurahan: _selectedKelurahan ?? '',
        alasan: _effectiveAlasan,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        fotoPohonBase64: _fotoPohonBase64!,
        fotoKtpBase64: _fotoKtpBase64!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      requestNumber = await _createRequest(request);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError =
            'Gagal menyimpan data. Isian tetap tersedia. Periksa koneksi lalu coba kembali.';
      });
      return;
    }
    if (!mounted) return;
    // Rendering/navigation after a successful write must not report write failure.
    setState(() {
      _submittedNumber = requestNumber;
      _isSubmitting = false;
    });
  }

  Future<void> _copyNumber() async {
    final number = _submittedNumber;
    if (number == null || _isCopyingNumber) return;
    setState(() {
      _isCopyingNumber = true;
      _copyNotice = null;
    });
    try {
      if (widget.copyNumber != null) {
        await widget.copyNumber!(number);
      } else {
        await Clipboard.setData(ClipboardData(text: number));
      }
      if (mounted) {
        setState(() => _copyNotice = 'Nomor permohonan disalin.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _copyNotice =
              'Nomor belum berhasil disalin. Anda dapat menyeleksi teks nomor untuk menyalinnya.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCopyingNumber = false);
    }
  }

  void _newRequest() {
    if (_busy || _isCopyingNumber) return;
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _submittedNumber = null;
      _copyNotice = null;
      _submitError = null;
      _step = 0;
      _selectedKecamatan = null;
      _selectedKelurahan = null;
      _selectedAlasan = null;
      _position = null;
      _locationError = null;
      _fotoPohonBytes = null;
      _fotoPohonBase64 = null;
      _fotoKtpBytes = null;
      _fotoKtpBase64 = null;
      _pernyataanBenar = false;
      for (var i = 0; i < _attempted.length; i++) {
        _attempted[i] = false;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  List<TextEditingController> get _controllers => [
    _namaController,
    _alamatPemohonController,
    _hpController,
    _emailController,
    _nikController,
    _alamatPohonController,
    _alasanLainnyaController,
  ];
  @override
  void dispose() {
    _scroll.dispose();
    for (final focus in [..._fieldFocus.values, ..._controlFocus]) {
      focus.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _successBody() => PublicPageScroll(
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.leaf,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Permohonan Berhasil Dikirim',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  'Nomor Permohonan: $_submittedNumber',
                  textAlign: TextAlign.center,
                ),
                if (_copyNotice != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_copyNotice!, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Simpan nomor ini. Permohonan akan diperiksa oleh petugas DPRKP Kota Cirebon.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isCopyingNumber ? null : _copyNumber,
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin nomor'),
                    ),
                    FilledButton(
                      onPressed: _isCopyingNumber
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder:
                                    widget.homeBuilder ??
                                    (_) => const PublicHomeScreen(),
                              ),
                            ),
                      child: const Text('Kembali ke Beranda'),
                    ),
                    TextButton(
                      onPressed: _isCopyingNumber ? null : _newRequest,
                      child: const Text('Ajukan lagi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const PublicFooter(currentPage: PublicPage.permohonan),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_busy,
    child: PublicScaffold(
      currentPage: PublicPage.permohonan,
      navigationEnabled: !_busy,
      body: _submittedNumber != null
          ? _successBody()
          : AbsorbPointer(
              absorbing: _busy,
              child: PublicPageScroll(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CivicHeading(
                            eyebrow: 'LAYANAN MASYARAKAT',
                            title: 'Rawat pohon, mulai dari laporanmu.',
                            description:
                                'Ajukan permohonan perapihan tanpa login. Lengkapi data dan foto untuk diajukan kepada DPRKP Kota Cirebon.',
                          ),
                          const SizedBox(height: 24),
                          PublicPanel(
                            color: PublicUi.mint,
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 16,
                              children: [
                                for (final entry in [
                                  (0, 'Data pemohon'),
                                  (1, 'Lokasi & foto'),
                                  (2, 'Tinjau & kirim'),
                                ])
                                  Semantics(
                                    selected: _step == entry.$1,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: _step >= entry.$1
                                              ? PublicUi.green
                                              : Colors.white,
                                          foregroundColor: _step >= entry.$1
                                              ? Colors.white
                                              : PublicUi.muted,
                                          child: _step > entry.$1
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 20,
                                                )
                                              : Text(
                                                  '${entry.$1 + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            entry.$2,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: _step == entry.$1
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            key: _stepAnchor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    'Langkah ${_step + 1} dari 3',
                                    style: const TextStyle(
                                      color: PublicUi.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: (_step + 1) / 3,
                                    end: (_step + 1) / 3,
                                  ),
                                  duration: PublicUi.duration(context, 240),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, value, child) =>
                                      ExcludeSemantics(
                                        child: LinearProgressIndicator(
                                          value: value,
                                          minHeight: 4,
                                          color: PublicUi.green,
                                          backgroundColor: PublicUi.border,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          PublicPanel(
                            padding: EdgeInsets.all(
                              MediaQuery.sizeOf(context).width >= 1100
                                  ? 32
                                  : 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TweenAnimationBuilder<double>(
                                  key: ValueKey('request-step-$_step'),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds:
                                        MediaQuery.of(context).disableAnimations
                                        ? 0
                                        : 180,
                                  ),
                                  builder: (_, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        16 * _stepDirection * (1 - value),
                                        0,
                                      ),
                                      child: child,
                                    ),
                                  ),
                                  child: _step == 0
                                      ? _applicant()
                                      : _step == 1
                                      ? _location()
                                      : _review(),
                                ),
                                const SizedBox(height: 16),
                                if (_submitError != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _submitError!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    if (_step > 0)
                                      OutlinedButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _changeStep(_step - 1),
                                        child: const Text('Kembali'),
                                      ),
                                    if (_step < 2)
                                      FilledButton(
                                        onPressed: _busy ? null : _next,
                                        child: const Text('Lanjut'),
                                      )
                                    else
                                      FilledButton(
                                        onPressed: _canSubmit ? _submit : null,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            'KIRIM PERMOHONAN',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_step == 2 && !_pernyataanBenar)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Centang pernyataan sebelum mengirim.',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PublicFooter(currentPage: PublicPage.permohonan),
                ],
              ),
            ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label,
    int max,
    String? error, {
    int lines = 1,
    TextInputType? keyboard,
    bool digits = false,
    String? helper,
  }) => Padding(
    key: _fieldKeys.putIfAbsent(controller, () => GlobalKey()),
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      scrollPadding: EdgeInsets.only(
        top: PublicUi.headerHeight(context) + 24,
        bottom: 24,
      ),
      focusNode: _fieldFocus.putIfAbsent(controller, () => FocusNode()),
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 4,
        errorText: _attempted[_step] ? error : null,
      ),
      onChanged: (_) => _changed(),
    ),
  );
  Widget _applicant() => _SectionCard(
    title: 'Data Pemohon',
    children: [
      _field(
        _namaController,
        'Nama Lengkap *',
        200,
        _required(_namaController, 200),
      ),
      _field(
        _alamatPemohonController,
        'Alamat Pemohon *',
        2000,
        _required(_alamatPemohonController, 2000),
        lines: 2,
      ),
      _pair(
        _field(
          _hpController,
          'Nomor HP *',
          30,
          _hpError,
          keyboard: TextInputType.phone,
          digits: true,
        ),
        _field(
          _emailController,
          'Email *',
          320,
          _emailError,
          keyboard: TextInputType.emailAddress,
        ),
      ),
      _field(
        _nikController,
        'Nomor KTP/NIK *',
        16,
        _nikError,
        keyboard: TextInputType.number,
        digits: true,
        helper: '16 digit sesuai KTP',
      ),
    ],
  );
  Widget _location() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionCard(
        title: 'Data Pohon',
        children: [
          _field(
            _alamatPohonController,
            'Alamat/Lokasi Pohon *',
            2000,
            _required(_alamatPohonController, 2000),
            lines: 2,
          ),
          _pair(
            DropdownButtonFormField<String>(
              key: _controlKeys[0],
              focusNode: _controlFocus[0],
              value: _selectedKecamatan,
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: 'Kecamatan *',
                errorText: _attempted[1] && _selectedKecamatan == null
                    ? 'Pilih kecamatan'
                    : null,
              ),
              items: [
                for (final k in cirebonKecamatanList)
                  DropdownMenuItem(
                    value: k,
                    child: Text(
                      k,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _selectedKecamatan = value;
                _selectedKelurahan = null;
                _pernyataanBenar = false;
              }),
            ),
            DropdownButtonFormField<String>(
              key: _controlKeys[1],
              focusNode: _controlFocus[1],
              value: _selectedKelurahan,
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: 'Kelurahan *',
                errorText: _attempted[1] && _selectedKelurahan == null
                    ? 'Pilih kelurahan'
                    : null,
              ),
              items: [
                for (final k in kelurahanFor(_selectedKecamatan))
                  DropdownMenuItem(
                    value: k,
                    child: Text(
                      k,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _selectedKecamatan == null
                  ? null
                  : (value) => setState(() {
                      _selectedKelurahan = value;
                      _pernyataanBenar = false;
                    }),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lokasi GPS (opsional). Gunakan jika sedang berada di lokasi pohon; alamat manual tetap dapat digunakan.',
          ),
          if (_position != null)
            Text(
              'Lokasi berhasil diperoleh: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
            ),
          if (_locationError != null)
            Semantics(liveRegion: true, child: Text(_locationError!)),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _fetchLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _position == null ? 'Gunakan Lokasi Saya' : 'Perbarui Lokasi',
                ),
              ),
              if (_position != null)
                TextButton(
                  onPressed: () => setState(() {
                    _position = null;
                    _pernyataanBenar = false;
                  }),
                  child: const Text('Hapus lokasi GPS'),
                ),
            ],
          ),
        ],
      ),
      _SectionCard(
        title: 'Alasan Permohonan',
        children: [
          DropdownButtonFormField<String>(
            key: _controlKeys[2],
            focusNode: _controlFocus[2],
            value: _selectedAlasan,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: 'Alasan *',
              errorText: _attempted[1] && _effectiveAlasan.isEmpty
                  ? 'Lengkapi alasan'
                  : null,
            ),
            items: [
              for (final reason in _alasanOptions)
                DropdownMenuItem(
                  value: reason,
                  child: Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _selectedAlasan = value;
              _pernyataanBenar = false;
            }),
          ),
          if (_selectedAlasan == 'Lainnya')
            _field(
              _alasanLainnyaController,
              'Jelaskan alasan Anda',
              4000,
              _required(_alasanLainnyaController, 4000),
              lines: 3,
            ),
        ],
      ),
      _pair(
        _SectionCard(
          title: 'Foto Pohon *',
          children: [
            const Text(
              'Pastikan kondisi pohon terlihat jelas. Foto diperkecil saat dipilih oleh aplikasi.',
            ),
            _photo(_fotoPohonBytes),
            OutlinedButton.icon(
              key: _controlKeys[3],
              focusNode: _controlFocus[3],
              onPressed: _busy ? null : () => _pickPhoto(isKtp: false),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _fotoPohonBytes == null
                    ? 'Tambahkan Foto Pohon'
                    : 'Ganti Foto Pohon',
              ),
            ),
            if (_attempted[1] && _fotoPohonBase64 == null)
              const Text('Foto pohon wajib diisi.'),
          ],
        ),
        _SectionCard(
          title: 'Foto KTP *',
          children: [
            const Text(
              'Untuk verifikasi pemohon oleh admin berwenang; tidak ditampilkan dalam daftar publik.',
            ),
            _photo(_fotoKtpBytes),
            OutlinedButton.icon(
              key: _controlKeys[4],
              focusNode: _controlFocus[4],
              onPressed: _busy ? null : () => _pickPhoto(isKtp: true),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _fotoKtpBytes == null ? 'Tambahkan Foto KTP' : 'Ganti Foto KTP',
              ),
            ),
            if (_attempted[1] && _fotoKtpBase64 == null)
              const Text('Foto KTP wajib diisi.'),
          ],
        ),
      ),
    ],
  );
  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, box) {
      return box.maxWidth >= 680 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18.2
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 24),
                Expanded(child: second),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 16), second],
            );
    },
  );
  Widget _photo(Uint8List? bytes) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: bytes == null
          ? const ColoredBox(
              color: PublicUi.mint,
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Icon(Icons.photo_outlined, size: 40),
              ),
            )
          : PublicPhotoFrame(
              image: MemoryImage(bytes),
              title: identical(bytes, _fotoKtpBytes)
                  ? 'Foto KTP'
                  : 'Foto pohon',
              height: 160,
            ),
    ),
  );
  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionCard(
        title: 'Periksa data pemohon',
        children: [
          _row('Nama', _namaController.text.trim()),
          _row('Alamat pemohon', _alamatPemohonController.text.trim()),
          _row('Nomor HP', _hpController.text.trim()),
          _row('Email', _emailController.text.trim()),
          _row('NIK', _nikController.text.trim()),
          TextButton(
            onPressed: () => _changeStep(0),
            child: const Text('Edit data pemohon'),
          ),
        ],
      ),
      _SectionCard(
        title: 'Periksa lokasi dan foto',
        children: [
          _row('Alamat pohon', _alamatPohonController.text.trim()),
          _row('Kecamatan', _selectedKecamatan ?? ''),
          _row('Kelurahan', _selectedKelurahan ?? ''),
          _row('Alasan', _effectiveAlasan),
          _row(
            'GPS',
            _position == null
                ? 'Tidak digunakan (alamat manual)'
                : '${_position!.latitude}, ${_position!.longitude}',
          ),
          const Text('Foto pohon'),
          _photo(_fotoPohonBytes),
          const Text('Foto KTP'),
          _photo(_fotoKtpBytes),
          TextButton(
            onPressed: () => _changeStep(1),
            child: const Text('Edit lokasi & foto'),
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _pernyataanBenar,
        onChanged: (value) => setState(() => _pernyataanBenar = value ?? false),
        title: const Text(
          'Saya menyatakan bahwa data yang saya masukkan adalah benar.',
        ),
      ),
    ],
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(value),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}