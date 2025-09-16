part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Finish form ===========================================================
class _FinishForm extends StatefulWidget {
  const _FinishForm({
    required this.method,
    required this.total,
    required this.received,
    required this.change,
    required this.onReceivedChanged,
    required this.onFinalize,
    required this.onBack,
  });

  final _PayMethod method;
  final double total;
  final double received;
  final double change;
  final ValueChanged<double> onReceivedChanged;
  final VoidCallback onFinalize;
  final VoidCallback onBack;

  @override
  State<_FinishForm> createState() => _FinishFormState();
}

class _FinishFormState extends State<_FinishForm> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.received.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void didUpdateWidget(covariant _FinishForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // se o valor vindo de fora mudar (ex.: pré-preenchido), refletir sem quebrar caret
    if (oldWidget.received != widget.received &&
        _parseFinish(_ctl.text) != widget.received) {
      final sel = _ctl.selection;
      _ctl.text = widget.received.toStringAsFixed(2).replaceAll('.', ',');
      _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
      // mantém caret ao final
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_title(widget.method), style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    onChanged: (t) => widget.onReceivedChanged(_parseFinish(t)),
                    onSubmitted: (_) => widget.onFinalize(), // ENTER conclui
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor recebido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar (F11)',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: widget.onFinalize,
                  icon: const Icon(Icons.check),
                  label: const Text('FINALIZAR (F12/F8)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _FinishCard(title: _money(widget.total),    subtitle: 'Valor total do pedido'),
                const SizedBox(width: 12),
                _FinishCard(title: _money(widget.received), subtitle: 'Valor recebido'),
                const SizedBox(width: 12),
                _FinishCard(title: _money(widget.change),   subtitle: 'Troco'),
              ],
            )
          ],
        ),
      ),
    );
  }

  double _parseFinish(String t) {
    var s = t.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  String _title(_PayMethod m) {
    switch (m) {
      case _PayMethod.cash:         return '1 - Dinheiro';
      case _PayMethod.check:        return '1 - Cheque';
      case _PayMethod.cardCredit:   return '1 - Cartão de Crédito';
      case _PayMethod.cardDebit:    return '1 - Cartão de Débito';
      case _PayMethod.storeCredit:  return '1 - Crédito Loja';
      case _PayMethod.foodVoucher:  return '1 - Vale Alimentação';
      case _PayMethod.mealVoucher:  return '1 - Vale Refeição';
      case _PayMethod.giftCard:     return '1 - Vale Presente';
      case _PayMethod.fuelVoucher:  return '1 - Vale Combustível';
      case _PayMethod.other:        return '1 - Outros';
      case _PayMethod.pix:          return '1 - PIX';
      case _PayMethod.mercadoPago:  return '1 - Mercado Pago';
    }
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
