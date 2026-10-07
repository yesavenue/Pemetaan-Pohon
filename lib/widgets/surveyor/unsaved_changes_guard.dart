import 'dart:async';

import 'package:flutter/material.dart';

/// Perlindungan keluar route saja, bukan penyimpanan draft permanen.
class UnsavedChangesGuard extends StatefulWidget {
  final bool hasChanges;
  final bool busy;
  final bool hasPreviousStep;
  final VoidCallback onPreviousStep;
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.busy,
    required this.hasPreviousStep,
    required this.onPreviousStep,
    required this.child,
  });

  @override
  State<UnsavedChangesGuard> createState() => UnsavedChangesGuardState();
}

class UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _confirming = false;
  bool _leaving = false;

  Future<void> requestBack() async {
    if (widget.busy || _confirming || _leaving) return;
    FocusScope.of(context).unfocus();
    if (widget.hasPreviousStep) {
      widget.onPreviousStep();
      return;
    }
    if (!widget.hasChanges) {
      await leave();
      return;
    }
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text(
          'Data yang belum disimpan akan hilang jika Anda keluar dari formulir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut mengisi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buang perubahan'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (discard == true && !widget.busy) await leave();
  }

  /// Dipakai setelah konfirmasi buang atau simpan berhasil.
  Future<void> leave([Object? result]) async {
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    // Tunggu PopScope mengizinkan pop sebelum keluar dari route.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop:
        _leaving ||
        (!widget.busy &&
            !widget.hasChanges &&
            !widget.hasPreviousStep &&
            !_confirming),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(requestBack());
    },
    child: widget.child,
  );
}