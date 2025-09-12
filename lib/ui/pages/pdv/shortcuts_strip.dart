// lib/ui/pages/pdv/shortcuts_strip.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Shortcuts Strip =======================================================
class _ShortcutsStripItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: const [
          _KbdHint('F2', 'Buscar Produto'),
          _KbdHint('F3', 'Adicionar Produto'),
          _KbdHint('F4', 'Alterar quantidade'),
          _KbdHint('F5', 'Alterar valor'),
          _KbdHint('F6', 'Remover produto'),
          _KbdHint('F8', 'Prosseguir'),
          _KbdHint('F10', 'Desconto'),
        ],
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  const _KbdHint(this.k, this.label);
  final String k;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: cs.outlineVariant)),
        child: Text(k, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}
