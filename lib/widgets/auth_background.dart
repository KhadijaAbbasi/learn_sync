import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final topHeight = (size.height * 0.22).clamp(140.0, 210.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.background(brightness)),
        CustomPaint(
          painter: _DotGridPainter(color: AppColors.border(brightness)),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ClipPath(
            clipper: const _TopWaveClipper(),
            child: SizedBox(
              height: topHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF05101C), AppColors.navyDark]
                        : const [AppColors.navy, AppColors.navyDark],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: ClipPath(
            clipper: const _BottomWaveClipper(),
            child: SizedBox(
              height: 150,
              width: size.width * 0.62,
              child: ColoredBox(
                color: AppColors.teal.withValues(alpha: isDark ? 0.22 : 0.16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopWaveClipper extends CustomClipper<Path> {
  const _TopWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BottomWaveClipper extends CustomClipper<Path> {
  const _BottomWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.05,
        size.width,
        size.height,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.7);
    const spacing = 18.0;
    const radius = 1.1;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        final inTopCorner = x < 90 && y < 90;
        final inBottomCorner = x > size.width - 110 && y > size.height - 140;
        if (inTopCorner || inBottomCorner) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
