import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import '../theme/app_theme.dart';
import '../utils/cirebon_boundary.dart';
import '../utils/geo_utils.dart';
import '../utils/device_location.dart';
import '../utils/tree_condition_style.dart';
import '../widgets/tree_authority_field.dart';
import '../widgets/civic_design.dart';
import '../utils/tree_options.dart';
import '../widgets/surveyor/unsaved_changes_guard.dart';
import 'surveyor/tree_location_picker_screen.dart';

class TreeInputScreen extends StatefulWidget {
  final AppUser surveyorUser;
  final TreeData? initialTree;

  const TreeInputScreen({
    super.key,
    required this.surveyorUser,
    this.initialTree,
  });

  @override
  State<TreeInputScreen> createState() => _TreeInputScreenState();
}

class _TreeInputScreenState extends State<TreeInputScreen> {
  final _treeService = TreeService();
  final _authorityController = TextEditingController();
  String? _authority;
  String get _effectiveAuthority => _authority == 'Lainnya'
      ? _authorityController.text.trim()
      : (_authority ?? '');
  final _customSpeciesController = TextEditingController();
  final _kecamatanCustomController = TextEditingController();
  final _kelurahanController = TextEditingController();
  final _namaJalanController = TextEditingController();
  final _keteranganKondisiController = TextEditingController();
  final _locationFormKey = GlobalKey<FormState>();
  final _treeFormKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _exitGuardKey = GlobalKey<UnsavedChangesGuardState>();
  late List<Object?> _initialDraft;

  List<TextEditingController> get _draftControllers => [
    _authorityController,
    _customSpeciesController,
    _kecamatanCustomController,
    _kelurahanController,
    _namaJalanController,
    _keteranganKondisiController,
  ];

  List<Object?> _draftSnapshot() => [
    _authority,
    _selectedSpecies,
    _selectedKecamatan,
    ..._draftControllers.map((controller) => controller.text),
    _condition,
    _position?.latitude,
    _position?.longitude,
    _photoBase64,
  ];

  bool get _hasChanges => !listEquals(_initialDraft, _draftSnapshot());

  void _draftTextChanged() {
    if (mounted) setState(() {});
  }

  StreamSubscription<List<TreeData>>? _editSubscription;
  TreeData? _latestEditTree;
  bool _editLoaded = false;
  bool _editReadFailed = false;
  int _step = 0;
  String? _selectedSpecies;
  String? _selectedKecamatan;
  TreeCondition _condition = TreeCondition.sehat;
  Uint8List? _photoBytes;
  String? _photoBase64;
  LatLng? _position;
  bool _isFetchingLocation = false;
  bool _isPickingPhoto = false;
  bool _isSaving = false;
  String? _locationError;

  bool get _busy => _isSaving || _isPickingPhoto || _isFetchingLocation;
  String get _effectiveSpecies => _selectedSpecies == 'Lainnya'
      ? _customSpeciesController.text.trim()
      : (_selectedSpecies ?? '');
  String get _effectiveKecamatan => _selectedKecamatan == 'Lainnya'
      ? _kecamatanCustomController.text.trim()
      : (_selectedKecamatan ?? '');
  bool get _isLocationValid =>
      _position != null &&
      isInsideCirebon(_position!.latitude, _position!.longitude);
  bool get _requiresKeterangan =>
      _condition == TreeCondition.sakit ||
      _condition == TreeCondition.rawanTumbang;
  bool get _isEditing => widget.initialTree != null;
  bool get _ownsEdit =>
      !_isEditing ||
      (widget.initialTree!.surveyorId == widget.surveyorUser.uid &&
          FirebaseAuth.instance.currentUser?.uid == widget.surveyorUser.uid &&
          widget.surveyorUser.isActive);

  String? get _editProblem {
    if (!_isEditing) {
      return null;
    }
    if (!_ownsEdit) {
      return 'Akun ini tidak dapat mengubah pohon tersebut.';
    }
    if (_editReadFailed) {
      return 'Data terbaru gagal dimuat. Kembali ke detail dan buka Edit lagi.';
    }
    if (!_editLoaded) {
      return 'Memeriksa data pohon terbaru...';
    }
    if (_latestEditTree == null) {
      return 'Pohon ini sudah tidak tersedia.';
    }
    if (!mapEquals(widget.initialTree!.toMap(), _latestEditTree!.toMap())) {
      return 'Data berubah saat formulir terbuka. Kembali ke detail dan buka Edit lagi sebelum menyimpan.';
    }
    return null;
  }

