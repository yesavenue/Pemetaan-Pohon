import 'dart:convert';
import 'package:flutter/material.dart';
import '../tree_authority_field.dart';
import '../public/public_visuals.dart';
import '../../models/app_user.dart';
import '../../models/tree_data.dart';
import '../../models/tree_pruning_request.dart';
import '../../theme/app_theme.dart';
import '../../utils/tree_options.dart';
import '../surveyor/tree_thumbnail.dart';
import 'admin_dialog_scope.dart';

typedef AdminWrite = Future<String?> Function();
typedef RequestStatusWrite =
    Future<String?> Function(String id, PruningStatus status, String reason);

/// Single guard for confirmation/forms: failure keeps the dialog and draft.
class AdminActionDialog extends StatefulWidget {
  final String title, submitLabel, cancelLabel;
  final Widget Function(BuildContext, StateSetter) content;
  final AdminWrite operation;
  final String? Function()? validate;
  final ValueChanged<bool>? onBusy;
  final VoidCallback? onDispose;
  final List<Widget> Function(bool busy)? extraActions;
  final bool destructive;
  final bool canSubmit;
  const AdminActionDialog({
    super.key,
    required this.title,
    required this.content,
    required this.operation,
    this.submitLabel = 'Simpan',
    this.cancelLabel = 'Batal',
    this.validate,
    this.onBusy,
    this.onDispose,
    this.extraActions,
    this.destructive = false,
    this.canSubmit = true,
  });
  @override
  State<AdminActionDialog> createState() => _AdminActionDialogState();
}

class _AdminActionDialogState extends State<AdminActionDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _run() async {
    if (!mounted || _busy || !widget.canSubmit) return;
    final invalid = widget.validate?.call();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusy?.call(true);
    String? error;
    try {
      error = await widget.operation();
    } catch (_) {
      error =
          'Tindakan belum berhasil. Periksa koneksi dan hak akses, lalu coba kembali.';
    }
    widget.onBusy?.call(false);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_busy,
    child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AbsorbPointer(
              absorbing: _busy,
              child: widget.content(context, setState),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const Text('Sedang memproses…'),
            ],
          ],
        ),
      ),
      actions: [
        ...?widget.extraActions?.call(_busy),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const ValueKey('admin-dialog-submit'),
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade800)
              : null,
          onPressed: _busy || !widget.canSubmit ? null : _run,
          child: Text(widget.submitLabel),
        ),
      ],
    ),
  );
}

Future<bool?> openAdminAction(BuildContext context, AdminActionDialog dialog) {
  if (!canOpenAdminDialog(context)) {
    dialog.onDispose?.call();
    return Future.value(false);
  }
  return showOwnedAdminDialog<bool>(
    context,
    dismissible: false,
    builder: (_) => dialog,
  );
}

Widget adminField(
  TextEditingController controller,
  String label, {
  int? max,
  int lines = 1,
  TextInputType? keyboard,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: TextField(
    controller: controller,
    maxLength: max,
    maxLines: lines,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      filled: true,
    ),
  ),
);
Widget adminSelect<T>(
  String label,
  T? value,
  List<T> items,
  String Function(T) name,
  ValueChanged<T?> change,
) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    hint: Text(
      items.isNotEmpty && items.first == null
          ? name(items.first)
          : 'Pilih $label',
    ),
    itemHeight: null,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in items)
        DropdownMenuItem<T>(
          value: item,
          child: Text(name(item), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: change,
  ),
);
Widget adminDetail(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      Text(value.trim().isEmpty ? '—' : value),
    ],
  ),
);

Future<bool?> showAddSurveyor(
  BuildContext context,
  Future<String?> Function(String, String) create, {
  ValueChanged<bool>? onBusy,
}) {
  final name = TextEditingController(), email = TextEditingController();
  return openAdminAction(
    context,
    AdminActionDialog(
      title: 'Buat akun surveyor',
      submitLabel: 'Buat Akun',
      onBusy: onBusy,
      content: (_, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminField(name, 'Nama Lengkap *', max: 200),
          adminField(
            email,
            'Email Pekerjaan *',
            max: 320,
            keyboard: TextInputType.emailAddress,
          ),
          const Text(
            'Password awal: Surveyor123! Akun wajib mengganti password saat login pertama.',
          ),
        ],
      ),
      validate: () => name.text.trim().isEmpty
          ? 'Isi nama lengkap.'
          : !RegExp(r'^[^ @]+@[^ @]+\.[^ @]+$').hasMatch(email.text.trim())
          ? 'Isi email pekerjaan yang valid.'
          : null,
      operation: () => create(name.text.trim(), email.text.trim()),
      onDispose: () {
        name.dispose();
        email.dispose();
      },
    ),
  );
}

