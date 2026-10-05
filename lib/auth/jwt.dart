import 'dart:convert';

Map<String, dynamic>? parseJwtPayload(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

int getTokenExpiry(String? token) {
  final payload = parseJwtPayload(token);
  final exp = payload?['exp'];
  if (exp is! num) return 0;
  return (exp * 1000).toInt();
}

const int kProactiveSkewMs = 5 * 60 * 1000;

bool isTokenExpired(String? token, {int skewMs = kProactiveSkewMs}) {
  final exp = getTokenExpiry(token);
  if (exp == 0) return true;
  return DateTime.now().millisecondsSinceEpoch >= exp - skewMs;
}

List<String> getCognitoGroups(String? idToken) {
  final payload = parseJwtPayload(idToken);
  final groups = payload?['cognito:groups'];
  if (groups is List) {
    return groups.map((g) => g.toString()).toList();
  }
  return const [];
}

String displayNameFromIdToken(String idToken) {
  final payload = parseJwtPayload(idToken) ?? const {};
  final name = (payload['name'] ?? payload['given_name'] ?? payload['email'] ?? '').toString().trim();
  return name.isEmpty ? 'Staff' : name;
}
