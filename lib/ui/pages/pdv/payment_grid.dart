// lib/ui/pages/pdv/payment_grid.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Payment grid ==========================================================
class _PaymentGrid extends StatelessWidget {
  const _PaymentGrid({required this.onSelect});
  final ValueChanged<_PayMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile(String label, IconData icon, _PayMethod m, {String? hint}) {
      return InkWell(
        onTap: () => onSelect(m),
        child: Container(
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(.25),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (hint != null) Text(hint, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    }

    // Somente os 5 métodos solicitados
    final tiles = <Widget>[
      tile('Dinheiro', Icons.attach_money, _PayMethod.cash, hint: 'F1'),
      tile('Cartão de Crédito', Icons.credit_card, _PayMethod.cardCredit, hint: 'F3'),
      tile('Cartão de Débito', Icons.credit_card_rounded, _PayMethod.cardDebit, hint: 'F4'),
      tile('PIX', Icons.qr_code_2, _PayMethod.pix, hint: 'P'),
      tile('Mercado Pago', Icons.account_balance_wallet, _PayMethod.mercadoPago, hint: 'M'),
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.count(
        crossAxisCount: 5,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        children: tiles,
      ),
    );
  }
}
