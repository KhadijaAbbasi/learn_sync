import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/course_content.dart';
import '../../widgets/topic_slides_viewer.dart';

/// Full-screen in-app viewer for chapter/topic attachments (PDF, PPT, DOC, …).
class CourseFileViewerScreen extends StatelessWidget {
  const CourseFileViewerScreen({
    super.key,
    required this.attachments,
    required this.courseId,
    this.initialIndex = 0,
    this.title,
  });

  final List<CourseAttachment> attachments;
  final String courseId;
  final int initialIndex;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final safeIndex = attachments.isEmpty
        ? 0
        : initialIndex.clamp(0, attachments.length - 1);
    final heading =
        title ?? (attachments.isEmpty ? 'File' : attachments[safeIndex].name);

    // Reorder so TopicSlidesViewer starts on the tapped file.
    final ordered = <CourseAttachment>[
      if (attachments.isNotEmpty) attachments[safeIndex],
      for (var i = 0; i < attachments.length; i++)
        if (i != safeIndex) attachments[i],
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        title: Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ordered.isEmpty
                    ? const Center(child: Text('No file'))
                    : TopicSlidesViewer(
                        attachments: ordered,
                        courseId: courseId,
                        title: heading,
                        isPresenter: true,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
