import 'package:flutter/material.dart';
import '../../domain/services/cash_service.dart';

class CashMovementDialog extends StatefulWidget {
  final bool isSangria; // true=SANGRIA, false=SUPRIMENTO
  const CashMovementDialog({super.key, required this.isSangria});

  @override
  State<CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<CashMovementDialog> {
  final _form = GlobalKey<FormState>();
  final _valueCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final v =
          double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      final note = _noteCtrl.text.trim();

      final cash = CashService();
      if (widget.isSangria) {
        await cash.sangria(v, note: note.isEmpty ? null : note);
      } else {
        await cash.suprimento(v, note: note.isEmpty ? null : note);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSangria ? 'Sangria' : 'Suprimento';
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _valueCtrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixText: 'R\$ ',
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final x = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (x == null || x <= 0) return 'Informe um valor > 0';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration:
              const InputDecoration(labelText: 'Observação (opcional)'),
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
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
