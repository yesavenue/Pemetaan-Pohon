import 'package:flutter/material.dart';

const treeAuthorityOptions = [
  'Pusat',
  'Provinsi',
  'Kota Cirebon',
  'Kabupaten Cirebon',
];

/// Optional for legacy records; selecting Lainnya requires a real description.
class TreeAuthorityField extends StatelessWidget {
  final String? selection;
  final TextEditingController customController;
  final ValueChanged<String?> onChanged;
  const TreeAuthorityField({
    super.key,
    required this.selection,
    required this.customController,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        value: selection ?? '',
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(
          labelText: 'Ranah kewenangan',
          prefixIcon: Icon(Icons.account_balance_outlined),
          helperText: 'Pilih sesuai informasi kewenangan yang diketahui.',
          helperMaxLines: 3,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Belum diketahui')),
          for (final value in [...treeAuthorityOptions, 'Lainnya'])
            DropdownMenuItem(value: value, child: Text(value)),
        ],
        onChanged: (value) => onChanged(value == '' ? null : value),
      ),
      if (selection == 'Lainnya') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: customController,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Sebutkan ranah kewenangan',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Isi ranah kewenangan.'
              : value.trim().length > 120
              ? 'Maksimal 120 karakter.'
              : null,
        ),
      ],
    ],
  );
}