import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import 'dashboard_home_header.dart';

class StudentHomeHeader extends StatelessWidget {
  const StudentHomeHeader({
    super.key,
    required this.userName,
    required this.searchController,
    required this.onSearch,
    this.photoUrl = '',
    this.appBarActions = const [],
  });

  final String userName;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final String photoUrl;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;

    return DashboardHomeHeader(
      showMenuButton: false,
      userName: userName,
      roleLabel: l10n.student,
      photoUrl: photoUrl,
      subtitle: l10n.keepLearningAhead,
      appBarActions: appBarActions,
      overlay: DashboardOverlayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.findYourTeacher,
              style: TextStyle(
                color: AppColors.textPrimary(brightness),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            DashboardSearchField(
              controller: searchController,
              hintText: l10n.searchTeacherHint,
              onSubmitted: (_) => onSearch(),
              onSearch: onSearch,
            ),
          ],
        ),
      ),
    );
  }
}
