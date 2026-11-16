import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../theme/app_colors.dart';

abstract final class AppResponsive {
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppSizes.desktopBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppSizes.tabletBreakpoint &&
        width < AppSizes.desktopBreakpoint;
  }

  static double pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppSizes.desktopBreakpoint) {
      return 32;
    }
    if (width >= AppSizes.tabletBreakpoint) {
      return 28;
    }
    return 20;
  }

  static double pageTitleSize(BuildContext context) {
    return isDesktop(context) ? 24 : 20;
  }

  static double sectionTitleSize(BuildContext context) {
    return isDesktop(context) ? 17 : 15.5;
  }

  static int understandingColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) {
      return 4;
    }
    if (width >= AppSizes.tabletBreakpoint) {
      return 2;
    }
    return 2;
  }

  static int actionColumns(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppSizes.tabletBreakpoint
        ? 2
        : 1;
  }

  static int progressColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) {
      return 3;
    }
    if (width >= AppSizes.tabletBreakpoint) {
      return 3;
    }
    return 1;
  }
}

abstract final class AppTextStyles {
  static TextStyle pageTitle(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontSize: AppResponsive.pageTitleSize(context),
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: AppColors.textPrimary(Theme.of(context).brightness),
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      fontSize: AppResponsive.sectionTitleSize(context),
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary(Theme.of(context).brightness),
    );
  }

  static TextStyle subtitle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: AppResponsive.isDesktop(context) ? 14 : 13,
      height: 1.4,
      color: AppColors.textSecondary(Theme.of(context).brightness),
    );
  }
}
