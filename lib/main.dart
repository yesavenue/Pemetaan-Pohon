import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'theme/app_theme.dart';
import 'utils/app_mode.dart';
import 'utils/public_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: isSurveyorApp
          ? 'Surveyor Pohon Cirebon'
          : 'Pemetaan Pohon Kota Cirebon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Resolve only the explicitly supported public entry links. The role gate
      // remains inside AuthWrapper; URL values never grant admin access.
      onGenerateInitialRoutes: (_) => [MaterialPageRoute<void>(
        builder: (_) => isSurveyorApp
            ? const AuthWrapper() : publicEntry(Uri.base),
      )],
    );
  }
}