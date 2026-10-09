import 'package:flutter/material.dart';

/// Admin-owned routes are closed when the admin subtree is removed.
class AdminDialogScope extends StatefulWidget {
  final Widget child;
  const AdminDialogScope({super.key, required this.child});
  @override
  State<AdminDialogScope> createState() => _AdminDialogScopeState();
}

class _AdminDialogScopeState extends State<AdminDialogScope> {
  final _routes = <Route<dynamic>, NavigatorState>{};
  bool get canOpen => mounted && _routes.isEmpty;
  Future<T?> open<T>(NavigatorState navigator, Route<T> route) {
    if (!canOpen) return Future.value(null);
    _routes[route] = navigator;
    try {
      return navigator.push(route).whenComplete(() => _routes.remove(route));
    } catch (_) {
      _routes.remove(route);
      rethrow;
    }
  }

  @override
  void dispose() {
    final owned = Map<Route<dynamic>, NavigatorState>.of(_routes);
    _routes.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in owned.entries) {
        if (entry.value.mounted && entry.key.isActive) {
          entry.value.removeRoute(entry.key);
        }
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AdminDialogOwner(owner: this, child: widget.child);
}

class _AdminDialogOwner extends InheritedWidget {
  final _AdminDialogScopeState owner;
  const _AdminDialogOwner({required this.owner, required super.child});
  @override
  bool updateShouldNotify(_AdminDialogOwner oldWidget) =>
      owner != oldWidget.owner;
}

bool canOpenAdminDialog(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_AdminDialogOwner>()?.owner.canOpen ??
    true;
Future<T?> showOwnedAdminDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final owner = context
      .getInheritedWidgetOfExactType<_AdminDialogOwner>()
      ?.owner;
  if (owner != null && !owner.canOpen) return Future.value(null);
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: dismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  return owner == null ? navigator.push(route) : owner.open(navigator, route);
}