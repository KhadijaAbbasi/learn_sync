import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import '../models/course_content.dart';
import '../screens/common/course_file_viewer_screen.dart';
import '../services/download_course_file.dart';
import '../services/load_course_file.dart';
import '../services/open_course_file.dart';

class CourseLinkChip extends StatefulWidget {
  const CourseLinkChip({
    super.key,
    required this.label,
    required this.url,
    this.icon = Icons.insert_drive_file_outlined,
    this.courseId = '',
    this.siblings,
    this.siblingIndex = 0,
  });

  final String label;
  final String url;
  final IconData icon;
  final String courseId;
  final List<CourseAttachment>? siblings;
  final int siblingIndex;

  @override
  State<CourseLinkChip> createState() => _CourseLinkChipState();
}

class _CourseLinkChipState extends State<CourseLinkChip> {
  var _busy = false;

  bool get _hasUrl => widget.url.trim().isNotEmpty;

  bool _shouldOpenInApp(String nameOrUrl) {
    final key = nameOrUrl.trim();
    if (key.startsWith('firestore://')) {
      return true;
    }
    if (widget.courseId.trim().isNotEmpty) {
      return true;
    }
    return isCoursePdf(key) ||
        isCoursePpt(key) ||
        isCourseOfficeDoc(key) ||
        isCourseImage(key);
  }

  Future<void> _open() async {
    if (!_hasUrl || _busy) {
      return;
    }
    final keyName = widget.label.isNotEmpty ? widget.label : widget.url;
    if (_shouldOpenInApp(keyName) || _shouldOpenInApp(widget.url)) {
      final list = widget.siblings != null && widget.siblings!.isNotEmpty
          ? List<CourseAttachment>.from(widget.siblings!)
          : [CourseAttachment(name: widget.label, url: widget.url)];
      final index = widget.siblingIndex.clamp(0, list.length - 1);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CourseFileViewerScreen(
            attachments: list,
            courseId: widget.courseId,
            initialIndex: index,
            title: widget.label,
          ),
        ),
      );
      return;
    }
    try {
      await openCourseFile(widget.url);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  Future<void> _download() async {
    if (!_hasUrl || _busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final savedPath = await downloadCourseFile(
        url: widget.url,
        fileName: widget.label,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? l10n.fileDownloadStarted(savedPath)
                : l10n.fileDownloadSaved(savedPath),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fileDownloadFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : const Color(0xFFF3F5F8),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
            if (_hasUrl) ...[
              IconButton(
                tooltip: l10n.openFile,
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : _open,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                color: AppColors.navy,
              ),
              IconButton(
                tooltip: l10n.downloadFile,
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : _download,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                color: AppColors.navy,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
