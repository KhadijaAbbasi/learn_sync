import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnsync/services/windows_callable_client.dart';

void main() {
  test('Windows callable sends ID token and protocol envelope', () async {
    final client = WindowsCallableClient(
      projectId: 'test-project',
      idToken: () async => 'test-id-token',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://us-central1-test-project.cloudfunctions.net/generateAiPracticeQuiz',
        );
        expect(request.headers['Authorization'], 'Bearer test-id-token');
        expect(jsonDecode(request.body), {
          'data': {'topic': 'Graphs'},
        });
        return http.Response(
          jsonEncode({
            'result': {'quiz': []},
          }),
          200,
        );
      }),
    );
    expect(await client.call('generateAiPracticeQuiz', {'topic': 'Graphs'}), {
      'quiz': [],
    });
  });

  test('Windows callable preserves backend error code and details', () async {
    final client = WindowsCallableClient(
      projectId: 'test-project',
      idToken: () async => 'test-id-token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'status': 'FAILED_PRECONDITION',
              'message': 'No weak slides',
              'details': 'no-below50',
            },
          }),
          400,
        ),
      ),
    );
    await expectLater(
      client.call('generateAiPracticeQuiz', {}),
      throwsA(
        isA<FirebaseFunctionsException>()
            .having((e) => e.code, 'code', 'failed-precondition')
            .having((e) => e.details, 'details', 'no-below50'),
      ),
    );
  });

  test(
    'private Windows callable does not send a request without an ID token',
    () async {
      final client = WindowsCallableClient(
        projectId: 'test-project',
        idToken: () async => null,
        client: MockClient(
          (_) async => throw StateError('Request must not be sent'),
        ),
      );
      await expectLater(
        client.call('generateAiPracticeQuiz', {}),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
    },
  );

  test(
    'phone-password sign-in supports unauthenticated callable and no bearer header',
    () async {
      final client = WindowsCallableClient(
        projectId: 'test-project',
        idToken: () async => null,
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode({
              'result': {'token': 'custom-token'},
            }),
            200,
          );
        }),
      );
      expect(
        await client.call('signInWithPhonePassword', {
          'phone': '+920000000000',
          'password': 'test',
        }, requireAuth: false),
        {'token': 'custom-token'},
      );
    },
  );
}
