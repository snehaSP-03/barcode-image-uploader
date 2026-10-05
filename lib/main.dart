import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth/auth_store.dart';
import 'screens/login_screen.dart';
import 'screens/lookup_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const envFile = String.fromEnvironment('ENV_FILE', defaultValue: '.env');
  await dotenv.load(fileName: envFile);
  await AuthStore.instance.restoreSession();
  runApp(const BarcodeUploaderApp());
}

class BarcodeUploaderApp extends StatelessWidget {
  const BarcodeUploaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Image Uploader',
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: AuthStore.instance,
        builder: (context, _) {
          final auth = AuthStore.instance;
          if (auth.status == AuthStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isAuthenticated) {
            return const LookupScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
