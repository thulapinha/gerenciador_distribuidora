import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/repositories/customer_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _repo = CustomerRepository();
  final _searchCtl = TextEditingController();
  bool _loading = true;
  List<ParseObject> _all = [];
  List<ParseObject> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _all = await _repo.list();
      _filtered = _all;
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final t = _searchCtl.text.toLowerCase().trim();
    setState(() {
      if (t.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((o) {
          final name = (o.get<String>('name') ?? '').toLowerCase();
          final cpf = (o.get<String>('cpf') ?? '').toLowerCase();
          final phone = (o.get<String>('phone') ?? '').toLowerCase();
          return name.contains(t) || cpf.contains(t) || phone.contains(t);
        }).toList();
      }
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openForm({ParseObject? o}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomerDialog(obj: o),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(ParseObject o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text('Deseja excluir "${o.get<String>('name')}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.delete(o.objectId!);
        _snack('Cliente excluído');
        _load();
      } catch (e) {
        _snack('Erro: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nome/CPF/telefone',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Sem clientes'))
                  : ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = _filtered[i];
                  return ListTile(
                    title: Text(o.get<String>('name') ?? '-'),
                    subtitle: Text([
                      o.get<String>('cpf'),
                      o.get<String>('phone'),
                      o.get<String>('email'),
                    ].where((e) => e != null && e!.isNotEmpty).join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(o: o)),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(o)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  final ParseObject? obj;
  const _CustomerDialog({this.obj});

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _repo = CustomerRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.obj;
    if (o != null) {
      _name.text = o.get<String>('name') ?? '';
      _cpf.text = o.get<String>('cpf') ?? '';
      _phone.text = o.get<String>('phone') ?? '';
      _email.text = o.get<String>('email') ?? '';
      _address.text = o.get<String>('address') ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.upsert(
        objectId: widget.obj?.objectId,
        name: _name.text.trim(),
        cpf: _cpf.text.trim().isEmpty ? null : _cpf.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.obj == null ? 'Novo cliente' : 'Editar cliente'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _cpf, decoration: const InputDecoration(labelText: 'CPF', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar')),
      ],
    );
  }
}
