import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl = '',
    this.radius = 28,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first));
    final letters = parts.join();
    return letters.isEmpty ? 'L' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFFD7F3F2);
    final fg = foregroundColor ?? AppColors.tealDark;
    final initials = Text(
      _initials,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: radius * 0.62,
        color: fg,
      ),
    );

    if (photoUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: initials,
      );
    }

    return FutureBuilder<List<int>?>(
      future: AppScope.of(context).authService.loadAvatarBytes(photoUrl),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: bg,
            child: initials,
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
        );
      },
    );
  }
}
