import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/tree_pruning_request.dart';
import '../../services/pruning_request_service.dart';

class AdminRequestHistory extends StatefulWidget {
  final String requestId;
  final Future<List<Map<String, dynamic>>> Function(String)? load;
  const AdminRequestHistory({super.key, required this.requestId, this.load});
  @override
  State<AdminRequestHistory> createState() => _AdminRequestHistoryState();
}

class _AdminRequestHistoryState extends State<AdminRequestHistory> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  Future<void> _reload() async {
    if (_loading || !mounted) return;
    final generation = ++_generation;
    setState(() { _loading = true; _failed = false; });
    try {
      // Attach the error handler immediately, before the next widget build.
      final rows = await (widget.load ?? PruningRequestService().history)(widget.requestId);
      if (!mounted || generation != _generation) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() { _failed = true; _loading = false; });
    }
  }

  @override
  void didUpdateWidget(covariant AdminRequestHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _generation++;
      _rows = null;
      _loading = false;
      _failed = false;
    }
  }
  String _date(Object? value) {
    if (value is! Timestamp) return 'Waktu belum tersedia';
    final d = value.toDate().toUtc().add(const Duration(hours: 7));
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} • ${pad(d.hour)}:${pad(d.minute)} WIB';
  }
  @override
  Widget build(BuildContext context) {
    if (!PruningRequestService.validAccessCode(widget.requestId)) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Permohonan lama: riwayat pelacakan belum tersedia.'));
    }
    return ExpansionTile(
      key: ValueKey(widget.requestId),
      title: const Text('Riwayat status'),
      subtitle: const Text('Perubahan yang tercatat untuk pelacakan warga'),
      tilePadding: EdgeInsets.zero,
      onExpansionChanged: (open) {
        if (open && _rows == null && !_failed) _reload();
      },
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
        else if (_failed)
          Column(children: [
            const Text('Riwayat belum dapat dimuat. Periksa koneksi dan coba lagi.'),
            TextButton(onPressed: _reload, child: const Text('Coba lagi')),
          ])
        else if (_rows != null)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_rows!.isEmpty) const Text('Belum ada riwayat status yang tercatat.'),
            for (final row in _rows!) ListTile(contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(PruningStatus.fromString(row['status'] as String? ?? '').label),
              subtitle: Text(_date(row['at']))),
            const Text('Maksimal 100 perubahan terbaru, dari yang paling baru.'),
            Align(alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _reload, child: const Text('Muat ulang riwayat'))),
          ]),
      ],
    );
  }
}
