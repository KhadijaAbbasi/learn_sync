import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.fontSize = 16,
    this.syncColor = AppColors.teal,
    this.learnColor = Colors.white,
  });

  final double fontSize;
  final Color syncColor;
  final Color learnColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'LEARN',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              color: learnColor,
              letterSpacing: 0.2,
            ),
          ),
          TextSpan(
            text: 'sync',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: syncColor,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
