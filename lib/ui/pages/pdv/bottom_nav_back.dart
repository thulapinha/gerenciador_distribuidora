// lib/ui/pages/pdv/bottom_nav_back.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

class _BottomNavBack extends StatelessWidget {
  const _BottomNavBack({required this.text, required this.onBack});
  final String text;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: Text(text)),
    );
  }
}
