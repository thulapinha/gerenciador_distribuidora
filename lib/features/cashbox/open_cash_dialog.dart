import 'package:flutter/material.dart';
import '../../domain/services/cash_service.dart';

class OpenCashDialog extends StatefulWidget {
  const OpenCashDialog({super.key});

  @override
  State<OpenCashDialog> createState() => _OpenCashDialogState();
}

class _OpenCashDialogState extends State<OpenCashDialog> {
  final _form = GlobalKey<FormState>();
  final _trocoCtrl = TextEditingController(text: '0');
  final _sangriaInicialCtrl = TextEditingController(text: '0');

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _trocoCtrl.dispose();
    _sangriaInicialCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      double parseNum(String s) =>
          double.tryParse(s.trim().replaceAll(',', '.')) ?? 0.0;

      final opening = parseNum(_trocoCtrl.text);
      final sangriaInicial = parseNum(_sangriaInicialCtrl.text);

      final cash = CashService();
      final res = await cash.open(opening);

      if (sangriaInicial > 0) {
        await cash.sangria(sangriaInicial, note: 'Sangria na abertura');
      }

      if (!mounted) return;
      Navigator.of(context).pop(res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir caixa'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _trocoCtrl,
              decoration: const InputDecoration(
                labelText: 'Troco inicial (R\$)',
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _sangriaInicialCtrl,
              decoration: const InputDecoration(
                labelText: 'Sangria imediata (opcional)',
                helperText: 'Se quiser retirar já na abertura',
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
              : const Text('Abrir'),
        ),
      ],
    );
  }
}
