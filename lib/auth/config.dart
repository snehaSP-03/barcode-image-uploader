import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthConfig {
  AuthConfig._();

  static String get cognitoRegion => dotenv.env['COGNITO_REGION']!;
  static String get cognitoClientId => dotenv.env['COGNITO_CLIENT_ID']!;
  static String get cognitoUserPoolId => dotenv.env['COGNITO_USER_POOL_ID']!;

  /// Staff groups that may use barcode lookup + product image upload.
  static List<String> get allowedGroups {
    final raw = dotenv.env['AUTH_ALLOWED_GROUPS'] ?? 'Admin,Ops';
    return raw
        .split(',')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
  }
}
