import 'package:flutter/material.dart';
import '../civic_design.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../utils/branding.dart';
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

/// Presentasi navigasi admin; autentikasi tetap milik AuthWrapper/service.
class AdminShell extends StatelessWidget {
  final AppUser user;
  final AdminPage page;
  final ValueChanged<AdminPage> onSelect;
  final VoidCallback onLogout;
  final Widget body;
  final Widget? pageAction;
  final bool enabled;
  const AdminShell({
    super.key,
    required this.user,
    required this.page,
    required this.onSelect,
    required this.onLogout,
    required this.body,
    this.pageAction,
    this.enabled = true,
  });

  void _select(AdminPage value) {
    if (enabled && value != page) onSelect(value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final desktop =
        MediaQuery.sizeOf(context).width >= 1150 * scale && scale <= 1.35;
    return PopScope<Object?>(
      canPop:
          enabled &&
          page == AdminPage.ringkasan &&
          Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && enabled && page != AdminPage.ringkasan) {
          _select(AdminPage.ringkasan);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        appLogoAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, error, stack) => const Icon(
                          Icons.park,
                          color: AppColors.leaf,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pemetaan Pohon',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Admin • Kota Cirebon',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (desktop) ...[
                        for (final destination in AdminPage.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Semantics(
                              selected: page == destination,
                              child: TextButton(
                                key: ValueKey('admin-nav-${destination.name}'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  foregroundColor: page == destination
                                      ? AppColors.leaf
                                      : AppColors.navy,
                                  backgroundColor: page == destination
                                      ? AppColors.leaf.withValues(alpha: .1)
                                      : null,
                                ),
                                onPressed: enabled
                                    ? () => _select(destination)
                                    : null,
                                child: Text(adminPageLabel(destination)),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        tooltip: 'Akun admin',
                        onPressed: enabled
                            ? () => showOwnedAdminDialog<void>(
                                context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Akun admin'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(user.name),
                                        const SizedBox(height: 8),
                                        SelectableText(user.email),
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
                              )
                            : null,
                        icon: const Icon(
                          Icons.account_circle_outlined,
                          color: AppColors.navy,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Keluar',
                        onPressed: enabled ? onLogout : null,
                        icon: const Icon(Icons.logout, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (pageAction != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: pageAction!,
                  ),
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: !enabled,
                  child: CivicEntrance(key: ValueKey(page), child: body),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: desktop
            ? null
            : SafeArea(
                top: false,
                child: Material(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final destination in AdminPage.values)
                            SizedBox(
                              width: (constraints.maxWidth / 4)
                                  .clamp(80.0 * scale, double.infinity)
                                  .toDouble(),
                              child: Semantics(
                                selected: page == destination,
                                child: TextButton(
                                  key: ValueKey(
                                    'admin-nav-${destination.name}',
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 64),
                                    foregroundColor: page == destination
                                        ? AppColors.leaf
                                        : AppColors.navy,
                                    backgroundColor: page == destination
                                        ? AppColors.leaf.withValues(alpha: .1)
                                        : null,
                                  ),
                                  onPressed: enabled
                                      ? () => _select(destination)
                                      : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_icon(destination)),
                                      const SizedBox(height: 4),
                                      Text(
                                        destination == AdminPage.pohon
                                            ? 'Pohon'
                                            : adminPageLabel(destination),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}