Future<bool?> showTreeEditor(
  BuildContext context, {
  required AppUser admin,
  TreeData? tree,
  required Future<String?> Function(TreeData) save,
  ValueChanged<bool>? onBusy,
}) {
  final species = TextEditingController(
    text: tree != null && !speciesOptions.contains(tree.species)
        ? tree.species
        : '',
  );
  final kec = TextEditingController(
    text: tree != null && !kecamatanOptions.contains(tree.kecamatan)
        ? tree.kecamatan
        : '',
  );
  final kel = TextEditingController(text: tree?.kelurahan ?? ''),
      road = TextEditingController(text: tree?.namaJalan ?? '');
  final existingAuthority = tree?.ranahKewenangan ?? '';
  final authority = TextEditingController(text: existingAuthority);
  String? selectedAuthority = existingAuthority.isEmpty
      ? null
      : treeAuthorityOptions.contains(existingAuthority)
      ? existingAuthority
      : 'Lainnya';
  String effectiveAuthority() => selectedAuthority == 'Lainnya'
      ? authority.text.trim()
      : (selectedAuthority ?? '');
  final note = TextEditingController(text: tree?.keteranganKondisi ?? '');
  final lat = TextEditingController(), lng = TextEditingController();
  String? selectedSpecies = tree == null
      ? null
      : speciesOptions.contains(tree.species)
      ? tree.species
      : 'Lainnya';
  String? selectedKec = tree == null
      ? null
      : kecamatanOptions.contains(tree.kecamatan)
      ? tree.kecamatan
      : 'Lainnya';
  var condition = tree?.condition ?? TreeCondition.sehat;
  String effectiveSpecies() {
    final value = selectedSpecies == 'Lainnya'
        ? species.text.trim()
        : selectedSpecies ?? '';
    return value.isEmpty && tree != null ? tree.species : value;
  }

  String effectiveKec() {
    final value = selectedKec == 'Lainnya'
        ? kec.text.trim()
        : selectedKec ?? '';
    return value.isEmpty && tree != null ? tree.kecamatan : value;
  }

  bool needsNote() => condition != TreeCondition.sehat;
  return openAdminAction(
    context,
    AdminActionDialog(
      title: tree == null ? 'Tambah data pohon' : 'Edit data pohon',
      onBusy: onBusy,
      content: (_, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminSelect(
            'Jenis Pohon *',
            selectedSpecies,
            speciesOptions,
            (v) => v,
            (v) => setState(() => selectedSpecies = v),
          ),
          if (selectedSpecies == 'Lainnya')
            adminField(species, 'Sebutkan jenis pohon *', max: 200),
          adminSelect(
            'Kondisi Pohon',
            condition,
            TreeCondition.values,
            (v) => v.label,
            (v) => setState(() => condition = v ?? condition),
          ),
          if (needsNote())
            adminField(note, 'Keterangan Kondisi *', max: 4000, lines: 3),
          const SizedBox(height: 16),
          TreeAuthorityField(
            selection: selectedAuthority,
            customController: authority,
            onChanged: (value) => setState(() => selectedAuthority = value),
          ),
          adminSelect(
            'Kecamatan *',
            selectedKec,
            kecamatanOptions,
            (v) => v,
            (v) => setState(() => selectedKec = v),
          ),
          if (selectedKec == 'Lainnya')
            adminField(kec, 'Sebutkan kecamatan *', max: 200),
          adminField(kel, 'Kelurahan (opsional)', max: 200),
          adminField(
            road,
            tree == null ? 'Nama Jalan *' : 'Nama Jalan',
            max: 2000,
          ),
          if (tree == null) ...[
            adminField(
              lat,
              'Latitude *',
              keyboard: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            adminField(
              lng,
              'Longitude *',
              keyboard: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const Text(
              'Data manual admin langsung terverifikasi. Foto dapat tetap kosong.',
            ),
          ] else
            adminDetail('Koordinat', '${tree.latitude}, ${tree.longitude}'),
        ],
      ),
      validate: () {
        if (effectiveSpecies().isEmpty ||
            (tree == null &&
                (effectiveKec().isEmpty || road.text.trim().isEmpty))) {
          return 'Lengkapi jenis, kecamatan dan nama jalan.';
        }
        if (selectedAuthority == 'Lainnya' && effectiveAuthority().isEmpty) {
          return 'Isi ranah kewenangan.';
        }
        if (effectiveAuthority().length > 120) {
          return 'Ranah kewenangan maksimal 120 karakter.';
        }
        if (needsNote() && note.text.trim().isEmpty) {
          return 'Keterangan kondisi wajib diisi untuk pohon sakit atau rawan tumbang.';
        }
        if (effectiveSpecies().length > 200 ||
            effectiveKec().length > 200 ||
            (needsNote() && note.text.trim().length > 4000) ||
            road.text.trim().length > 2000 ||
            kel.text.trim().length > 200) {
          return 'Isian melebihi batas karakter.';
        }
        if (tree == null) {
          final a = double.tryParse(lat.text.trim()),
              b = double.tryParse(lng.text.trim());
          if (a == null ||
              b == null ||
              !a.isFinite ||
              !b.isFinite ||
              a.abs() > 90 ||
              b.abs() > 180) {
            return 'Isi koordinat valid: latitude −90…90, longitude −180…180.';
          }
        }
        return null;
      },
      operation: () {
        final updated = tree == null
            ? TreeData(
                id: '',
                latitude: double.parse(lat.text.trim()),
                longitude: double.parse(lng.text.trim()),
                photoBase64: '',
                surveyorId: admin.uid,
                surveyorName: 'Admin: ${admin.name}',
                species: effectiveSpecies(),
                kecamatan: effectiveKec(),
                kelurahan: kel.text.trim(),
                namaJalan: road.text.trim(),
                condition: condition,
                ranahKewenangan: effectiveAuthority(),
                keteranganKondisi: needsNote() ? note.text.trim() : '',
                timestamp: DateTime.now(),
                status: TreeStatus.verified,
              )
            : tree.copyWith(
                species: effectiveSpecies(),
                kecamatan: effectiveKec(),
                kelurahan: kel.text.trim(),
                namaJalan: road.text.trim(),
                condition: condition,
                ranahKewenangan: effectiveAuthority(),
                keteranganKondisi: needsNote() ? note.text.trim() : '',
              );
        return save(updated);
      },
      onDispose: () {
        for (final c in [species, kec, kel, road, note, lat, lng, authority]) {
          c.dispose();
        }
      },
    ),
  );
}

Widget adminTreeReview(TreeData tree) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _RequestPhoto(label: 'Foto pohon', data: tree.photoBase64),
    PublicConditionBadge(condition: tree.condition),
    const SizedBox(height: 12),
    adminDetail('Jenis pohon', tree.species),
    adminDetail(
      'Keterangan kondisi',
      tree.keteranganKondisi.isEmpty
          ? 'Tidak ada keterangan tambahan'
          : tree.keteranganKondisi,
    ),
    adminDetail(
      'Lokasi',
      [
        tree.namaJalan,
        tree.kelurahan,
        tree.kecamatan,
      ].where((v) => v.isNotEmpty).join(', '),
    ),
    adminDetail(
      'Ranah kewenangan',
      tree.ranahKewenangan.isEmpty ? 'Belum diketahui' : tree.ranahKewenangan,
    ),
    adminDetail('Surveyor', tree.surveyorName),
    adminDetail('Tanggal', tree.timestamp.toLocal().toString()),
    adminDetail('Koordinat', '${tree.latitude}, ${tree.longitude}'),
    adminDetail(
      'Status saat ini',
      tree.status == TreeStatus.verified ? 'Terverifikasi' : 'Menunggu',
    ),
  ],
);

