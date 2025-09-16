part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Shortcuts Strip =======================================================
// Agora os "chips" são clicáveis e disparam as mesmas ações dos atalhos.
class _ShortcutsStripItems extends StatelessWidget {
  const _ShortcutsStripItems({
    required this.onF2Search,
    required this.onF3Add,
    required this.onF4Qty,
    required this.onF5Val,
    required this.onF6Remove,
    required this.onF8Proceed,
    required this.onF10Discount,
  });

  final VoidCallback onF2Search;
  final VoidCallback onF3Add;
  final VoidCallback onF4Qty;
  final VoidCallback onF5Val;
  final VoidCallback onF6Remove;
  final VoidCallback onF8Proceed;
  final VoidCallback onF10Discount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _KbdHint('F2', 'Buscar Produto', onTap: onF2Search),
          _KbdHint('F3', 'Adicionar Produto', onTap: onF3Add),
          _KbdHint('F4', 'Alterar quantidade', onTap: onF4Qty),
          _KbdHint('F5', 'Alterar valor', onTap: onF5Val),
          _KbdHint('F6', 'Remover produto', onTap: onF6Remove),
          _KbdHint('F8', 'Prosseguir', onTap: onF8Proceed),
          _KbdHint('F10', 'Desconto', onTap: onF10Discount),
        ],
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  const _KbdHint(this.k, this.label, {required this.onTap});
  final String k;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(k, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}
