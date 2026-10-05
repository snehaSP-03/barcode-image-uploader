import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'pin_password.dart';

const String _kTargetPrefix = 'AWSCognitoIdentityProviderService.';

Uri _cognitoEndpoint() =>
    Uri.parse('https://cognito-idp.${AuthConfig.cognitoRegion}.amazonaws.com/');

class CognitoTokens {
  const CognitoTokens({
    required this.idToken,
    this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.tokenType,
  });

  final String idToken;
  final String? accessToken;
  final String refreshToken;
  final int? expiresIn;
  final String? tokenType;
}

Future<Map<String, dynamic>> _cognitoCall(String action, Map<String, dynamic> body) async {
  http.Response response;
  try {
    response = await http.post(
      _cognitoEndpoint(),
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': '$_kTargetPrefix$action',
      },
      body: jsonEncode(body),
    );
  } catch (_) {
    throw const AuthException(
      'Unable to reach the sign-in service. Check your connection.',
      code: 'NetworkError',
    );
  }

  Map<String, dynamic> data = const {};
  if (response.body.isNotEmpty) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final type = (data['__type'] as String?)?.split('#').last;
    throw messageFromCognitoError(code: type, rawMessage: data['message'] as String?);
  }

  return data;
}

void _assertPin(String pin) {
  if (!isValidPin(pin)) {
    throw const AuthException('PIN must be exactly 4 digits.');
  }
}

Future<CognitoTokens> signIn({required String identifier, required String pin}) async {
  _assertPin(pin);
  final username = normalizeLoginIdentifier(identifier).username;
  final password = pinToCognitoPassword(pin);

  final data = await _cognitoCall('InitiateAuth', {
    'AuthFlow': 'USER_PASSWORD_AUTH',
    'ClientId': AuthConfig.cognitoClientId,
    'AuthParameters': {'USERNAME': username, 'PASSWORD': password},
  });

  final result = data['AuthenticationResult'] as Map<String, dynamic>?;
  if (result == null || result['IdToken'] == null) {
    throw const AuthException('Sign-in did not return tokens. Please try again.', code: 'MissingTokens');
  }

  return CognitoTokens(
    idToken: result['IdToken'] as String,
    accessToken: result['AccessToken'] as String?,
    refreshToken: result['RefreshToken'] as String,
    expiresIn: result['ExpiresIn'] as int?,
    tokenType: result['TokenType'] as String?,
  );
}

Future<CognitoTokens> refreshTokens(String? refreshToken) async {
  if (refreshToken == null || refreshToken.isEmpty) {
    throw const AuthException('Missing refresh token.');
  }

  Map<String, dynamic> data;
  try {
    data = await _cognitoCall('InitiateAuth', {
      'AuthFlow': 'REFRESH_TOKEN_AUTH',
      'ClientId': AuthConfig.cognitoClientId,
      'AuthParameters': {'REFRESH_TOKEN': refreshToken},
    });
  } catch (err) {
    if (err is AuthException &&
        (err.message.toLowerCase().contains('refresh token rotation') ||
            err.message.toLowerCase().contains('gettokensfromrefreshtoken'))) {
      data = await _cognitoCall('GetTokensFromRefreshToken', {
        'RefreshToken': refreshToken,
        'ClientId': AuthConfig.cognitoClientId,
      });
    } else {
      rethrow;
    }
  }

  final result = data['AuthenticationResult'] as Map<String, dynamic>?;
  if (result == null || result['IdToken'] == null) {
    throw const AuthException('Session refresh failed. Please log in again.', code: 'MissingTokens');
  }

  return CognitoTokens(
    idToken: result['IdToken'] as String,
    accessToken: result['AccessToken'] as String?,
    refreshToken: (result['RefreshToken'] as String?) ?? refreshToken,
    expiresIn: result['ExpiresIn'] as int?,
    tokenType: result['TokenType'] as String?,
  );
}
