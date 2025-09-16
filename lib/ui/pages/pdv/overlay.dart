// lib/ui/pages/pdv/overlay.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Overlay progress (não trava) =========================================
VoidCallback _showBlockingOverlay(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  var removed = false;

  entry = OverlayEntry(
    builder: (_) => Stack(children: [
      const ModalBarrier(dismissible: false, color: Colors.black54),
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              const SizedBox(width: 12),
              Flexible(child: Text(message)),
            ]),
          ),
        ),
      ),
    ]),
  );

  overlay.insert(entry);

  final timer = Timer(const Duration(seconds: 25), () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
  });
  return () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
    timer.cancel();
  };
}
