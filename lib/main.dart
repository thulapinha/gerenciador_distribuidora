import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/di.dart';
import 'app_router.dart';
import 'domain/services/parse_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Widget de erro para evitar “tela preta”
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Ops! Ocorreu um erro.\n${details.exceptionAsString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  await runZonedGuarded<Future<void>>(() async {
    await initParse();
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: MaterialApp.router(
        title: 'Gerenciador Distribuidora',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
        ),
        routerConfig: _router,
      ),
    );
  }
}
