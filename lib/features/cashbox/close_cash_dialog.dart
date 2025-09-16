import 'package:flutter/material.dart';
import '../../domain/services/cash_service.dart';

class CloseCashDialog extends StatefulWidget {
  const CloseCashDialog({super.key});

  @override
  State<CloseCashDialog> createState() => _CloseCashDialogState();
}

class _CloseCashDialogState extends State<CloseCashDialog> {
  final _form = GlobalKey<FormState>();
  final _declaredCtrl = TextEditingController(text: '0');

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _declaredCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final declared =
          double.tryParse(_declaredCtrl.text.trim().replaceAll(',', '.')) ??
              0.0;
      final cash = CashService();
      final summary = await cash.close(declared);
      final report =
      await cash.report(sessionId: summary['sessionId'] as String?);

      if (!mounted) return;
      Navigator.of(context).pop(report); // retorna o extrato completo
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fechar caixa'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _declaredCtrl,
              decoration: const InputDecoration(
                labelText: 'Valor contado (R\$)',
                prefixText: 'R\$ ',
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final x = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (x == null || x < 0) return 'Informe um valor válido';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator())
              : const Text('Fechar'),
        ),
      ],
    );
  }
}
