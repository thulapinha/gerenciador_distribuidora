import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/di.dart';
import 'app_router.dart';
import 'domain/services/parse_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Back4App/Parse antes de subir o app
  await initParse();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Evita recriar o GoRouter a cada rebuild
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
