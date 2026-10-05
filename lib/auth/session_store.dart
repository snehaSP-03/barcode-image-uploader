import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cognito_client.dart';

class SessionStore {
  SessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _idTokenKey = 'barcode.uploader.auth.idToken';
  static const _accessTokenKey = 'barcode.uploader.auth.accessToken';
  static const _refreshTokenKey = 'barcode.uploader.auth.refreshToken';

  static Future<CognitoTokens?> load() async {
    final results = await Future.wait([
      _storage.read(key: _idTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _accessTokenKey),
    ]);
    final idToken = results[0];
    final refreshToken = results[1];
    final accessToken = results[2];

    if (idToken == null || idToken.isEmpty || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    return CognitoTokens(idToken: idToken, accessToken: accessToken, refreshToken: refreshToken);
  }

  static Future<void> save(CognitoTokens tokens) async {
    await Future.wait([
      _storage.write(key: _idTokenKey, value: tokens.idToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
      if (tokens.accessToken != null)
        _storage.write(key: _accessTokenKey, value: tokens.accessToken)
      else
        _storage.delete(key: _accessTokenKey),
    ]);
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
