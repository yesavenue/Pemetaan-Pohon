import 'package:flutter/material.dart';
import '../utils/branding.dart';
import '../theme/app_theme.dart';

/// Horizontal logo, with a readable fallback when the asset is unavailable.
class AppBrand extends StatelessWidget {
  final double width, height;
  const AppBrand({super.key, this.width = 220, this.height = 64});
  @override
  Widget build(BuildContext context) => Semantics(
    label: appSystemName, image: true,
    child: ExcludeSemantics(child: SizedBox(width: width, height: height,
      child: Image.asset(appLogoAsset, fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, error, stack) => const FittedBox(fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.park_outlined, size: 36, color: AppColors.leaf),
            SizedBox(width: 10),
            Text('Pemetaan Pohon\nKota Cirebon', style: TextStyle(
              color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700)),
          ]))))));
}