  bool get _canSubmit =>
      !_busy &&
      _editProblem == null &&
      _isLocationValid &&
      _effectiveSpecies.isNotEmpty &&
      (_authority != 'Lainnya' ||
          (_effectiveAuthority.isNotEmpty &&
              _effectiveAuthority.length <= 120)) &&
      _effectiveKecamatan.isNotEmpty &&
      _namaJalanController.text.trim().isNotEmpty &&
      _photoBase64 != null &&
      (!_requiresKeterangan ||
          _keteranganKondisiController.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    final tree = widget.initialTree;
    if (tree == null) {
      _initialDraft = _draftSnapshot();
      for (final controller in _draftControllers) {
        controller.addListener(_draftTextChanged);
      }
      return;
    }
    _selectedSpecies = speciesOptions.contains(tree.species)
        ? tree.species
        : 'Lainnya';
    _customSpeciesController.text = tree.species;
    _selectedKecamatan = kecamatanOptions.contains(tree.kecamatan)
        ? tree.kecamatan
        : 'Lainnya';
    _kecamatanCustomController.text = tree.kecamatan;
    _kelurahanController.text = tree.kelurahan;
    _namaJalanController.text = tree.namaJalan;
    _keteranganKondisiController.text = tree.keteranganKondisi;
    _condition = tree.condition;
    _authority = tree.ranahKewenangan.isEmpty
        ? null
        : treeAuthorityOptions.contains(tree.ranahKewenangan)
        ? tree.ranahKewenangan
        : 'Lainnya';
    _authorityController.text = tree.ranahKewenangan;
    _position = LatLng(tree.latitude, tree.longitude);
    if (tree.photoBase64.isNotEmpty) {
      try {
        _photoBytes = base64Decode(tree.photoBase64);
        _photoBase64 = tree.photoBase64;
      } on FormatException {
        _photoBytes = null;
        _photoBase64 = null;
      }
    }
    _initialDraft = _draftSnapshot();
    for (final controller in _draftControllers) {
      controller.addListener(_draftTextChanged);
    }
    _editSubscription = _treeService.streamTrees().listen(
      (trees) {
        if (!mounted) {
          return;
        }
        setState(() {
          _latestEditTree = trees
              .where((item) => item.id == tree.id)
              .firstOrNull;
          _editLoaded = true;
          _editReadFailed = false;
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _editReadFailed = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _editSubscription?.cancel();
    for (final controller in _draftControllers) {
      controller.removeListener(_draftTextChanged);
    }
    _authorityController.dispose();
    _customSpeciesController.dispose();
    _kecamatanCustomController.dispose();
    _kelurahanController.dispose();
    _namaJalanController.dispose();
    _keteranganKondisiController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takePhoto() async {
    if (_busy) {
      return;
    }
    setState(() => _isPickingPhoto = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 40,
        maxWidth: 900,
      );
      if (photo == null) {
        return;
      }
      final bytes = await photo.readAsBytes();
      final encoded = base64Encode(bytes);
      if (!mounted) {
        return;
      }
      if (bytes.isEmpty || encoded.length > 700000) {
        _message('Foto kosong atau terlalu besar. Coba ambil ulang.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoBase64 = encoded;
      });
    } catch (_) {
      _message(
        'Kamera tidak dapat dibuka. Periksa izin kamera lalu coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _fetchLocation() async {
    if (_busy) {
      return;
    }
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });
    try {
      final position = await readDeviceLocation();
      if (!mounted) {
        return;
      }
      setState(() => _position = position);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _locationError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickLocation() async {
    final selected = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => TreeLocationPickerScreen(initialLocation: _position),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _position = selected;
      _locationError = null;
    });
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      final validForm = _locationFormKey.currentState?.validate() ?? false;
      if (!_isLocationValid) {
        _message('Tentukan lokasi pohon di dalam wilayah Kota Cirebon.');
      }
      if (!validForm || !_isLocationValid) {
        return;
      }
    } else if (!(_treeFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    unawaited(_exitGuardKey.currentState?.requestBack());
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final nearby = await _treeService.findNearbyTrees(
        _position!.latitude,
        _position!.longitude,
      );
      if (!mounted) {
        return;
      }
      final nearbyTrees = nearby
          .where((tree) => tree.id != widget.initialTree?.id)
          .toList();
      if (nearbyTrees.isNotEmpty) {
        final proceed = await _showDuplicateWarning(nearbyTrees);
        if (!mounted || proceed != true) {
          return;
        }
      }
      await _saveTree();
    } catch (_) {
      _message('Data belum berhasil disimpan. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showConditionGuide() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Panduan Ciri-Ciri Kondisi Pohon'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guideSection(
                    title: 'Sakit',
                    color: treeConditionColor(TreeCondition.sakit),
                    points: const [
                      'Daun tampak kusam, pucat, atau layu ringan padahal tanah cukup basah',
                      'Muncul bercak kuning/cokelat/hitam pada daun yang makin melebar',
                      'Daun rontok di luar musim atau siklus normalnya',
                      'Tunas baru kerdil, atau ujung dahan mulai mengering',
                      'Kulit batang memar, melunak, retak tipis, atau keluar getah tak wajar',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _guideSection(
                    title: 'Rawan Tumbang',
                    color: treeConditionColor(TreeCondition.rawanTumbang),
                    points: const [
                      'Batang miring tajam (lebih dari ~30°) atau kemiringan berubah mendadak',
                      'Tanah di sekitar akar terangkat, retak, atau bergelombang',
                      'Batang keropos/berlubang di bagian dalam',
                      'Ada retakan vertikal dalam yang membelah batang utama',
                      'Tumbuh jamur di pangkal batang (tanda akar/pangkal mulai busuk)',
                      'Tajuk berat sebelah, daun/dahan hanya lebat di satu sisi',
                      'Banyak cabang besar yang mati, kering, atau menggantung patah',
                      'Akar terpotong atau tertutup semen akibat galian/proyek',
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _guideSection({
    required String title,
    required Color color,
    required List<String> points,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...points.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('•  $p', style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDuplicateWarning(List<TreeData> nearbyTrees) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pohon Kemungkinan Sudah Terdata'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ditemukan pohon lain yang sudah tercatat sangat dekat dengan lokasi ini. '
                    'Periksa kembali sebelum menyimpan — mungkin ini pohon yang sama.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...nearbyTrees.map((t) {
                    final distance = distanceInMeters(
                      _position!.latitude,
                      _position!.longitude,
                      t.latitude,
                      t.longitude,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.species,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${distance.toStringAsFixed(1)} m dari lokasi Anda • oleh ${t.surveyorName}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal, Saya Cek Dulu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tetap Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTree() async {
    if (_isEditing) {
      await _saveEdit();
      return;
    }
    final tree = TreeData(
      id: '',
      latitude: _position!.latitude,
      longitude: _position!.longitude,
      photoBase64: _photoBase64!,
      surveyorId: widget.surveyorUser.uid,
      surveyorName: widget.surveyorUser.name,
      species: _effectiveSpecies,
      kecamatan: _effectiveKecamatan,
      kelurahan: _kelurahanController.text.trim(),
      namaJalan: _namaJalanController.text.trim(),
      condition: _condition,
      ranahKewenangan: _effectiveAuthority,
      keteranganKondisi: _requiresKeterangan
          ? _keteranganKondisiController.text.trim()
          : '',
      timestamp: DateTime.now(),
      status: TreeStatus.pending,
    );

    final error = await _treeService.createTree(tree);

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data pohon berhasil disimpan!'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _step = 0;
      _selectedSpecies = null;
      _selectedKecamatan = null;
      _condition = TreeCondition.sehat;
      _authority = null;
      _authorityController.clear();
      _customSpeciesController.clear();
      _kecamatanCustomController.clear();
      _kelurahanController.clear();
      _namaJalanController.clear();
      _keteranganKondisiController.clear();
      _photoBytes = null;
      _photoBase64 = null;
      _position = null;
      _locationError = null;
      _initialDraft = _draftSnapshot();
    });
  }

  Future<void> _saveEdit() async {
    final problem = _editProblem;
    if (problem != null) {
      _message(problem);
      return;
    }
    final updated = _latestEditTree!.copyWith(
      latitude: _position!.latitude,
      longitude: _position!.longitude,
      photoBase64: _photoBase64!,
      species: _effectiveSpecies,
      kecamatan: _effectiveKecamatan,
      kelurahan: _kelurahanController.text.trim(),
      namaJalan: _namaJalanController.text.trim(),
      condition: _condition,
      ranahKewenangan: _effectiveAuthority,
      keteranganKondisi: _requiresKeterangan
          ? _keteranganKondisiController.text.trim()
          : '',
    );
    final error = await _treeService.updateTree(updated);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _message(error);
      return;
    }
    _initialDraft = _draftSnapshot();
    await _exitGuardKey.currentState?.leave(true);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      key: _exitGuardKey,
      hasChanges: _hasChanges,
      busy: _busy,
      hasPreviousStep: _step > 0,
      onPreviousStep: () => setState(() => _step -= 1),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F5),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(_isEditing ? 'Edit Pohon' : 'Tambah Pohon'),
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: _busy ? null : _back,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _formBody(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formFields() => [
    Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CivicHeading(
        eyebrow: 'PENDATAAN POHON • LANGKAH ${_step + 1}/3',
        title: [
          'Tentukan lokasi',
          'Kenali pohonnya',
          'Lengkapi dokumentasi',
        ][_step],
        description: [
          'Pastikan titik peta sesuai dengan posisi pohon di lapangan.',
          'Catat jenis, kondisi, dan kewenangan pengelolaan pohon.',
          'Gunakan foto yang jelas agar hasil survei mudah diperiksa.',
        ][_step],
      ),
    ),
    if (_step == 0) _locationStep(),
    if (_step == 1) _treeStep(),
    if (_step == 2) _photoStep(),
  ];

  Widget _formBody() => LayoutBuilder(
    builder: (context, constraints) {
      final warning = _editProblem != null && !_isSaving
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _editProblem!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            )
          : const SizedBox.shrink();
      final actions = Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _stepActions(),
      );
      // Landscape/keyboard: seluruh isi dapat discroll, bukan Column meluber.
      if (constraints.maxHeight < 420) {
        return ListView(
          key: ValueKey('compact-$_step'),
          children: [
            _stepIndicator(),
            warning,
            AbsorbPointer(
              absorbing: _busy,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _formFields(),
                ),
              ),
            ),
            actions,
          ],
        );
      }
      return Column(
        children: [
          _stepIndicator(),
          warning,
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.all(16),
                children: _formFields(),
              ),
            ),
          ),
          actions,
        ],
      );
    },
  );

  Widget _stepActions() => LayoutBuilder(
    builder: (context, constraints) {
      final back = OutlinedButton(
        onPressed: _busy ? null : _back,
        child: const Text('Kembali'),
      );
      final next = FilledButton(
        onPressed: _step == 2
            ? (_canSubmit ? _submit : null)
            : (_busy ? null : _next),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _step == 2
                    ? (_isEditing ? 'Simpan Perubahan' : 'Simpan')
                    : 'Lanjut',
              ),
      );
      final stacked =
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            next,
            if (_step > 0) ...[const SizedBox(height: 8), back],
          ],
        );
      }
      return Row(
        children: [
          if (_step > 0) ...[back, const SizedBox(width: 12)],
          Expanded(child: next),
        ],
      );
    },
  );

  Widget _stepIndicator() {
    const labels = ['Data Lokasi', 'Data Pohon', 'Foto'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: index == 0
                              ? Colors.transparent
                              : index <= _step
                              ? AppColors.leaf
                              : Colors.black12,
                        ),
                      ),
                      Semantics(
                        label: 'Langkah ${index + 1}: ${labels[index]}',
                        selected: index == _step,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: index <= _step
                              ? AppColors.leaf
                              : Colors.blueGrey.shade50,
                          child: index < _step
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: index == _step
                                        ? Colors.white
                                        : AppColors.navy,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: index == labels.length - 1
                              ? Colors.transparent
                              : index < _step
                              ? AppColors.leaf
                              : Colors.black12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: index <= _step ? AppColors.leaf : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationStep() {
    final point = _position;
    return Form(
      key: _locationFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 190,
              child: point == null
                  ? Container(
                      color: Colors.blueGrey.shade50,
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 52,
                          color: Colors.blueGrey,
                        ),
                      ),
                    )
                  : IgnorePointer(
                      child: FlutterMap(
                        key: ValueKey('${point.latitude},${point.longitude}'),
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 17,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.pemetaanpohon.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.location_on,
                                  size: 36,
                                  color: _isLocationValid
                                      ? AppColors.leaf
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          RichAttributionWidget(
                            attributions: [
                              const TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (point != null)
            Text(
              _isLocationValid
                  ? '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'
                  : 'Lokasi berada di luar wilayah Kota Cirebon.',
              style: TextStyle(
                color: _isLocationValid ? AppColors.leaf : Colors.red,
              ),
            ),
          if (_locationError != null)
            Text(_locationError!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Pilih Lokasi di Peta'),
          ),
          TextButton.icon(
            onPressed: _isFetchingLocation ? null : _fetchLocation,
            icon: _isFetchingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _isFetchingLocation
                  ? 'Mengambil lokasi...'
                  : 'Gunakan Lokasi GPS',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedKecamatan,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kecamatan *'),
            items: kecamatanOptions
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            validator: (value) => value == null ? 'Pilih kecamatan.' : null,
            onChanged: (value) => setState(() => _selectedKecamatan = value),
          ),
          if (_selectedKecamatan == 'Lainnya') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _kecamatanCustomController,
              decoration: const InputDecoration(
                labelText: 'Sebutkan kecamatan *',
              ),
              validator: (value) => _required(value, 'Isi kecamatan.'),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _kelurahanController,
            decoration: const InputDecoration(
              labelText: 'Kelurahan (opsional)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _namaJalanController,
            decoration: const InputDecoration(
              labelText: 'Alamat Pohon / Nama Jalan *',
              hintText: 'Mis. Jl. Siliwangi',
            ),
            validator: (value) => _required(value, 'Isi nama jalan.'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  Widget _treeStep() {
    return Form(
      key: _treeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSpecies,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Jenis Pohon *'),
            items: speciesOptions
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            validator: (value) => value == null ? 'Pilih jenis pohon.' : null,
            onChanged: (value) => setState(() => _selectedSpecies = value),
          ),
          if (_selectedSpecies == 'Lainnya') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customSpeciesController,
              decoration: const InputDecoration(
                labelText: 'Sebutkan jenis pohon *',
              ),
              validator: (value) => _required(value, 'Isi jenis pohon.'),
            ),
          ],
          const SizedBox(height: 20),
          TreeAuthorityField(
            selection: _authority,
            customController: _authorityController,
            onChanged: (value) => setState(() => _authority = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kondisi Pohon',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _showConditionGuide,
                tooltip: 'Panduan kondisi pohon',
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TreeCondition.values.map((condition) {
              final color = treeConditionColor(condition);
              return ChoiceChip(
                avatar: TreeSilhouette(color: color, size: 20),
                label: Text(condition.label),
                selected: _condition == condition,
                selectedColor: color.withValues(alpha: .15),
                onSelected: (_) => setState(() => _condition = condition),
              );
            }).toList(),
          ),
          if (_requiresKeterangan) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _keteranganKondisiController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Keterangan Kondisi *',
                hintText: 'Jelaskan kondisi pohon yang ditemukan.',
              ),
              validator: (value) =>
                  _required(value, 'Isi keterangan kondisi pohon.'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Foto Pohon *',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _photoBytes!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Foto tidak dapat ditampilkan. Ambil ulang foto.',
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 48,
              color: Colors.blueGrey,
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isPickingPhoto ? null : _takePhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(
            _isPickingPhoto
                ? 'Membuka kamera...'
                : _photoBytes == null
                ? 'Ambil Foto'
                : 'Ambil Ulang Foto',
          ),
        ),
        if (_photoBytes != null)
          TextButton.icon(
            onPressed: () => setState(() {
              _photoBytes = null;
              _photoBase64 = null;
            }),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus Foto'),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_effectiveSpecies),
                Text(
                  'Kewenangan: ${_effectiveAuthority.isEmpty ? 'Belum diketahui' : _effectiveAuthority}',
                ),
                Text(
                  '${_namaJalanController.text.trim()}, $_effectiveKecamatan',
                ),
                Text(
                  _condition.label,
                  style: TextStyle(color: treeConditionColor(_condition)),
                ),
              ],
            ),
          ),
        ),
        if (_photoBytes == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ambil satu foto pohon sebelum menyimpan.'),
          ),
      ],
    );
  }
}
