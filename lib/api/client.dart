import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_store.dart';
import '../auth/errors.dart';
import 'config.dart';

Future<dynamic> apiRequest(
  String path, {
  String method = 'GET',
  Object? body,
  bool auth = true,
}) async {
  return _apiRequestInner(path, method: method, body: body, auth: auth, isRetry: false);
}

Future<dynamic> _apiRequestInner(
  String path, {
  required String method,
  required Object? body,
  required bool auth,
  required bool isRetry,
}) async {
  final headers = <String, String>{'Accept': 'application/json'};
  if (body != null) headers['Content-Type'] = 'application/json';

  if (auth) {
    final idToken = await AuthStore.instance.ensureIdToken();
    headers['Authorization'] = 'Bearer $idToken';
  }

  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final url = Uri.parse('${ApiConfig.baseUrl}$normalizedPath');
  final encodedBody = body == null ? null : jsonEncode(body);

  http.Response response;
  try {
    switch (method) {
      case 'POST':
        response = await http.post(url, headers: headers, body: encodedBody);
      case 'PUT':
        response = await http.put(url, headers: headers, body: encodedBody);
      case 'PATCH':
        response = await http.patch(url, headers: headers, body: encodedBody);
      case 'DELETE':
        response = await http.delete(url, headers: headers, body: encodedBody);
      default:
        response = await http.get(url, headers: headers);
    }
  } catch (_) {
    throw const AuthException(
      'Unable to reach BHIMA services. Check your connection.',
      code: 'NetworkError',
    );
  }

  if (response.statusCode == 401 && auth && !isRetry) {
    await AuthStore.instance.ensureIdToken(force: true);
    return _apiRequestInner(path, method: method, body: body, auth: auth, isRetry: true);
  }

  dynamic data;
  if (response.body.isNotEmpty) {
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw messageFromApiError(data is Map<String, dynamic> ? data : null, response.statusCode);
  }

  return data;
}
