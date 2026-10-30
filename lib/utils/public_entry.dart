import 'package:flutter/material.dart';
import '../screens/auth_wrapper.dart';
import '../screens/public_home_screen.dart';
import '../screens/public_map_viewer_screen.dart';
import '../screens/public_pruning_request_screen.dart';
import '../screens/public_statistik_screen.dart';
import '../screens/public_tentang_screen.dart';
import '../screens/public_tracking_screen.dart';

/// Public links use fragments, so tracking codes are not sent to the web host.
/// Unknown links fall back to the normal authenticated entry, never an admin page.
Widget publicEntry(Uri location) {
  Uri route;
  try {
    route = Uri.parse(location.fragment);
  } on FormatException {
    return const AuthWrapper();
  }
  return switch (route.path) {
    '/peta' => PublicMapViewerScreen(initialTreeId: route.queryParameters['tree']),
    '/permohonan' => const PublicPruningRequestScreen(),
    '/statistik' => const PublicStatistikScreen(),
    '/tentang' => const PublicTentangScreen(),
    '/beranda' => const PublicHomeScreen(),
    '/lacak' => PublicTrackingScreen(initialCode: route.queryParameters['code']),
    '/login' => const AuthWrapper(showLogin: true),
    _ => const AuthWrapper(),
  };
}
