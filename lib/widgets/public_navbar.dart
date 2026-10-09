import 'dart:ui';

import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/public_home_screen.dart';
import '../screens/public_map_viewer_screen.dart';
import '../screens/public_pruning_request_screen.dart';
import '../screens/public_statistik_screen.dart';
import '../screens/public_tentang_screen.dart';
import 'public/public_ui.dart';
import '../utils/branding.dart';

enum PublicPage { beranda, peta, statistik, permohonan, tentang }

String _label(PublicPage page) => switch (page) {
  PublicPage.beranda => 'Beranda',
  PublicPage.peta => 'Peta Pohon',
  PublicPage.statistik => 'Statistik',
  PublicPage.permohonan => 'Permohonan',
  PublicPage.tentang => 'Tentang',
};
IconData _icon(PublicPage page, {bool active = false}) => switch (page) {
  PublicPage.beranda => active ? Icons.home_rounded : Icons.home_outlined,
  PublicPage.peta => active ? Icons.map_rounded : Icons.map_outlined,
  PublicPage.statistik =>
    active ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
  PublicPage.permohonan =>
    active ? Icons.description_rounded : Icons.description_outlined,
  PublicPage.tentang => active ? Icons.info_rounded : Icons.info_outline,
};
bool _wide(BuildContext context) =>
    PublicUi.desktop(context, MediaQuery.sizeOf(context).width);

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

/// A pinned header overlays the main scroll, exposing content through glass.
class PublicScaffold extends StatefulWidget {
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
  @override
  State<PublicScaffold> createState() => _PublicScaffoldState();
}

class _PublicScaffoldState extends State<PublicScaffold> {
  bool _glass = false;
  void _navigate(BuildContext context, PublicPage page) {
    if (!widget.navigationEnabled || page == widget.currentPage) return;
    if (widget.onNavigate != null) {
      widget.onNavigate!(page);
    } else {
      navigateToPublicPage(context, page, widget.currentPage);
    }
  }

  @override
  void didUpdateWidget(covariant PublicScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage ||
        oldWidget.body.runtimeType != widget.body.runtimeType) {
      // Form → success (and Ajukan lagi) mounts a fresh scroll at offset zero.
      _glass = false;
    }
  }

  bool _scroll(ScrollNotification n) {
    if (widget.currentPage == PublicPage.peta ||
        n.depth != 0 ||
        n.metrics.axis != Axis.vertical) {
      return false;
    }
    final next = n.metrics.pixels >= 32
        ? true
        : n.metrics.pixels <= 8
        ? false
        : _glass;
    if (next != _glass) setState(() => _glass = next);
    return false;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PublicUi.theme(context),
    child: Builder(
      builder: (context) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
        return PopScope<Object?>(
          canPop:
              widget.navigationEnabled &&
              (widget.currentPage == PublicPage.beranda ||
                  Navigator.of(context).canPop()),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop &&
                widget.navigationEnabled &&
                widget.currentPage != PublicPage.beranda) {
              _navigate(context, PublicPage.beranda);
            }
          },
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _scroll,
                    child: widget.currentPage == PublicPage.peta
                        ? Padding(
                            padding: EdgeInsets.only(
                              top:
                                  PublicUi.headerHeight(context) +
                                  MediaQuery.paddingOf(context).top,
                            ),
                            child: widget.body,
                          )
                        : widget.body,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PublicNavbar(
                    currentPage: widget.currentPage,
                    glass: _glass,
                    extraActions: widget.extraActions,
                    enabled: widget.navigationEnabled,
                    onNavigate: (p) => _navigate(context, p),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _wide(context)
                ? null
                : AbsorbPointer(
                    absorbing: !widget.navigationEnabled,
                    child: largeText
                        ? Material(
                            color: Colors.white,
                            child: SafeArea(
                              top: false,
                              child: SingleChildScrollView(
                                key: const ValueKey('public-bottom-navigation'),
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final p in PublicPage.values)
                                      SizedBox(
                                        width: 144,
                                        child: TextButton(
                                          onPressed: widget.navigationEnabled
                                              ? () => _navigate(context, p)
                                              : null,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _icon(p),
                                                color: p == widget.currentPage
                                                    ? PublicUi.green
                                                    : PublicUi.muted,
                                              ),
                                              Text(
                                                _shortLabel(p),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      p == widget.currentPage
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : NavigationBar(
                            key: const ValueKey('public-bottom-navigation'),
                            height: 72,
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            indicatorColor: PublicUi.mint,
                            selectedIndex: widget.currentPage.index,
                            onDestinationSelected: (i) =>
                                _navigate(context, PublicPage.values[i]),
                            destinations: [
                              for (final p in PublicPage.values)
                                NavigationDestination(
                                  icon: Icon(_icon(p)),
                                  selectedIcon: Icon(
                                    _icon(p, active: true),
                                    color: PublicUi.green,
                                  ),
                                  label: _shortLabel(p),
                                ),
                            ],
                          ),
                  ),
          ),
        );
      },
    ),
  );
}

