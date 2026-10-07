import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/tree_data.dart';
import '../../services/tree_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tree_condition_style.dart';
import '../../widgets/surveyor/tree_thumbnail.dart';
import '../tree_input_screen.dart';
import 'tree_browser.dart';

class TreeDetailScreen extends StatefulWidget {
  final TreeData tree;
  final AppUser surveyorUser;

  const TreeDetailScreen({
    super.key,
    required this.tree,
    required this.surveyorUser,
  });

  @override
  State<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends State<TreeDetailScreen> {
  final _service = TreeService();
  StreamSubscription<List<TreeData>>? _subscription;
  TreeData? _tree;
  bool _loaded = false;
  bool _readError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _watchTree();
  }

  void _watchTree() {
    _subscription?.cancel();
    _subscription = _service.streamTrees().listen(
      (trees) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tree = trees.where((item) => item.id == widget.tree.id).firstOrNull;
          _loaded = true;
          _readError = false;
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _readError = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _canManage(TreeData tree) =>
      widget.surveyorUser.isActive &&
      tree.surveyorId == widget.surveyorUser.uid &&
      FirebaseAuth.instance.currentUser?.uid == widget.surveyorUser.uid;

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit(TreeData tree) async {
    if (_busy || !_canManage(tree)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TreeInputScreen(
            surveyorUser: widget.surveyorUser,
            initialTree: tree,
          ),
        ),
      );
      if (saved == true) {
        _message('Data pohon berhasil diperbarui.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(TreeData tree) async {
    if (_busy || !_canManage(tree)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hapus Pohon?'),
          content: Text(
            'Data "${tree.species}" di ${tree.namaJalan} akan dihapus permanen. '
            'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      final current = _tree;
      if (_readError || current == null || !_canManage(current)) {
        _message(
          'Pohon tidak tersedia atau akun ini tidak dapat menghapusnya.',
        );
        return;
      }
      if (!mapEquals(current.toMap(), tree.toMap())) {
        _message(
          'Data pohon berubah. Periksa detail terbaru sebelum menghapus.',
        );
        return;
      }
      final error = await _service.deleteTree(current.id);
      if (!mounted) {
        return;
      }
      if (error != null) {
        _message(error);
        return;
      }
      _message('Data pohon berhasil dihapus.');
      Navigator.pop(context);
    } catch (_) {
      _message('Pohon belum berhasil dihapus. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pohon'),
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_readError) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Detail pohon gagal dimuat.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _readError = false;
                            _loaded = false;
                          });
                          _watchTree();
                        },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_loaded || (_busy && _tree == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    final tree = _tree;
    if (tree == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pohon ini sudah tidak tersedia. Kembali ke daftar pohon.',
          ),
        ),
      );
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) => TreeThumbnail(
                  base64: tree.photoBase64,
                  size: constraints.maxWidth,
                  height: 220,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tree.species,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.circle,
                      size: 10,
                      color: treeConditionColor(tree.condition),
                    ),
                    label: Text(tree.condition.label),
                    backgroundColor: treeConditionColor(
                      tree.condition,
                    ).withValues(alpha: .1),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(Icons.location_on, 'Lokasi', tree.namaJalan),
              _field(
                Icons.my_location,
                'Koordinat',
                '${tree.latitude.toStringAsFixed(6)}, ${tree.longitude.toStringAsFixed(6)}',
              ),
              _field(Icons.location_city, 'Kecamatan', tree.kecamatan),
              _field(Icons.apartment, 'Kelurahan', tree.kelurahan),
              _field(Icons.notes, 'Keterangan Kondisi', tree.keteranganKondisi),
              _field(Icons.schedule, 'Tanggal Input', _date(tree.timestamp)),
              _field(
                Icons.verified_outlined,
                'Verifikasi Admin',
                tree.status == TreeStatus.verified
                    ? 'Terverifikasi'
                    : 'Menunggu verifikasi',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Lihat di Peta'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Lokasi Pohon')),
                            body: TreeBrowser(
                              trees: [tree],
                              mapMode: true,
                              initialTreeId: tree.id,
                              onOpenTree: (_) => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
              ),
              if (_canManage(tree)) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(14) > 21;
                    final width = stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _edit(tree),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: _busy ? null : () => _delete(tree),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}, '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Widget _field(IconData icon, String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Colors.blueGrey, size: 22),
    title: Text(
      label,
      style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
    ),
    subtitle: Text(
      value.isEmpty ? '—' : value,
      style: const TextStyle(color: AppColors.navy),
    ),
  );
}