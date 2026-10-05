class AuthException implements Exception {
  const AuthException(this.message, {this.code, this.payload});

  final String message;
  final String? code;
  final Map<String, dynamic>? payload;

  @override
  String toString() => message;
}

const Map<String, String> _kCognitoMessages = {
  'NotAuthorizedException': 'Incorrect phone/email or PIN. Please try again.',
  'UserNotFoundException': 'No account found with those details.',
  'UserNotConfirmedException': 'Please confirm your account before logging in.',
  'InvalidPasswordException': 'PIN does not meet security requirements.',
  'InvalidParameterException': 'Check your phone, email, and PIN, then try again.',
  'LimitExceededException': 'Too many attempts. Please wait a moment and try again.',
  'TooManyRequestsException': 'Too many requests. Please wait and try again.',
};

AuthException messageFromCognitoError({String? code, String? rawMessage}) {
  if (code != null && _kCognitoMessages.containsKey(code)) {
    return AuthException(_kCognitoMessages[code]!, code: code);
  }
  if (rawMessage != null && rawMessage.isNotEmpty) {
    return AuthException(rawMessage, code: code);
  }
  return AuthException('Something went wrong. Please try again.', code: code);
}

const Map<String, String> _kApiMessages = {
  'not_found': 'Product not in catalog.',
  'barcode_required': 'Enter a barcode.',
  'forbidden': 'You do not have permission for this action (Admin/Ops required).',
  'artifacts_bucket_missing': 'Image storage is not configured on the server. Report to backend.',
  'image_keys_must_be_list': 'image_keys must be sent as a JSON array.',
  'max_images': 'This product already has 5 photos. Remove one before adding more.',
};

AuthException messageFromApiError(Map<String, dynamic>? payload, int status) {
  final error = payload?['error'];
  if (error is String && error.isNotEmpty) {
    final friendly = _kApiMessages[error];
    if (friendly != null) return AuthException(friendly, code: error, payload: payload);
    return AuthException(error, code: error, payload: payload);
  }
  final message = payload?['message'];
  if (message is String && message.isNotEmpty) {
    return AuthException(message, payload: payload);
  }
  if (status == 401) {
    return const AuthException('Session expired. Please log in again.', code: 'Unauthorized');
  }
  if (status == 403) {
    return const AuthException(
      'You do not have permission for this action (Admin/Ops required).',
      code: 'forbidden',
    );
  }
  if (status == 404) {
    return const AuthException('Product not in catalog.', code: 'not_found');
  }
  return AuthException('Request failed (HTTP $status). Please try again.', payload: payload);
}
