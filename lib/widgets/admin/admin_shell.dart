import 'package:flutter/material.dart';
import '../civic_design.dart';
import '../app_brand.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import 'admin_dialog_scope.dart';

enum AdminPage { ringkasan, surveyor, pohon, permohonan }
String adminPageLabel(AdminPage page) => switch (page) {
  AdminPage.ringkasan => 'Ringkasan',
  AdminPage.surveyor => 'Surveyor',
  AdminPage.pohon => 'Data Pohon',
  AdminPage.permohonan => 'Permohonan',
};
IconData _icon(AdminPage page) => switch (page) {
  AdminPage.ringkasan => Icons.grid_view_outlined,
  AdminPage.surveyor => Icons.groups_outlined,
  AdminPage.pohon => Icons.park_outlined,
  AdminPage.permohonan => Icons.content_cut_outlined,
};

class AdminShell extends StatefulWidget {
  final AppUser user;
  final AdminPage page;
  final ValueChanged<AdminPage> onSelect;
  final VoidCallback onLogout;
  final Widget body;
  final Widget? pageAction;
  final bool enabled;
  const AdminShell({super.key, required this.user, required this.page,
    required this.onSelect, required this.onLogout, required this.body,
    this.pageAction, this.enabled = true});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _collapsed = true;
  AppUser get user => widget.user;
  AdminPage get page => widget.page;
  bool get enabled => widget.enabled;
  Widget get body => widget.body;
  Widget? get pageAction => widget.pageAction;
  VoidCallback get onLogout => widget.onLogout;
  ValueChanged<AdminPage> get onSelect => widget.onSelect;

  void _select(AdminPage value) {
    if (enabled && value != page) onSelect(value);
  }

  Widget _destination(AdminPage destination, {bool compact = false}) => Semantics(
    selected: page == destination,
    child: TextButton(
      key: ValueKey('admin-nav-${destination.name}'),
      onPressed: enabled ? () => _select(destination) : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        foregroundColor: page == destination ? AppColors.leaf : AppColors.navy,
        backgroundColor: page == destination ? AppColors.leaf.withValues(alpha: .1) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: compact
        ? Column(mainAxisSize: MainAxisSize.min, children: [Icon(_icon(destination)),
            const SizedBox(height: 4), Text(destination == AdminPage.pohon ? 'Pohon' : adminPageLabel(destination))])
        : Row(children: [Icon(_icon(destination)), const SizedBox(width: 12),
            Expanded(child: Text(adminPageLabel(destination)))])));

  Widget _iconDestination(AdminPage destination) => Semantics(
    selected: page == destination,
    child: Tooltip(message: adminPageLabel(destination),
      child: SizedBox(height: 52,
        child: TextButton(
          key: ValueKey('admin-nav-${destination.name}'),
          onPressed: enabled ? () => _select(destination) : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            foregroundColor: page == destination ? AppColors.leaf : AppColors.navy,
            backgroundColor: page == destination ? AppColors.leaf.withValues(alpha: .12) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Icon(_icon(destination), semanticLabel: adminPageLabel(destination))))));

  Future<void> _account(BuildContext context) async {
    await showOwnedAdminDialog<void>(context, builder: (context) => AlertDialog(
      title: const Text('Akun admin'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name), const SizedBox(height: 8), SelectableText(user.email),
          const SizedBox(height: 12), const Text('Peran: Admin'),
        ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))]));
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final desktop = MediaQuery.sizeOf(context).width >= 1150 * scale && scale <= 1.35;
    final header = Material(color: Colors.white, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        if (desktop) ...[
          IconButton(key: const ValueKey('admin-sidebar-toggle'),
            tooltip: _collapsed ? 'Perluas sidebar' : 'Kecilkan sidebar',
            onPressed: enabled ? () => setState(() => _collapsed = !_collapsed) : null,
            icon: Icon(_collapsed ? Icons.menu_open : Icons.menu,
              color: AppColors.navy)),
          const SizedBox(width: 12),
        ],
        Expanded(child: desktop
          ? Text(adminPageLabel(page), style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w700, color: AppColors.navy))
          : const Align(alignment: Alignment.centerLeft, child: AppBrand(width: 230, height: 64))),
        IconButton(tooltip: 'Akun admin', onPressed: enabled ? () => _account(context) : null,
          icon: const Icon(Icons.account_circle_outlined, color: AppColors.navy)),
        IconButton(tooltip: 'Keluar', onPressed: enabled ? onLogout : null,
          icon: const Icon(Icons.logout, color: AppColors.navy)),
      ])));
    final workspace = Column(children: [
      header, const Divider(height: 1),
      if (pageAction != null) ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .25),
        child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12),
          child: Align(alignment: Alignment.centerRight, child: pageAction!)))),
      Expanded(child: AbsorbPointer(absorbing: !enabled,
        child: CivicEntrance(key: ValueKey(page), child: body))),
    ]);
    return PopScope<Object?>(
      canPop: enabled && page == AdminPage.ringkasan && Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && enabled && page != AdminPage.ringkasan) _select(AdminPage.ringkasan);
      },
      child: Scaffold(backgroundColor: AppColors.background,
        body: SafeArea(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (desktop) AnimatedContainer(
            key: const ValueKey('admin-sidebar'),
            width: _collapsed ? 80 : 248,
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            color: Colors.white,
            child: LayoutBuilder(builder: (context, box) {
              // Switch labels only where there is enough room during resize.
              final iconsOnly = box.maxWidth < 220;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 12 : 16, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(height: 64, child: iconsOnly
                    ? const Tooltip(message: 'Pemetaan Pohon Kota Cirebon',
                        child: Icon(Icons.park_outlined, color: AppColors.leaf, size: 32))
                    : const AppBrand(width: 216, height: 64)),
                  const SizedBox(height: 16),
                  if (!iconsOnly) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('MENU UTAMA', style: TextStyle(fontSize: 11,
                        letterSpacing: 1.2, color: Colors.blueGrey, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 12),
                  ],
                  for (final destination in AdminPage.values) Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: iconsOnly ? _iconDestination(destination) : _destination(destination)),
                  const Divider(height: 40),
                  if (iconsOnly)
                    IconButton(tooltip: 'Akun admin',
                      onPressed: enabled ? () => _account(context) : null,
                      icon: const Icon(Icons.account_circle_outlined, color: AppColors.navy))
                  else Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                      const SizedBox(height: 6),
                      const Text('Administrator', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ])),
                ]));
            })),
          if (desktop) const VerticalDivider(width: 1),
          Expanded(child: workspace),
        ])),
        bottomNavigationBar: desktop ? null : SafeArea(top: false,
          child: Material(color: Colors.white, child: LayoutBuilder(builder: (context, box) =>
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final destination in AdminPage.values) SizedBox(
                width: (box.maxWidth / 4).clamp(96.0 * scale, double.infinity).toDouble(),
                child: _destination(destination, compact: true)),
            ]))))),
      ));
  }
}
