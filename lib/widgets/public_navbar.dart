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

String _labelFor(PublicPage page) {
  switch (page) {
    case PublicPage.beranda:
      return 'Beranda';
    case PublicPage.peta:
      return 'Peta Pohon';
    case PublicPage.statistik:
      return 'Statistik';
    case PublicPage.permohonan:
      return 'Permohonan';
    case PublicPage.tentang:
      return 'Tentang';
  }
}

void navigateToPublicPage(BuildContext context, PublicPage page, PublicPage current) {
  if (page == current) return;
  Widget target;
  switch (page) {
    case PublicPage.beranda:
      target = const PublicHomeScreen();
      break;
    case PublicPage.peta:
      target = const PublicMapViewerScreen();
      break;
    case PublicPage.statistik:
      target = const PublicStatistikScreen();
      break;
    case PublicPage.permohonan:
      target = const PublicPruningRequestScreen();
      break;
    case PublicPage.tentang:
      target = const PublicTentangScreen();
      break;
  }
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
}

/// Navbar modern yang dipakai bersama di semua halaman publik, supaya
/// tampilan & menu aktif konsisten tanpa menduplikasi kode di tiap layar.
class PublicNavbar extends StatelessWidget implements PreferredSizeWidget {
  final PublicPage currentPage;
  final List<Widget> extraActions;
  const PublicNavbar({super.key, required this.currentPage, this.extraActions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: Colors.black12, width: 1)),
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              appLogoAsset,
              width: 38,
              height: 38,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.location_city, color: AppColors.navy, size: 38),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pemetaan Pohon',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
              Text('Kota Cirebon', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
      actions: [
        if (isWide)
          ...PublicPage.values.map((p) => _NavItem(
                label: _labelFor(p),
                active: p == currentPage,
                onTap: () => navigateToPublicPage(context, p, currentPage),
              )),
        if (isWide) const SizedBox(width: 4),
        ...extraActions,
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Cari',
          onPressed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Fitur pencarian akan segera hadir.')));
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: OutlinedButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => const LoginScreen()),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Login'),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppColors.leaf : AppColors.navy,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(height: 2),
          Container(height: 2, width: 20, color: active ? AppColors.leaf : Colors.transparent),
        ],
      ),
    );
  }
}

/// Drawer pendamping untuk layar sempit (mobile web), isinya sama
/// dengan menu navbar supaya tidak ada navigasi yang beda/duplikat.
class PublicNavDrawer extends StatelessWidget {
  final PublicPage currentPage;
  const PublicNavDrawer({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.navy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    appLogoAsset,
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.location_city, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Pemetaan Pohon\nKota Cirebon',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...PublicPage.values.map((p) => ListTile(
                leading: Icon(_iconFor(p), color: p == currentPage ? AppColors.leaf : null),
                title: Text(
                  _labelFor(p),
                  style: TextStyle(
                    color: p == currentPage ? AppColors.leaf : null,
                    fontWeight: p == currentPage ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  navigateToPublicPage(context, p, currentPage);
                },
              )),
        ],
      ),
    );
  }

  IconData _iconFor(PublicPage page) {
    switch (page) {
      case PublicPage.beranda:
        return Icons.home_outlined;
      case PublicPage.peta:
        return Icons.map_outlined;
      case PublicPage.statistik:
        return Icons.bar_chart_outlined;
      case PublicPage.permohonan:
        return Icons.content_cut_outlined;
      case PublicPage.tentang:
        return Icons.info_outline;
    }
  }
}