import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../repositories/customer_repository.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.customerId});
  final String? customerId;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _repo = CustomerRepository();
  final _form = GlobalKey<FormState>();

  // Ctls
  final name = TextEditingController();
  final cpfCnpj = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final zip = TextEditingController();
  final street = TextEditingController();
  final number = TextEditingController();
  final neighborhood = TextEditingController();
  final city = TextEditingController();
  final stateCtl = TextEditingController();
  final creditLimit = TextEditingController(text: '0');
  final balance = TextEditingController(text: '0');
  final notes = TextEditingController();

  bool active = true;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) _load();
  }

  @override
  void dispose() {
    for (final c in [
      name, cpfCnpj, phone, email, zip, street, number, neighborhood, city, stateCtl, creditLimit, balance, notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final c = await _repo.getById(widget.customerId!);
      if (c != null) {
        name.text = c.get<String>('name') ?? '';
        cpfCnpj.text = c.get<String>('cpfCnpj') ?? '';
        phone.text = c.get<String>('phone') ?? '';
        email.text = c.get<String>('email') ?? '';
        zip.text = c.get<String>('zip') ?? '';
        street.text = c.get<String>('street') ?? '';
        number.text = c.get<String>('number') ?? '';
        neighborhood.text = c.get<String>('neighborhood') ?? '';
        city.text = c.get<String>('city') ?? '';
        stateCtl.text = c.get<String>('state') ?? '';
        creditLimit.text = (c.get<num>('creditLimit') ?? 0).toString();
        balance.text = (c.get<num>('balance') ?? 0).toString();
        notes.text = c.get<String>('notes') ?? '';
        active = c.get<bool>('active') ?? true;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double _parseMoney(String t) {
    var s = t.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.contains(',') && s.contains('.')) s = s.replaceAll('.', '').replaceAll(',', '.');
    if (s.contains(',') && !s.contains('.')) s = s.replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await _repo.save({
        'objectId': widget.customerId,
        'name': name.text.trim(),
        'cpfCnpj': cpfCnpj.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'zip': zip.text.trim(),
        'street': street.text.trim(),
        'number': number.text.trim(),
        'neighborhood': neighborhood.text.trim(),
        'city': city.text.trim(),
        'state': stateCtl.text.trim(),
        'active': active,
        'creditLimit': _parseMoney(creditLimit.text),
        'balance': _parseMoney(balance.text),
        'notes': notes.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso.')));
      context.go('/customers'); // volta para lista
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerId == null ? 'Novo Cliente' : 'Editar Cliente'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  flex: 3,
                ),
                _field(TextFormField(
                  controller: cpfCnpj,
                  decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
                )),
                _field(TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                )),
                _field(
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  flex: 2,
                ),
                _field(TextFormField(
                  controller: creditLimit,
                  decoration: const InputDecoration(labelText: 'Limite de crédito'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                _field(TextFormField(
                  controller: balance,
                  decoration: const InputDecoration(labelText: 'Saldo/Em aberto'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(TextFormField(controller: zip, decoration: const InputDecoration(labelText: 'CEP')), flex: 1),
                _field(TextFormField(controller: street, decoration: const InputDecoration(labelText: 'Rua')), flex: 3),
                _field(TextFormField(controller: number, decoration: const InputDecoration(labelText: 'Número')), flex: 1),
                _field(TextFormField(controller: neighborhood, decoration: const InputDecoration(labelText: 'Bairro')), flex: 2),
                _field(TextFormField(controller: city, decoration: const InputDecoration(labelText: 'Cidade')), flex: 2),
                _field(TextFormField(controller: stateCtl, decoration: const InputDecoration(labelText: 'UF')), flex: 1),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Observações'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Cliente ativo'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar')),
                const SizedBox(width: 8),
                TextButton.icon(onPressed: () => context.go('/customers'), icon: const Icon(Icons.arrow_back), label: const Text('Voltar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(Widget child, {int flex = 1}) {
    return SizedBox(width: 280.0 * flex, child: child);
  }
}
