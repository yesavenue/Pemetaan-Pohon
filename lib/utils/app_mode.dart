import 'package:flutter/foundation.dart';

/// Native builds open the surveyor app; the normal web build stays public.
/// Chrome preview: --dart-define=SURVEYOR_APP=true.
const bool isSurveyorApp = bool.fromEnvironment(
  'SURVEYOR_APP',
  defaultValue: !kIsWeb,
);