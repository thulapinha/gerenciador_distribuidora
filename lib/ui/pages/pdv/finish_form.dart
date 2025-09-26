// lib/ui/pages/pdv/finish_form.dart
part of '../pdv_page.dart';

class _FinishForm extends StatefulWidget {
  final _PayMethod method;
  final List<_PdvItem> items;
  final double total;
  final double received;
  final double change;
  final ValueChanged<double> onReceivedChanged;
  final VoidCallback onFinalize;     // não-PIX
  final VoidCallback onPixApproved;  // quando PIX aprovar
  final VoidCallback onBack;

  const _FinishForm({
    required this.method,
    required this.items,
    required this.total,
    required this.received,
    required this.change,
    required this.onReceivedChanged,
    required this.onFinalize,
    required this.onPixApproved,
    required this.onBack,
  });

  @override
  State<_FinishForm> createState() => _FinishFormState();
}

class _FinishFormState extends State<_FinishForm> {
  bool _busy = false;

  String _fmt(num v) => 'R\$ ${v.toStringAsFixed(2)}';

  List<Map<String, dynamic>> _buildItemsPayload() {
    return widget.items.map((e) {
      final base = {
        'qty': e.qty,
        'unitPrice': e.unitPrice,
        'uom': e.uom,
        'multiplier': e.multiplier,
      };
      if (e.productId != null) return {'productId': e.productId, ...base};
      return {'manual': true, 'name': e.name, ...base};
    }).toList();
  }

  Future<void> _payWithPix() async {
    setState(() => _busy = true);
    try {
      final clientTxnId =
          'txn-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(0x7fffffff)}';

      final payload = {
        'items': _buildItemsPayload(),
        'discount': 0.0,
        'customerId': null,
        'customerCpf': null,
        'note': null,
        'clientTxnId': clientTxnId,
        'createdAtLocal': DateTime.now().toIso8601String(),
        'total': widget.total,
      };

      final fn = ParseCloudFunction('mpCreatePixPayment');
      final resp = await fn.execute(parameters: payload);

      if (!mounted) return;

      if (!(resp.success)) {
        final msg = resp.error?.message ??
            (resp.result is Map ? (resp.result['message']?.toString() ?? '') : '');
        _showError('Falha ao criar pagamento.\n$msg');
        return;
      }

      final data = (resp.result as Map).cast<String, dynamic>();

      final saleId   = (data['saleId'] ?? data['sale_id'] ?? '').toString();
      final payIdStr = (data['paymentId'] ?? data['mpPaymentId'] ?? data['id'] ?? data['payment_id'] ?? '').toString();

      // TOP-LEVEL: agora considera qr_code_base64 também
      final qrCode   = (data['qr_code'] ?? _deep(data, ['point_of_interaction','transaction_data','qr_code']))?.toString();
      final qrBase64 = (data['qr_code_base64'] ?? data['qr_base64'] ??
          _deep(data, ['point_of_interaction','transaction_data','qr_code_base64']))?.toString();
      final ticket   = (data['ticket_url'] ??
          _deep(data, ['point_of_interaction','transaction_data','ticket_url']))?.toString();

      if (payIdStr.isEmpty) {
        _showError('Retorno sem paymentId/mpPaymentId.');
        return;
      }

      final dialogResult = await showDialog<PixDialogResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PixPaymentDialog(
          saleId: saleId,
          paymentId: payIdStr, // dialog converte p/ number ao chamar o cloud
          qrCode: qrCode,
          qrBase64Png: qrBase64,
          ticketUrl: ticket,
        ),
      );

      if (!mounted) return;

      if (dialogResult == PixDialogResult.approved) {
        widget.onPixApproved();
      } else if (dialogResult == PixDialogResult.pending) {
        _showInfo('Pagamento ainda pendente. Verifique depois.');
      } else if (dialogResult == PixDialogResult.cancelled) {
        _showInfo('Pagamento cancelado.');
      } else if (dialogResult == PixDialogResult.expired) {
        _showInfo('Pagamento expirado.');
      } else if (dialogResult == PixDialogResult.rejected) {
        _showInfo('Pagamento rejeitado.');
      }
    } catch (e) {
      _showError('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  dynamic _deep(Map<String, dynamic> m, List<String> path) {
    dynamic v = m;
    for (final k in path) {
      if (v is Map && v.containsKey(k)) {
        v = v[k];
      } else {
        return null;
      }
    }
    return v;
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erro'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isPix = widget.method == _PayMethod.pix;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(_fmt(widget.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!isPix) ...[
                    Row(
                      children: [
                        const Text('Recebido'),
                        const Spacer(),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            textAlign: TextAlign.right,
                            controller: TextEditingController(
                              text: widget.received.toStringAsFixed(2),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onSubmitted: (s) {
                              final v = double.tryParse(s.replaceAll(',', '.')) ?? widget.total;
                              widget.onReceivedChanged(v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Troco'),
                        const Spacer(),
                        Text(_fmt(widget.change)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : widget.onBack,
                child: const Text('Voltar (F11)'),
              ),
              if (isPix)
                FilledButton.icon(
                  onPressed: _busy ? null : _payWithPix,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Pagar com PIX'),
                )
              else
                FilledButton.icon(
                  onPressed: _busy ? null : widget.onFinalize,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Finalizar (F8/F12/Enter)'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
