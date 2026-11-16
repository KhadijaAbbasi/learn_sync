import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';

class CircularLogo extends StatelessWidget {
  const CircularLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Transform.scale(
          scale: 1.18,
          child: Image.asset(
            AppAssets.logoMark,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
