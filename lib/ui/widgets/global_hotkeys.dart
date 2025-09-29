import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envolve qualquer tela e captura F2, F3, F4, F5, F6, F8, F10.
/// Não interfere no layout. Use no PDV envolvendo o Scaffold.
class GlobalHotkeys extends StatefulWidget {
  const GlobalHotkeys({
    super.key,
    required this.child,
    this.onF2,
    this.onF3,
    this.onF4,
    this.onF5,
    this.onF6,
    this.onF8,
    this.onF10,
  });

  final Widget child;
  final VoidCallback? onF2;
  final VoidCallback? onF3;
  final VoidCallback? onF4;
  final VoidCallback? onF5;
  final VoidCallback? onF6;
  final VoidCallback? onF8;
  final VoidCallback? onF10;

  @override
  State<GlobalHotkeys> createState() => _GlobalHotkeysState();
}

class _GlobalHotkeysState extends State<GlobalHotkeys> {
  final _focus = FocusNode(debugLabel: 'GlobalHotkeys');

  @override
  void initState() {
    super.initState();
    // Garante foco logo após montar.
    scheduleMicrotask(() {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Apenas no "key down"
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    bool handled = false;
    void call(VoidCallback? cb) {
      if (cb != null) {
        cb();
        handled = true;
      }
    }

    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.f2) call(widget.onF2);
    else if (k == LogicalKeyboardKey.f3) call(widget.onF3);
    else if (k == LogicalKeyboardKey.f4) call(widget.onF4);
    else if (k == LogicalKeyboardKey.f5) call(widget.onF5);
    else if (k == LogicalKeyboardKey.f6) call(widget.onF6);
    else if (k == LogicalKeyboardKey.f8) call(widget.onF8);
    else if (k == LogicalKeyboardKey.f10) call(widget.onF10);

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