String _shortLabel(PublicPage p) => switch (p) {
  PublicPage.peta => 'Peta',
  PublicPage.permohonan => 'Ajukan',
  _ => _label(p),
};

class PublicNavbar extends StatelessWidget implements PreferredSizeWidget {
  final PublicPage currentPage;
  final List<Widget> extraActions;
  final bool enabled;
  final bool glass;
  final ValueChanged<PublicPage>? onNavigate;
  const PublicNavbar({
    super.key,
    required this.currentPage,
    this.extraActions = const [],
    this.enabled = true,
    this.glass = false,
    this.onNavigate,
  });
  @override
  Size get preferredSize => const Size.fromHeight(76);
  @override
  Widget build(BuildContext context) {
    final wide = _wide(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: glass ? 1 : 0),
      duration: PublicUi.duration(context, 200),
      curve: Curves.easeOut,
      builder: (context, t, child) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
          child: Container(
            key: ValueKey(
              glass ? 'public-header-glass' : 'public-header-solid',
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 1 - .28 * t),
              border: Border(
                bottom: BorderSide(
                  color: Color.lerp(
                    PublicUi.border,
                    Colors.white.withValues(alpha: .45),
                    t,
                  )!,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: PublicUi.headerHeight(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1264),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 12),
                      child: Row(
                        children: [
                          Image.asset(
                            appLogoAsset,
                            width: wide ? 40 : 32,
                            height: wide ? 40 : 32,
                            errorBuilder: (_, error, stack) =>
                                const Icon(Icons.park, color: PublicUi.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Pemetaan Pohon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PublicUi.brandTitleStyle,
                                ),
                                Text(
                                  'Kota Cirebon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PublicUi.brandSubtitleStyle,
                                ),
                              ],
                            ),
                          ),
                          if (wide)
                            for (final p in PublicPage.values)
                              TextButton(
                                onPressed: !enabled
                                    ? null
                                    : () => onNavigate != null
                                          ? onNavigate!(p)
                                          : navigateToPublicPage(
                                              context,
                                              p,
                                              currentPage,
                                            ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 2,
                                        color: p == currentPage
                                            ? PublicUi.green
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _label(p),
                                    style: TextStyle(
                                      color: p == currentPage
                                          ? PublicUi.green
                                          : PublicUi.ink,
                                      fontSize: 14,
                                      fontWeight: p == currentPage
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ...extraActions,
                          if (wide)
                            OutlinedButton.icon(
                              onPressed: enabled ? () => _login(context) : null,
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('Login Petugas'),
                            )
                          else
                            IconButton(
                              tooltip: 'Login Petugas',
                              onPressed: enabled ? () => _login(context) : null,
                              icon: const Icon(Icons.login),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _login(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const LoginScreen());
}