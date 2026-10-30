import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'public/public_form_exit_guard.dart';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/auth_wrapper.dart';
import '../screens/public_home_screen.dart';
import '../screens/public_map_viewer_screen.dart';
import '../screens/public_pruning_request_screen.dart';
import '../screens/public_statistik_screen.dart';
import '../screens/public_tentang_screen.dart';
import 'public/public_ui.dart';
import 'public/public_home_interactions.dart' show publicHeroProgress;
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

Future<void> navigateToPublicPage(
  BuildContext context,
  PublicPage page,
  PublicPage current,
) async {
  if (page == current) return;
  final guard = PublicFormExitScope.of(context);
  if (guard != null && !await guard.confirmExit()) return;
  if (!context.mounted) return;
  if (page == PublicPage.beranda && kIsWeb &&
      Uri.base.path.startsWith('/app/')) {
    final opened = await launchUrl(Uri.base.resolve('/'), webOnlyWindowName: '_self');
    if (opened || !context.mounted) return;
  }
  final Widget target = switch (page) {
    PublicPage.beranda => const PublicHomeScreen(),
    PublicPage.peta => const PublicMapViewerScreen(),
    PublicPage.statistik => const PublicStatistikScreen(),
    PublicPage.permohonan => const PublicPruningRequestScreen(),
    PublicPage.tentang => const PublicTentangScreen(),
  };
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute<void>(builder: (_) => target));
}

/// Beranda overlays the hero; other pages always use an opaque header.
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
  double _headerOffset = 0;
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
      _headerOffset = 0;
    }
  }

  bool _scroll(ScrollNotification n) {
    // Only the page scroll moves the header; map gestures and nested lists do not.
    if (widget.currentPage == PublicPage.peta || n.depth != 0 ||
        n.metrics.axis != Axis.vertical) {
      return false;
    }
    final next = widget.currentPage == PublicPage.beranda
        ? publicHeroProgress(n.metrics.pixels)
        : (n.metrics.pixels > 24 ? 1.0 : 0.0);
    if (next != _headerOffset) setState(() => _headerOffset = next);
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
              PublicFormExitScope.of(context)?.allowPop ??
              (widget.navigationEnabled &&
                  (widget.currentPage == PublicPage.beranda ||
                      Navigator.of(context).canPop())),
          onPopInvokedWithResult: (didPop, result) {
            if (PublicFormExitScope.of(context) != null) return;
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
                  key: const ValueKey('public-header-position'),
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    key: const ValueKey('public-header-slide'),
                    offset: Offset(0, -_headerOffset),
                    duration: widget.currentPage == PublicPage.beranda
                        ? Duration.zero : PublicUi.duration(context, 240),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(ignoring: _headerOffset > 0, child: ExcludeFocus(
                    excluding: _headerOffset > 0,
                    child: ExcludeSemantics(
                      excluding: _headerOffset > 0,
                      child: PublicNavbar(
                    currentPage: widget.currentPage,
                    glass: widget.currentPage == PublicPage.beranda,
                    extraActions: widget.extraActions,
                    enabled: widget.navigationEnabled,
                    onNavigate: (p) => _navigate(context, p),
                      ),
                    ),
                  ))),
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
      tween: Tween(begin: glass ? 1 : 0, end: glass ? 1 : 0),
      duration: PublicUi.duration(context, 200),
      curve: Curves.easeOut,
      builder: (context, t, child) => Container(
        key: ValueKey(
          glass ? 'public-header-transparent' : 'public-header-solid',
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 1 - t),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06 * (1 - t)),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: Color.lerp(
                PublicUi.border,
                Colors.white.withValues(alpha: .18),
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
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            label: 'Pemetaan Pohon Kota Cirebon',
                            image: true,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: wide ? 260 : 210),
                              child: Image.asset(
                                appLogoAsset,
                                key: const ValueKey('public-brand-logo'),
                                width: wide ? 260 : 210,
                                height: 64,
                                fit: BoxFit.contain,
                                color: glass ? Colors.white : null,
                                colorBlendMode: BlendMode.srcIn,
                                alignment: Alignment.centerLeft,
                                excludeFromSemantics: true,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, error, stack) => Text(
                                  'Pemetaan Pohon\nKota Cirebon',
                                  style: TextStyle(color: glass ? Colors.white : PublicUi.ink, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 2,
                                    color: p == currentPage
                                        ? Color.lerp(
                                            PublicUi.green,
                                            const Color(0xFFBFE2CE),
                                            t,
                                          )!
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Text(
                                _label(p),
                                style: TextStyle(
                                  color: Color.lerp(
                                    p == currentPage
                                        ? PublicUi.green
                                        : PublicUi.ink,
                                    Colors.white,
                                    t,
                                  ),
                                  fontSize: 14,
                                  fontWeight: p == currentPage
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ...extraActions,
                      IconButton(
                        key: const ValueKey('header-login'),
                        tooltip: 'Login Petugas',
                        color: glass ? Colors.white : PublicUi.green,
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
    );
  }

  Future<void> _login(BuildContext context) async {
    final guard = PublicFormExitScope.of(context);
    if (guard != null && !await guard.confirmExit()) return;
    if (!context.mounted) return;
    if (kIsWeb && Uri.base.path.startsWith('/app/')) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => const AuthWrapper(showLogin: true)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => const LoginScreen(),
    );
  }
}
