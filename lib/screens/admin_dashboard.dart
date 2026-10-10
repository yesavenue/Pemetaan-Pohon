import 'dart:convert';
import '../utils/session_feed.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, debugPrint, debugPrintStack;
import 'package:firebase_core/firebase_core.dart';
import '../services/demo_tree_service.dart';
import '../utils/demo_tree_seed.dart';
import '../utils/demo_tree_photos.dart';
import '../widgets/civic_design.dart';
import '../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../models/tree_pruning_request.dart';
import '../services/auth_service.dart';
import '../services/pruning_request_service.dart';
import '../services/tree_service.dart';
import '../utils/pruning_docx_builder.dart';
import '../utils/tree_condition_style.dart';
import '../utils/tree_excel_export.dart';
import '../utils/web_download.dart';
import '../widgets/admin/admin_shell.dart';
import '../widgets/admin/admin_overview.dart';
import '../widgets/admin/admin_sections.dart';
import '../widgets/admin/admin_dialogs.dart';
import '../widgets/admin/admin_dialog_scope.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser adminUser;
  const AdminDashboard({super.key, required this.adminUser});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _treeService = TreeService();
  final _requestService = PruningRequestService();
  late final _treesFeed = SessionFeed<List<TreeData>>(_treeService.streamTrees);
  late final _usersFeed = SessionFeed<List<AppUser>>(
    _authService.streamSurveyors,
  );
  late final _requestsFeed = SessionFeed<List<TreePruningRequest>>(
    _requestService.streamRequests,
  );
  @override
  void dispose() {
    _treesFeed.dispose();
    _usersFeed.dispose();
    _requestsFeed.dispose();
    super.dispose();
  }

  final _requestKey = GlobalKey<AdminRequestsPaneState>();
  final _visited = <int>{0};
  final _dialogContextKey = GlobalKey();
  BuildContext get _dialogContext =>
      _dialogContextKey.currentContext ?? context;
  bool _isLoggingOut = false;
  bool _busyOperation = false;
  bool get _locked => _isLoggingOut || _busyOperation;
  void _setBusy(bool value) {
    if (mounted) setState(() => _busyOperation = value);
  }

  final _dataPohonKey = GlobalKey<AdminTreesPaneState>();
  int _selectedIndex = 0;

  Future<void> _showAddSurveyorDialog() async {
    if (_locked) return;
    final result = await showAddSurveyor(
      _dialogContext,
      (name, email) =>
          _authService.createSurveyorByAdmin(name, email, 'Surveyor123!'),
      onBusy: _setBusy,
    );
    if (mounted && result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Akun surveyor dibuat.')));
    }
  }

  Future<void> _manageDemoTrees({required bool remove}) async {
    if (!kDebugMode || _locked) return;
    var changed = 0;
    final accepted = await openAdminAction(
      _dialogContext,
      AdminActionDialog(
        title: remove ? 'Hapus data contoh?' : 'Isi 30 data pohon contoh?',
        submitLabel: remove ? 'Hapus data contoh' : 'Buat 30 data contoh',
        destructive: remove,
        onBusy: _setBusy,
        content: (_, setState) => Text(
          remove
              ? 'Hanya data dari generator ini milik akun admin Anda yang dihapus. Data pohon asli dan data contoh akun lain tidak disentuh.'
              : 'Membuat 30 pohon terverifikasi pada database aplikasi yang sedang terhubung: 21 sehat, 6 sakit, dan 3 rawan tumbang. Data akan muncul di peta serta statistik publik. Lokasi, wilayah dan ilustrasi adalah simulasi, ditandai DATA CONTOH. Klik ulang tidak menggandakan atau menimpa data. Hapus data contoh setelah pengujian.',
        ),
        operation: () async {
          var stage = 'menyiapkan generator';
          var projectId = 'belum terbaca';
          try {
            projectId = Firebase.app().options.projectId;
            final service = DemoTreeService();
            if (remove) {
              stage = 'menghapus data contoh di Firestore';
              changed = await service.remove(widget.adminUser);
            } else {
              stage = 'membuat ilustrasi PNG';
              final photos = await buildDemoTreePhotos();
              stage = 'menyimpan 30 pohon ke Firestore';
              changed = await service.create(widget.adminUser, photos);
            }
            return null;
          } on FirebaseException catch (error, stack) {
            debugPrint(
              '[Generator contoh] tahap=$stage; proyek=$projectId; '
              'kode=${error.plugin}/${error.code}; pesan=${error.message}',
            );
            debugPrintStack(stackTrace: stack);
            final hint = switch (error.code) {
              'permission-denied' =>
                'Firestore menolak akses. Periksa rules yang SUDAH DIPUBLISH pada proyek di bawah dan profil akun admin aktif. Mengganti file rules lokal saja belum memperbarui Firebase.',
              'unauthenticated' =>
                'Sesi login tidak dikenali. Keluar lalu login kembali sebagai admin.',
              'unavailable' || 'deadline-exceeded' =>
                'Layanan atau koneksi belum tersedia. Periksa jaringan lalu coba kembali.',
              'aborted' =>
                'Transaksi berbenturan dengan perubahan data. Coba lagi; ID tetap mencegah duplikasi.',
              _ =>
                'Salin kode dan detail error ini agar penyebabnya dapat diperiksa.',
            };
            return 'Gagal saat $stage.\n'
                'Proyek: $projectId\n'
                'Kode: ${error.plugin}/${error.code}\n'
                '$hint\n'
                'Detail: ${error.message ?? "Tidak ada detail dari Firebase."}';
          } catch (error, stack) {
            debugPrint(
              '[Generator contoh] tahap=$stage; '
              'jenis=${error.runtimeType}; error=$error',
            );
            debugPrintStack(stackTrace: stack);
            return 'Gagal saat $stage.\n'
                'Jenis error: ${error.runtimeType}\n'
                'Detail: $error\n'
                'Kirim teks ini atau error pada terminal Flutter. '
                'Penyebabnya belum dapat dianggap sebagai masalah rules.';
          }
        },
      ),
    );
    if (mounted && accepted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remove
                ? '$changed data contoh dihapus.'
                : '$changed dari $demoTreeCount data contoh dibuat. Data yang sudah ada tidak diubah.',
          ),
        ),
      );
    }
  }

  Future<void> _exportTrees(
    List<TreeData> trees, {
    String scope = 'Semua data',
  }) async {
    final bytes = buildTreeExcelBytes(
      trees,
      scope: scope,
      preparedBy: widget.adminUser.name,
    );
    final filename =
        'data_pohon_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx';
    downloadBytesAsFile(
      bytes,
      filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _exportRequest(TreePruningRequest request) async {
    downloadBytesAsFile(
      buildSuratPermohonanDocx(request),
      'Surat_Permohonan_${request.requestNumber}.docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  void _downloadRequestPhoto(TreePruningRequest request, bool ktp) {
    try {
      final bytes = _decodeBase64(
        ktp ? request.fotoKtpBase64 : request.fotoPohonBase64,
      );
      if (bytes == null || bytes.isEmpty) return;
      final format = guessImageFormat(bytes);
      downloadBytesAsFile(
        bytes,
        '${ktp ? 'FotoKTP' : 'FotoPohon'}_${request.requestNumber}.${format.extension}',
        mimeType: format.mimeType,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unduhan foto belum berhasil. Coba lagi.'),
          ),
        );
      }
    }
  }

  void _selectPage(int index, {VoidCallback? afterMount}) {
    if (_locked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
    if (afterMount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) afterMount();
      });
    }
  }

  Future<void> _logout() async {
    if (_locked) return;
    setState(() => _isLoggingOut = true);
    try {
      await _authService.logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal keluar. Periksa koneksi lalu coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminDialogScope(
    child: Builder(
      key: _dialogContextKey,
      builder: (_) => AdminShell(
        user: widget.adminUser,
        page: AdminPage.values[_selectedIndex],
        enabled: !_locked,
        onSelect: (page) => _selectPage(page.index),
        onLogout: _logout,
        pageAction: _selectedIndex == 1
            ? FilledButton.icon(
                onPressed: _locked ? null : _showAddSurveyorDialog,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Tambah Surveyor'),
              )
            : _selectedIndex == 2
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (kDebugMode) ...[
                    OutlinedButton.icon(
                      onPressed: _locked
                          ? null
                          : () => _manageDemoTrees(remove: false),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Isi 30 data contoh'),
                    ),
                    TextButton.icon(
                      onPressed: _locked
                          ? null
                          : () => _manageDemoTrees(remove: true),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Hapus data contoh'),
                    ),
                  ],
                  FilledButton.icon(
                    onPressed: _locked
                        ? null
                        : () => _dataPohonKey.currentState?.showAddTreeDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Pohon'),
                  ),
                ],
              )
            : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            TickerMode(
              enabled: _selectedIndex == 0,
              child: AdminOverview(
                adminName: widget.adminUser.name,
                loadSurveyors: _usersFeed.loadView,
                loadTrees: _treesFeed.loadView,
                loadRequests: _requestsFeed.loadView,
                onAddSurveyor: _showAddSurveyorDialog,
                onAddTree: () => _selectPage(
                  2,
                  afterMount: () =>
                      _dataPohonKey.currentState?.showAddTreeDialog(),
                ),
                onAllTrees: () => _selectPage(
                  2,
                  afterMount: () =>
                      _dataPohonKey.currentState?.showPendingTrees(),
                ),
                onAllRequests: () => _selectPage(
                  3,
                  afterMount: () =>
                      _requestKey.currentState?.showWaitingRequests(),
                ),
                onReviewTree: (tree) => _selectPage(
                  2,
                  afterMount: () =>
                      _dataPohonKey.currentState?.showTreeReview(tree),
                ),
                onReviewRequest: (request) => _selectPage(
                  3,
                  afterMount: () =>
                      _requestKey.currentState?.showRequest(request),
                ),
                mapBuilder: (_, trees) => _TreeMapCard(trees: trees),
              ),
            ),
            if (_visited.contains(1))
              AdminSurveyorPane(
                load: _usersFeed.loadView,
                setActive: _authService.setSurveyorActiveStatus,
                resetPassword: _authService.sendPasswordResetEmail,
                deleteProfile: _authService.deleteSurveyorProfile,
                onBusy: _setBusy,
              )
            else
              const SizedBox.shrink(),
            if (_visited.contains(2))
              AdminTreesPane(
                key: _dataPohonKey,
                admin: widget.adminUser,
                load: _treesFeed.loadView,
                create: _treeService.createTree,
                update: _treeService.updateTree,
                setStatus: _treeService.setTreeStatus,
                delete: _treeService.deleteTree,
                export: _exportTrees,
                exportReport: (rows, scope) => _exportTrees(rows, scope: scope),
                onBusy: _setBusy,
              )
            else
              const SizedBox.shrink(),
            if (_visited.contains(3))
              AdminRequestsPane(
                key: _requestKey,
                load: _requestsFeed.loadView,
                update: (id, status, reason) => _requestService.updateStatus(
                  id,
                  status,
                  alasanPenolakan: reason,
                ),
                exportWord: _exportRequest,
                downloadPhoto: _downloadRequestPhoto,
                onBusy: _setBusy,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
}

// ==================== HELPER BERSAMA ====================

Uint8List? _decodeBase64(String data) {
  if (data.isEmpty) return null;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

void _showTreeDetailDialog(BuildContext context, TreeData tree) =>
    showAdminTreeDetail(context, tree);

// ==================== DASHBOARD ====================

class _TreeMapCard extends StatefulWidget {
  final List<TreeData> trees;
  const _TreeMapCard({required this.trees});

  @override
  State<_TreeMapCard> createState() => _TreeMapCardState();
}

class _TreeMapCardState extends State<_TreeMapCard> {
  String _speciesFilter = 'Semua';
  TreeCondition? _conditionFilter;

  @override
  Widget build(BuildContext context) {
    final speciesInData =
        widget.trees
            .map((t) => t.species)
            .where((s) => s != 'Semua')
            .toSet()
            .toList()
          ..sort();
    if (_speciesFilter != 'Semua' && !speciesInData.contains(_speciesFilter)) {
      speciesInData.add(_speciesFilter);
    }

    final filtered = widget.trees.where((t) {
      final matchesSpecies =
          _speciesFilter == 'Semua' ||
          t.species.trim().toLowerCase() == _speciesFilter.trim().toLowerCase();
      final matchesCondition =
          _conditionFilter == null || t.condition == _conditionFilter;
      return matchesSpecies && matchesCondition;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE5E0)),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Sebaran pohon terverifikasi',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _FilterDropdown<String>(
                  value: _speciesFilter,
                  items: ['Semua', ...speciesInData],
                  labelBuilder: (v) => v,
                  onChanged: (v) =>
                      setState(() => _speciesFilter = v ?? 'Semua'),
                ),
                _FilterDropdown<TreeCondition?>(
                  value: _conditionFilter,
                  items: [null, ...TreeCondition.values],
                  labelBuilder: (v) => v == null ? 'Semua Kondisi' : v.label,
                  onChanged: (v) => setState(() => _conditionFilter = v),
                ),
                if (_speciesFilter != 'Semua' || _conditionFilter != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _speciesFilter = 'Semua';
                      _conditionFilter = null;
                    }),
                    child: const Text('Reset Filter'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text(
              '${filtered.length} pohon sesuai filter • Pilih pohon untuk melihat detail.',
            ),
          ),
          SizedBox(height: 420, child: _TreeMap(trees: filtered)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final condition in TreeCondition.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TreeSilhouette(
                        color: treeConditionColor(condition),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(condition.label),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            itemHeight: null,
            items: items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelBuilder(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _TreeMap extends StatelessWidget {
  final List<TreeData> trees;
  const _TreeMap({required this.trees});

  static const _defaultCenter = LatLng(-6.7183, 108.5522); // Cirebon
  static const _defaultZoom = 13.0;

  @override
  Widget build(BuildContext context) {
    final center = trees.isEmpty
        ? _defaultCenter
        : LatLng(
            trees.map((t) => t.latitude).reduce((a, b) => a + b) / trees.length,
            trees.map((t) => t.longitude).reduce((a, b) => a + b) /
                trees.length,
          );

    // Lookup cepat untuk tahu kondisi tiap pohon di dalam satu cluster,
    // dipakai untuk mewarnai lingkaran cluster berdasarkan kondisi terparah.
    final treeById = {for (final t in trees) t.id: t};

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: trees.isEmpty ? _defaultZoom : 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pemetaanpohon.app',
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 50,
                size: const Size(42, 42),
                markers: trees.map((tree) {
                  return Marker(
                    key: ValueKey(tree.id),
                    point: LatLng(tree.latitude, tree.longitude),
                    width: 48,
                    height: 48,
                    child: Material(
                      color: Colors.white,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: treeConditionColor(tree.condition),
                          width: 2,
                        ),
                      ),
                      elevation: 3,
                      child: IconButton(
                        tooltip: '${tree.species}: ${tree.condition.label}',
                        onPressed: () => _showTreeDetailDialog(context, tree),
                        icon: TreeSilhouette(
                          color: treeConditionColor(tree.condition),
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  final conditions = markers
                      .map(
                        (m) => treeById[(m.key as ValueKey<String>).value]
                            ?.condition,
                      )
                      .whereType<TreeCondition>()
                      .toSet();
                  final worst = conditions.contains(TreeCondition.rawanTumbang)
                      ? TreeCondition.rawanTumbang
                      : conditions.contains(TreeCondition.sakit)
                      ? TreeCondition.sakit
                      : TreeCondition.sehat;
                  final color = treeConditionColor(worst);
                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${markers.length}',
                      style: TextStyle(
                        color: worst == TreeCondition.sakit
                            ? AppColors.navy
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (trees.isEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: const Text(
                'Belum ada pohon terverifikasi untuk ditampilkan.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        const Positioned(
          bottom: 4,
          right: 8,
          left: 8,
          child: ColoredBox(
            color: Colors.white,
            child: Text(
              '© OpenStreetMap contributors',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}