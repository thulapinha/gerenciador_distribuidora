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
    // NOVOS (visual): status servidor + usuário
    required this.serverOnline,
    required this.userName,
  });

  final int itemsCount;
  final double discount;
  final double subtotal;
  final double total;
  final VoidCallback onDiscount;
  final VoidCallback onProceed;

  // NOVOS
  final bool serverOnline;
  final String userName;

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final online = serverOnline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          // ---- Status Servidor + Usuário (substitui "Operante / SEFAZ") ----
          _InfoTile(
            leading: Icon(
              online ? Icons.check_circle : Icons.error,
              color: online ? Colors.green : Colors.red,
            ),
            title: online ? 'Servidor ONLINE' : 'Servidor OFFLINE',
            subtitle: 'Usuário: $userName',
          ),
          const SizedBox(width: 12),

          // ---- Itens (igual) ----
          _InfoTile(title: '$itemsCount', subtitle: 'Item${itemsCount == 1 ? '' : 's'}'),
          const SizedBox(width: 12),

          // ---- Desconto (MENOR) ----
          InkWell(
            onTap: onDiscount,
            borderRadius: BorderRadius.circular(14),
            child: _InfoTile(
              title: _money(discount),
              subtitle: 'Desconto (F10)',
              compact: true,                  // <<< menor padding/tipografia
            ),
          ),
          const SizedBox(width: 12),

          // ---- Total (MAIOR/DESTAQUE) ----
          _InfoTile(
            title: _money(total),
            subtitle: 'Total',
            emphasized: true,                 // <<< destacado e grande
          ),
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
  const _InfoTile({
    this.leading,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.emphasized = false,
  });
  final Widget? leading;
  final String title;
  final String subtitle;

  // NOVOS ajustes visuais
  final bool compact;     // reduz padding e fonte
  final bool emphasized;  // aumenta e destaca (para Total)

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    final TextStyle titleStyle = emphasized
        ? const TextStyle(fontSize: 28, fontWeight: FontWeight.w900) // bem nítido
        : Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700);

    final TextStyle subtitleStyle = emphasized
        ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant);

    final BoxDecoration deco = emphasized
        ? BoxDecoration(
      color: cs.tertiaryContainer.withOpacity(.55),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.tertiary, width: 1.6),
      boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black12)],
    )
        : BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(14),
    );

    final BoxConstraints cons = emphasized
        ? const BoxConstraints(minWidth: 240, minHeight: 68) // maior para o Total
        : const BoxConstraints(minWidth: 0);

    return Container(
      constraints: cons,
      padding: padding,
      decoration: deco,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              Text(subtitle, style: subtitleStyle),
            ],
          )
        ],
      ),
    );
  }
}
