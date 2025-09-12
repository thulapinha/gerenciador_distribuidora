// lib/ui/pages/pdv/footer_items.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Footer (itens) =======================================================
class _FooterItems extends StatelessWidget {
  const _FooterItems({
    required this.itemsCount,
    required this.discount,
    required this.subtotal,
    required this.total,
    required this.onDiscount,
    required this.onProceed,
  });

  final int itemsCount;
  final double discount;
  final double subtotal;
  final double total;
  final VoidCallback onDiscount;
  final VoidCallback onProceed;

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          _InfoTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: 'Operante', subtitle: 'Status SEFAZ'),
          const SizedBox(width: 12),
          _InfoTile(title: '$itemsCount', subtitle: 'Item${itemsCount == 1 ? '' : 's'}'),
          const SizedBox(width: 12),
          Expanded(child: InkWell(onTap: onDiscount, borderRadius: BorderRadius.circular(14), child: _InfoTile(title: _money(discount), subtitle: 'Desconto (F10)'))),
          const SizedBox(width: 12),
          _InfoTile(title: _money(total), subtitle: 'Total'),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('FINALIZAR (F8)'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({this.leading, required this.title, required this.subtitle});
  final Widget? leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
          ])
        ],
      ),
    );
  }
}
