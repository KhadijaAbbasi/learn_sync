import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_sizes.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = AppSizes.logoHeight});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.22),
      child: Image.asset(
        AppAssets.logoMark,
        width: height,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}