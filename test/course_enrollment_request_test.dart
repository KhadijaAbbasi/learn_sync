import 'package:flutter_test/flutter_test.dart';
import 'package:learnsync/models/lecture_join_request.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  const courseId = '5102';
  const studentId = 'student-1';

  Future<bool> hasPending(CourseEnrollmentService enrollment) {
    return enrollment.watchHasPendingForCourses([courseId]).first;
  }

  test('first join is pending and visible to the teacher', () async {
    final enrollment = CourseEnrollmentService();

    final sent = await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );

    expect(sent.isPending, isTrue);
    expect(await hasPending(enrollment), isTrue);
    final mine = await enrollment.watchMyRequest(courseId, studentId).first;
    expect(mine?.isPending, isTrue);
  });

  test('decline removes the request so the student can join again', () async {
    final enrollment = CourseEnrollmentService();
    await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );

    await enrollment.decline(
      courseId: courseId,
      teacherId: 'teacher-1',
      studentId: studentId,
    );

    expect(await enrollment.watchMyRequest(courseId, studentId).first, isNull);
    expect(await hasPending(enrollment), isFalse);
    expect(await enrollment.watchPendingForCourse(courseId).first, isEmpty);

    final again = await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );

    expect(again.isPending, isTrue);
    expect(await hasPending(enrollment), isTrue);
    final pending = await enrollment.watchPendingForCourse(courseId).first;
    expect(pending.map((request) => request.studentId), [studentId]);
  });

  test('a second join while pending does not duplicate the request', () async {
    final enrollment = CourseEnrollmentService();
    await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );
    final again = await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );

    expect(again.isPending, isTrue);
    final pending = await enrollment.watchPendingForCourse(courseId).first;
    expect(pending, hasLength(1));
  });

  test('joining again after accept fails instead of reporting success', () async {
    final enrollment = CourseEnrollmentService();
    await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );
    await enrollment.accept(
      courseId: courseId,
      teacherId: 'teacher-1',
      studentId: studentId,
    );

    expect(
      enrollment.requestJoin(
        courseId: courseId,
        courseName: 'Data Science',
        courseCode: courseId,
        studentId: studentId,
        studentName: 'Dijah',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await hasPending(enrollment), isFalse);
  });

  test('a leftover declined request can be sent again', () async {
    final enrollment = CourseEnrollmentService();
    final declined = await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );
    // Older rejects stored status=declined instead of deleting the doc.
    enrollment.debugSeedLocalRequest(
      declined.copyWith(status: JoinRequestStatus.declined),
    );
    expect(await hasPending(enrollment), isFalse);

    final again = await enrollment.requestJoin(
      courseId: courseId,
      courseName: 'Data Science',
      courseCode: courseId,
      studentId: studentId,
      studentName: 'Dijah',
    );

    expect(again.isPending, isTrue);
    expect(await hasPending(enrollment), isTrue);
  });
}
