import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cognito_client.dart' as cognito;
import 'cognito_client.dart' show CognitoTokens;
import 'config.dart';
import 'errors.dart';
import 'jwt.dart';
import 'session_store.dart';

enum AuthStatus { loading, anonymous, authenticated }

class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  AuthStatus status = AuthStatus.loading;
  CognitoTokens? tokens;
  List<String> groups = [];
  String displayName = '';

  Future<String>? _refreshFlight;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  List<String> _assertStaffAccess(String idToken) {
    final tokenGroups = getCognitoGroups(idToken);
    final allowed = AuthConfig.allowedGroups;
    final hasAccess = tokenGroups.any(allowed.contains);
    if (!hasAccess) {
      throw AuthException(
        'This account needs ${allowed.join(" or ")} access to upload product images.',
        code: 'AccessDenied',
      );
    }
    return tokenGroups;
  }

  Future<void> _applySession(CognitoTokens sessionTokens) async {
    final resolvedGroups = _assertStaffAccess(sessionTokens.idToken);
    await SessionStore.save(sessionTokens);
    tokens = sessionTokens;
    groups = resolvedGroups;
    displayName = displayNameFromIdToken(sessionTokens.idToken);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _clearAuth() async {
    await SessionStore.clear();
    tokens = null;
    groups = [];
    displayName = '';
    status = AuthStatus.anonymous;
    notifyListeners();
  }

  Future<String> ensureIdToken({bool force = false}) async {
    final current = tokens;
    if (current == null) {
      throw const AuthException('Not signed in.', code: 'Unauthenticated');
    }
    if (!force && !isTokenExpired(current.idToken)) {
      return current.idToken;
    }

    if (_refreshFlight != null) {
      return _refreshFlight!;
    }

    final completer = Completer<String>();
    _refreshFlight = completer.future;

    try {
      final refreshed = await cognito.refreshTokens(current.refreshToken);
      tokens = refreshed;
      await SessionStore.save(refreshed);
      notifyListeners();
      completer.complete(refreshed.idToken);
      return refreshed.idToken;
    } catch (e) {
      completer.completeError(e);
      if (e is AuthException && (e.code == 'NotAuthorizedException' || e.code == 'MissingTokens')) {
        await _clearAuth();
      }
      rethrow;
    } finally {
      _refreshFlight = null;
    }
  }

  Future<void> restoreSession() async {
    final existing = await SessionStore.load();
    if (existing == null) {
      status = AuthStatus.anonymous;
      notifyListeners();
      return;
    }

    tokens = existing;

    try {
      var next = existing;
      if (isTokenExpired(existing.idToken)) {
        next = await cognito.refreshTokens(existing.refreshToken);
      }
      await _applySession(next);
    } catch (e) {
      if (e is AuthException &&
          (e.code == 'NotAuthorizedException' ||
              e.code == 'MissingTokens' ||
              e.code == 'AccessDenied')) {
        await _clearAuth();
      } else {
        try {
          await _applySession(existing);
        } catch (_) {
          await _clearAuth();
        }
      }
    }
  }

  Future<void> login({required String identifier, required String pin}) async {
    final sessionTokens = await cognito.signIn(identifier: identifier, pin: pin);
    await _applySession(sessionTokens);
  }

  Future<void> logout() => _clearAuth();
}
