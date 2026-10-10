import 'package:flutter/material.dart';
import '../../models/tree_data.dart';

/// Selection belongs to the parent dialog; search never discards hidden picks.
class AdminExportPicker extends StatefulWidget {
  final List<TreeData> items;
  final Set<String> selected;
  final VoidCallback onChanged;
  const AdminExportPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });
  @override
  State<AdminExportPicker> createState() => _AdminExportPickerState();
}

class _AdminExportPickerState extends State<AdminExportPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.items
        .where(
          (t) => [
            t.id,
            t.species,
            t.kecamatan,
            t.kelurahan,
            t.namaJalan,
            t.surveyorName,
          ].any((v) => v.toLowerCase().contains(_query)),
        )
        .toList();
    final allVisible =
        visible.isNotEmpty &&
        visible.every((t) => widget.selected.contains(t.id));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('export-search'),
          decoration: const InputDecoration(
            labelText: 'Cari pohon untuk ekspor',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${widget.selected.length} dipilih • ${visible.length} hasil pencarian',
            key: const ValueKey('export-selection-count'),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: visible.isEmpty
                  ? null
                  : () {
                      for (final row in visible) {
                        if (allVisible) {
                          widget.selected.remove(row.id);
                        } else {
                          widget.selected.add(row.id);
                        }
                      }
                      widget.onChanged();
                    },
              child: Text(
                _query.isEmpty
                    ? (allVisible ? 'Batal Semua' : 'Pilih Semua')
                    : (allVisible
                          ? 'Batalkan hasil pencarian'
                          : 'Pilih hasil pencarian'),
              ),
            ),
            if (widget.selected.isNotEmpty)
              TextButton(
                onPressed: () {
                  widget.selected.clear();
                  widget.onChanged();
                },
                child: const Text('Kosongkan pilihan'),
              ),
          ],
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * .32).clamp(140.0, 320.0),
          child: visible.isEmpty
              ? const Center(child: Text('Tidak ada pohon yang cocok.'))
              : ListView.builder(
                  key: const ValueKey('export-pick-list'),
                  primary: false,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final row = visible[index];
                    return CheckboxListTile(
                      key: ValueKey('export-pick-${row.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.species),
                      subtitle: Text('${row.kecamatan} • ${row.id}'),
                      value: widget.selected.contains(row.id),
                      onChanged: (value) {
                        if (value == true) {
                          widget.selected.add(row.id);
                        } else {
                          widget.selected.remove(row.id);
                        }
                        widget.onChanged();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}