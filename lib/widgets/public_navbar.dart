import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/public_home_screen.dart';
import '../screens/public_map_viewer_screen.dart';
import '../screens/public_pruning_request_screen.dart';
import '../screens/public_statistik_screen.dart';
import '../screens/public_tentang_screen.dart';
import '../theme/app_theme.dart';
import '../utils/branding.dart';

enum PublicPage { beranda, peta, statistik, permohonan, tentang }

String _label(PublicPage page) => switch (page) {
  PublicPage.beranda => 'Beranda',
  PublicPage.peta => 'Peta Pohon',
  PublicPage.statistik => 'Statistik',
  PublicPage.permohonan => 'Permohonan',
  PublicPage.tentang => 'Tentang',
};
IconData _icon(PublicPage page) => switch (page) {
  PublicPage.beranda => Icons.home_outlined,
  PublicPage.peta => Icons.map_outlined,
  PublicPage.statistik => Icons.bar_chart_outlined,
  PublicPage.permohonan => Icons.description_outlined,
  PublicPage.tentang => Icons.info_outline,
};
bool _wide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >=
        1024 * (MediaQuery.textScalerOf(context).scale(14) / 14) &&
    MediaQuery.textScalerOf(context).scale(14) <= 19;

void navigateToPublicPage(
  BuildContext context,
  PublicPage page,
  PublicPage current,
) {
  if (page == current) return;
  final Widget target = switch (page) {
    PublicPage.beranda => const PublicHomeScreen(),
    PublicPage.peta => const PublicMapViewerScreen(),
    PublicPage.statistik => const PublicStatistikScreen(),
    PublicPage.permohonan => const PublicPruningRequestScreen(),
    PublicPage.tentang => const PublicTentangScreen(),
  };
  Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute<void>(builder: (_) => target));
}

/// Shared navigation for all public pages; no duplicate drawer.
class PublicScaffold extends StatelessWidget {
  final PublicPage currentPage;
  final Widget body;
  final List<Widget> extraActions;
  final bool navigationEnabled;
  final ValueChanged<PublicPage>? onNavigate;
  const PublicScaffold({
    super.key,
    required this.currentPage,
    required this.body,
    this.extraActions = const [],
    this.navigationEnabled = true,
    this.onNavigate,
  });

  void _navigate(BuildContext context, PublicPage page) {
    if (!navigationEnabled || page == currentPage) return;
    if (onNavigate != null) {
      onNavigate!(page);
    } else {
      navigateToPublicPage(context, page, currentPage);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop:
        navigationEnabled &&
        (currentPage == PublicPage.beranda || Navigator.of(context).canPop()),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && navigationEnabled && currentPage != PublicPage.beranda) {
        _navigate(context, PublicPage.beranda);
      }
    },
    child: Scaffold(
      appBar: PublicNavbar(
        currentPage: currentPage,
        extraActions: extraActions,
        enabled: navigationEnabled,
        onNavigate: (p) => _navigate(context, p),
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: _wide(context)
          ? null
          : AbsorbPointer(
              absorbing: !navigationEnabled,
              child: NavigationBar(
                backgroundColor: Colors.white,
                indicatorColor: AppColors.leaf.withValues(alpha: .12),
                selectedIndex: currentPage.index,
                onDestinationSelected: (i) =>
                    _navigate(context, PublicPage.values[i]),
                destinations: [
                  for (final p in PublicPage.values)
                    NavigationDestination(
                      icon: Icon(_icon(p)),
                      label: switch (p) {
                        PublicPage.peta => 'Peta',
                        PublicPage.permohonan => 'Ajukan',
                        _ => _label(p),
                      },
                    ),
                ],
              ),
            ),
    ),
  );
}

class PublicNavbar extends StatelessWidget implements PreferredSizeWidget {
  final PublicPage currentPage;
  final List<Widget> extraActions;
  final bool enabled;
  final ValueChanged<PublicPage>? onNavigate;
  const PublicNavbar({
    super.key,
    required this.currentPage,
    this.extraActions = const [],
    this.enabled = true,
    this.onNavigate,
  });
  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final wide = _wide(context);
    return AppBar(
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 12,
      shape: const Border(bottom: BorderSide(color: Colors.black12)),
      title: Row(
        children: [
          Image.asset(
            appLogoAsset,
            width: 32,
            height: 32,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.park, color: AppColors.leaf, size: 32),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pemetaan Pohon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Kota Cirebon',
                  maxLines: 1,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (wide)
          for (final p in PublicPage.values)
            TextButton(
              onPressed: !enabled
                  ? null
                  : () {
                      if (onNavigate != null) {
                        onNavigate!(p);
                      } else {
                        navigateToPublicPage(context, p, currentPage);
                      }
                    },
              child: AnimatedContainer(
                duration: Duration(
                  milliseconds: MediaQuery.of(context).disableAnimations
                      ? 0
                      : 150,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: p == currentPage
                          ? AppColors.leaf
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  _label(p),
                  style: TextStyle(
                    color: p == currentPage ? AppColors.leaf : AppColors.navy,
                    fontWeight: p == currentPage
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ...extraActions,
        if (wide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: enabled ? () => _login(context) : null,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Login Petugas'),
            ),
          )
        else
          IconButton(
            tooltip: 'Login Petugas',
            onPressed: enabled ? () => _login(context) : null,
            icon: const Icon(Icons.login),
          ),
      ],
    );
  }

  void _login(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const LoginScreen());
}