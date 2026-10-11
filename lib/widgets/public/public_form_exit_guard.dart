import 'package:flutter/material.dart';

/// Guards in-app navigation. Does not persist private data or intercept reload.
class PublicFormExitScope extends InheritedWidget {
  final Future<bool> Function() confirmExit;
  final bool allowPop;
  const PublicFormExitScope({
    super.key,
    required this.confirmExit,
    required this.allowPop,
    required super.child,
  });
  static PublicFormExitScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PublicFormExitScope>();
  @override
  bool updateShouldNotify(PublicFormExitScope oldWidget) =>
      allowPop != oldWidget.allowPop || confirmExit != oldWidget.confirmExit;
}

class PublicFormExitGuard extends StatefulWidget {
  final bool hasChanges;
  final bool busy;
  final VoidCallback onRootExit;
  final Widget child;
  const PublicFormExitGuard({
    super.key,
    required this.hasChanges,
    required this.busy,
    required this.onRootExit,
    required this.child,
  });
  @override
  State<PublicFormExitGuard> createState() => _PublicFormExitGuardState();
}

class _PublicFormExitGuardState extends State<PublicFormExitGuard> {
  bool _confirming = false;
  bool _leaving = false;
  bool get _allowPop =>
      _leaving || (!widget.busy && !widget.hasChanges && !_confirming);

  Future<bool> _confirmExit() async {
    if (widget.busy || _confirming || _leaving) return false;
    if (!widget.hasChanges) return true;
    setState(() => _confirming = true);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tinggalkan permohonan?'),
        content: const Text(
          'Isian dan foto yang belum dikirim akan hilang jika Anda meninggalkan halaman ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut mengisi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tinggalkan halaman'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    setState(() => _confirming = false);
    return discard == true && !widget.busy;
  }

  Future<void> _back() async {
    if (!await _confirmExit() || !mounted) return;
    if (!Navigator.of(context).canPop()) {
      widget.onRootExit();
      return;
    }
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: PublicFormExitScope(
      confirmExit: _confirmExit,
      allowPop: _allowPop,
      child: widget.child,
    ),
  );
}