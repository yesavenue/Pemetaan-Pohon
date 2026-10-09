import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pemetaan_pohon/widgets/public/public_ui.dart';
import 'package:pemetaan_pohon/widgets/public_navbar.dart';

/// Account for the pinned overlay after ensureVisible changes page layout.
Future<void> revealPublicTarget(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
  final context = tester.element(finder);
  final position = Scrollable.maybeOf(context)?.position;
  final inPublicPage =
      context.findAncestorWidgetOfExactType<PublicScaffold>() != null;
  final scrollable = Scrollable.maybeOf(context);
  if (position == null || scrollable == null) {
    return;
  }
  final viewport = tester.getRect(find.byWidget(scrollable.widget));
  final headerBottom = inPublicPage
      ? PublicUi.headerHeight(context) + MediaQuery.paddingOf(context).top
      : 0.0;
  final topLimit = viewport.top > headerBottom ? viewport.top : headerBottom;
  var bottomLimit = viewport.bottom;
  final navigation = find.byKey(const ValueKey('public-bottom-navigation'));
  if (inPublicPage && navigation.evaluate().length == 1) {
    final navigationTop = tester.getRect(navigation).top;
    if (navigationTop < bottomLimit) {
      bottomLimit = navigationTop;
    }
  }
  final target = tester.getRect(finder);
  // A large card may be taller than its viewport; only its tappable centre
  // needs to be visible. Small buttons also get room above the pinned header.
  final centre = target.center.dy;
  final delta = centre < topLimit + 16
      ? centre - (topLimit + 16)
      : centre > bottomLimit - 16
      ? centre - (bottomLimit - 16)
      : 0.0;
  if (delta != 0) {
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
}