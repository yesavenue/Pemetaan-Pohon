import 'package:flutter/material.dart';

abstract final class PublicUi {
  static const ink = Color(0xFF0B3554);
  static const muted = Color(0xFF546A77);
  static const green = Color(0xFF2E7D5B);
  static const mint = Color(0xFFE9F3ED);
  static const page = Color(0xFFF7F9F8);
  static const border = Color(0xFFDCE5E0);
  static bool desktop(BuildContext context, double width) =>
      width >= 1100 && MediaQuery.textScalerOf(context).scale(14) <= 18.2;
  static Duration duration(BuildContext context, int ms) =>
      Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : ms);
  static const brandTitleStyle = TextStyle(
    inherit: false,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: ink,
  );
  static const brandSubtitleStyle = TextStyle(
    inherit: false,
    fontSize: 12,
    height: 1.3,
    color: muted,
  );

  // Measure the same two single-line styles used by the navbar. A body theme's
  // line height must not change the brand's layout, including at 200% text.
  static double headerHeight(BuildContext context) {
    double lineHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final contentHeight =
        lineHeight('Pemetaan Pohon', brandTitleStyle) +
        lineHeight('Kota Cirebon', brandSubtitleStyle) +
        24;
    final minimum = MediaQuery.sizeOf(context).width >= 1100 ? 76.0 : 64.0;
    return contentHeight > minimum ? contentHeight : minimum;
  }

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: border),
    );
    final button = ButtonStyle(
      animationDuration: duration(context, 140),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: page,
      colorScheme: base.colorScheme.copyWith(
        primary: green,
        onPrimary: Colors.white,
        secondary: ink,
        surface: Colors.white,
        onSurface: ink,
        outline: border,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.55,
              color: ink,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.55,
              color: ink,
            ),
          ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: ink, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

/// Main page scroll only: nested sheets/lists never drive the glass header.
class PublicPageScroll extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets padding;
  const PublicPageScroll({
    super.key,
    required this.children,
    this.controller,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('public-page-scroll'),
    controller: controller,
    padding: padding.add(
      EdgeInsets.only(
        top: PublicUi.headerHeight(context) + MediaQuery.paddingOf(context).top,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class PublicContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PublicContainer({super.key, required this.child, this.maxWidth = 1200});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width >= 1100
          ? 32
          : MediaQuery.sizeOf(context).width >= 600
          ? 24
          : 16,
      vertical: 24,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

class PublicPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final bool floating;
  const PublicPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    this.floating = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PublicUi.border),
      boxShadow: [
        BoxShadow(
          color: PublicUi.ink.withValues(alpha: floating ? .16 : .06),
          blurRadius: floating ? 32 : 24,
          offset: Offset(0, floating ? 12 : 8),
        ),
      ],
    ),
    child: child,
  );
}

/// Reveals once when the section enters the page viewport.
class PublicReveal extends StatefulWidget {
  final Widget child;
  final int milliseconds;
  const PublicReveal({super.key, required this.child, this.milliseconds = 240});
  @override
  State<PublicReveal> createState() => _PublicRevealState();
}

class _PublicRevealState extends State<PublicReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;
  ScrollPosition? _scrollPosition;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != position) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = position;
      _scrollPosition?.addListener(_onScroll);
    }
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  void _onScroll() {
    // Scroll offsets change before the next layout has positioned the section.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || _started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    if (_scrollPosition == null ||
        (top < MediaQuery.sizeOf(context).height && bottom > 0)) {
      _started = true;
      _controller.duration = PublicUi.duration(context, widget.milliseconds);
      _controller.forward();
      _scrollPosition?.removeListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final t = Curves.easeOut.transform(_controller.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}