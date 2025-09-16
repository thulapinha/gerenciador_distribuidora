import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di.dart';
import 'app_router.dart';
import 'domain/services/parse_initializer.dart';

Future<void> main() async {
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
    // ===== Desktop: abrir MAXIMIZADO (mantém botões do SO) ==================
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        center: true,
        // Obs: manter TitleBarStyle.normal garante os botões padrão
        titleBarStyle: TitleBarStyle.normal,
        backgroundColor: Colors.transparent,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();

        // Garante que não está em fullscreen (onde os botões somem)
        final fs = await windowManager.isFullScreen();
        if (fs) await windowManager.setFullScreen(false);

        // Maximiza com barra de título e botões visíveis
        await windowManager.maximize();
      });

      // Fallback pós-primeiro frame (alguns WMs aplicam depois de renderizar)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final fs = await windowManager.isFullScreen();
        if (fs) await windowManager.setFullScreen(false);
        // Reforça maximize se algo interferiu
        await windowManager.maximize();
      });
    }

    await initParse(); // mantém seu inicializador atual
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Agora buildRouter() existe em app_router.dart
  static final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: MaterialApp.router(
        title: 'RBC SERVIÇOS-Gerenciador Distribuidora',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
        ),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
