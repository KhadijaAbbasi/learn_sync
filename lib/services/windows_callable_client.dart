import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// Firebase's callable HTTP protocol for Windows, where cloud_functions has
/// no native plugin. Uses the same authenticated backend as the mobile app.
class WindowsCallableClient {
  WindowsCallableClient({
    required this.projectId,
    required this.idToken,
    this.region = 'us-central1',
    this.client,
  });

  final String projectId;
  final String region;
  final Future<String?> Function() idToken;
  final http.Client? client;

  Future<Object?> call(
    String name,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    final token = await idToken();
    if (requireAuth && (token == null || token.isEmpty)) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in to continue.',
      );
    }
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .post(
            Uri.https('$region-$projectId.cloudfunctions.net', '/$name'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 120));
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        throw const FormatException('Invalid callable response');
      }
      final error = payload['error'];
      if (error is Map) {
        throw FirebaseFunctionsException(
          code: (error['status'] as String? ?? 'INTERNAL')
              .toLowerCase()
              .replaceAll('_', '-'),
          message: error['message'] as String? ?? 'The request failed.',
          details: error['details'],
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (!payload.containsKey('result') && !payload.containsKey('data'))) {
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'The request failed.',
        );
      }
      return payload.containsKey('result')
          ? payload['result']
          : payload['data'];
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