void showAdminTreeDetail(BuildContext context, TreeData tree) =>
    showOwnedAdminDialog<void>(
      context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        scrollable: true,
        title: Text(tree.species),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RequestPhoto(label: 'Foto pohon', data: tree.photoBase64),
              const SizedBox(height: 16),
              adminDetail('Kecamatan', tree.kecamatan),
              adminDetail('Kelurahan', tree.kelurahan),
              adminDetail('Nama Jalan', tree.namaJalan),
              adminDetail('Kondisi', tree.condition.label),
              adminDetail(
                'Ranah kewenangan',
                tree.ranahKewenangan.isEmpty
                    ? 'Belum diketahui'
                    : tree.ranahKewenangan,
              ),
              adminDetail('Keterangan', tree.keteranganKondisi),
              adminDetail('Surveyor', tree.surveyorName),
              adminDetail('Tanggal', tree.timestamp.toLocal().toString()),
              adminDetail('Koordinat', '${tree.latitude}, ${tree.longitude}'),
              adminDetail(
                'Status',
                tree.status == TreeStatus.verified
                    ? 'Terverifikasi'
                    : 'Menunggu',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );

Future<bool?> showAdminRequestDetail(
  BuildContext context,
  TreePruningRequest request, {
  required RequestStatusWrite update,
  required Future<void> Function(TreePruningRequest) exportWord,
  required void Function(TreePruningRequest, bool) downloadPhoto,
  ValueChanged<bool>? onBusy,
}) {
  var status = request.status;
  final reason = TextEditingController(text: request.alasanPenolakan);
  String? exportError;
  return openAdminAction(
    context,
    AdminActionDialog(
      title: request.requestNumber,
      cancelLabel: 'Tutup',
      onBusy: onBusy,
      content: (dialogContext, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DATA PEMOHON',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          adminDetail('Nama', request.namaPemohon),
          adminDetail('Alamat pemohon', request.alamatPemohon),
          adminDetail('Nomor HP', request.nomorHp),
          adminDetail('Email', request.emailPemohon),
          adminDetail('NIK', request.nik),
          const Text(
            'DATA POHON',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          adminDetail('Alamat pohon', request.alamatPohon),
          adminDetail('Kecamatan', request.kecamatan),
          adminDetail('Kelurahan', request.kelurahan),
          adminDetail('Alasan', request.alasan),
          adminDetail(
            'Lokasi GPS',
            request.hasLocation
                ? '${request.latitude}, ${request.longitude}'
                : 'Alamat manual, GPS tidak digunakan',
          ),
          _RequestPhoto(
            label: 'Foto pohon',
            data: request.fotoPohonBase64,
            download: () => downloadPhoto(request, false),
          ),
          _RequestPhoto(
            label: 'Foto KTP',
            data: request.fotoKtpBase64,
            download: () => downloadPhoto(request, true),
          ),
          adminSelect(
            'Status',
            status,
            PruningStatus.values,
            (v) => v.label,
            (v) => setState(() => status = v ?? status),
          ),
          if (status == PruningStatus.ditolak)
            adminField(reason, 'Alasan Penolakan *', max: 4000, lines: 3),
          if (exportError != null)
            Text(exportError!, style: const TextStyle(color: Colors.red)),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await exportWord(request);
              } catch (_) {
                if (dialogContext.mounted) {
                  setState(
                    () =>
                        exportError = 'Unduhan Word belum berhasil. Coba lagi.',
                  );
                }
              }
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('Export Word'),
          ),
        ],
      ),
      validate: () =>
          status == PruningStatus.ditolak && reason.text.trim().isEmpty
          ? 'Isi alasan penolakan sebelum menyimpan.'
          : reason.text.trim().length > 4000
          ? 'Alasan penolakan maksimal 4000 karakter.'
          : null,
      operation: () => update(
        request.id,
        status,
        status == PruningStatus.ditolak ? reason.text.trim() : '',
      ),
      onDispose: reason.dispose,
    ),
  );
}

class _RequestPhoto extends StatefulWidget {
  final String label, data;
  final VoidCallback? download;
  const _RequestPhoto({required this.label, required this.data, this.download});
  @override
  State<_RequestPhoto> createState() => _RequestPhotoState();
}

class _RequestPhotoState extends State<_RequestPhoto> {
  MemoryImage? _image;
  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _RequestPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _decode();
    }
  }

  void _decode() {
    _image = null;
    try {
      final bytes = base64Decode(widget.data);
      if (bytes.isNotEmpty) {
        _image = MemoryImage(bytes);
      }
    } on FormatException {
      /* Use thumbnail fallback. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final data = widget.data;
    final download = widget.download;
    final image = _image;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TreeThumbnail(base64: data, size: 600, height: 180),
          if (image != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('admin-photo-open-$label'),
                  onPressed: () => showOwnedAdminDialog<void>(
                    context,
                    allowNested: true,
                    builder: (photoContext) => Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: 960,
                        height: MediaQuery.sizeOf(photoContext).height * .85,
                        child: PublicPhotoViewer(image: image, title: label),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.zoom_in),
                  label: Text('Perbesar $label'),
                ),
                if (download != null)
                  OutlinedButton.icon(
                    onPressed: download,
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Download $label'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}