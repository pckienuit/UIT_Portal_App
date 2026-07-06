import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/features/auth/auth_controller.dart';
import 'src/features/auth/auth_providers.dart';
import 'src/features/home/providers/widget_preferences_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  final authController = AuthController();
  await authController.restoreSession();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => authController),
      ],
      child: const UitPortalApp(),
    ),
  );
}