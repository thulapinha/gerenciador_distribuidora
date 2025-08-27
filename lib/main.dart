// lib/main.dart
import 'package:flutter/material.dart';
import 'core/di.dart';
import 'app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: MaterialApp.router(
        title: 'Gerenciador Distribuidora',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        routerConfig: buildRouter(),
      ),
    );
  }
}