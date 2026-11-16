import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/session/course_store.dart';
import '../core/session/session_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/course_enrollment_service.dart';

/// Red dot shown while the signed-in teacher has pending course join requests.
class PendingJoinRequestsBadge extends StatefulWidget {
  const PendingJoinRequestsBadge({super.key, required this.child});

  final Widget child;

  static const Key dotKey = Key('pending-join-requests-dot');

  @override
  State<PendingJoinRequestsBadge> createState() =>
      _PendingJoinRequestsBadgeState();
}

class _PendingJoinRequestsBadgeState extends State<PendingJoinRequestsBadge> {
  SessionController? _session;
  CourseStore? _courses;
  CourseEnrollmentService? _enrollment;
  CourseEnrollmentService? _boundEnrollment;
  Stream<bool>? _pending;
  String _watchKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (!identical(_session, scope.sessionController)) {
      _session?.removeListener(_onScopeChanged);
      _session = scope.sessionController;
      _session!.addListener(_onScopeChanged);
    }
    if (!identical(_courses, scope.courseStore)) {
      _courses?.removeListener(_onScopeChanged);
      _courses = scope.courseStore;
      _courses!.addListener(_onScopeChanged);
    }
    _enrollment = scope.enrollment;
    _bindPendingStream(scope.enrollment);
  }

  @override
  void dispose() {
    _session?.removeListener(_onScopeChanged);
    _courses?.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onScopeChanged() {
    final enrollment = _enrollment;
    if (enrollment == null) {
      return;
    }
    final previousKey = _watchKey;
    final previousStream = _pending;
    _bindPendingStream(enrollment);
    if ((previousKey != _watchKey || !identical(previousStream, _pending)) &&
        mounted) {
      setState(() {});
    }
  }

  void _bindPendingStream(CourseEnrollmentService enrollment) {
    final session = _session;
    final courses = _courses;
    if (session == null || courses == null) {
      return;
    }
    final teacherId = session.isTeacher ? (session.user?.id ?? '') : '';
    final courseIds = <String>[
      if (teacherId.isNotEmpty)
        for (final course in courses.courses)
          if (course.id.isNotEmpty) course.id,
    ]..sort();
    final watchKey = '$teacherId|${courseIds.join('|')}';
    if (_pending != null &&
        _watchKey == watchKey &&
        identical(_boundEnrollment, enrollment)) {
      return;
    }
    _watchKey = watchKey;
    _boundEnrollment = enrollment;
    _pending = enrollment.watchHasPendingForCourses(courseIds);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _pending,
      builder: (context, snapshot) {
        final show = snapshot.data ?? false;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (show)
              const PositionedDirectional(
                top: -2,
                end: -2,
                child: IgnorePointer(
                  child: SizedBox(
                    key: PendingJoinRequestsBadge.dotKey,
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
