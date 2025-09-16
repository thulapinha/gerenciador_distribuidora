import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../repositories/customer_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _repo = CustomerRepository();
  final _searchCtl = TextEditingController();

  Timer? _deb;
  String _query = '';
  bool _onlyActive = true; // filtro padrão
  bool _loading = false;
  bool _canLoadMore = true;
  int _skip = 0;
  final List<ParseObject> _items = [];

  // Resumo
  int _countActive = 0;
  int _countInactive = 0;

  @override
  void initState() {
    super.initState();
    _refresh(clear: true);
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool clear = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (clear) {
        _skip = 0;
        _items.clear();
        _canLoadMore = true;
      }
      final page = await _repo.search(q: _query, limit: 40, skip: _skip, onlyActive: _onlyActive);
      _items.addAll(page);
      _skip = _items.length;
      _canLoadMore = page.length == 40;

      // Resumo (mock simples; ideal seria cloud function de contagem)
      final active = await _repo.search(q: '', limit: 1, skip: 0, onlyActive: true);
      setState(() {
        _countActive = active.length;
        _countInactive = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 400), () {
      _query = v.trim();
      _refresh(clear: true);
    });
  }

  Future<void> _confirmDelete(ParseObject c) async {
    final name = c.get<String>('name') ?? '';
    final hard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover cliente'),
        content: Text('Deseja realmente remover "$name"?\n'
            'Você pode "inativar" (remoção lógica) ou "excluir" permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Inativar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (hard == null) return;
    try {
      await _repo.delete(c.objectId!, hardDelete: hard);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hard ? 'Excluído com sucesso.' : 'Cliente inativado.')),
        );
      }
      _refresh(clear: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('customerNew'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
      body: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(.95), cs.primaryContainer.withOpacity(.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clientes', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Busca
                    Expanded(
                      child: TextField(
                        controller: _searchCtl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome/CPF/CNPJ/telefone/email',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Ativos')),
                        ButtonSegment(value: false, label: Text('Todos')),
                      ],
                      selected: {_onlyActive},
                      onSelectionChanged: (s) {
                        setState(() => _onlyActive = s.first);
                        _refresh(clear: true);
                      },
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _refresh(clear: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Cards resumo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                _StatTile(title: 'Clientes Ativos', value: '$_countActive'),
                const SizedBox(width: 12),
                _StatTile(title: 'Clientes Inativos', value: '$_countInactive'),
                const Spacer(),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    _ListHeader(),
                    Expanded(
                      child: _loading && _items.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _items.isEmpty
                          ? const Center(child: Text('Nenhum cliente encontrado'))
                          : ListView.separated(
                        itemCount: _items.length + (_canLoadMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            _refresh();
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final c = _items[index];
                          return _CustomerRow(
                            c: c,
                            onEdit: () => context.pushNamed(
                              'customerEdit',
                              pathParameters: {'id': c.objectId!},
                            ),
                            onDelete: () => _confirmDelete(c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
        Text(title, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _ListHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          _HCell(flex: 2, child: Text('Nome', style: style)),
          _HCell(flex: 2, child: Text('CPF/CNPJ', style: style)),
          _HCell(flex: 2, child: Text('Telefone', style: style)),
          _HCell(flex: 2, child: Text('E-mail', style: style)),
          _HCell(flex: 1, child: Text('Últ. compra', style: style)),
          _HCell(width: 90, child: const SizedBox()),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.c, required this.onEdit, required this.onDelete});
  final ParseObject c;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _fmtCpf(String? v) {
    if (v == null || v.isEmpty) return '';
    final s = v.replaceAll(RegExp(r'\D'), '');
    if (s.length == 11) {
      return '${s.substring(0,3)}.${s.substring(3,6)}.${s.substring(6,9)}-${s.substring(9)}';
    } else if (s.length == 14) {
      return '${s.substring(0,2)}.${s.substring(2,5)}.${s.substring(5,8)}/${s.substring(8,12)}-${s.substring(12)}';
    }
    return v;
  }

  String _fmtPhone(String? v) {
    if (v == null) return '';
    final s = v.replaceAll(RegExp(r'\D'), '');
    if (s.length >= 10) {
      final ddd = s.substring(0,2);
      final rest = s.substring(2);
      if (rest.length == 8) return '($ddd) ${rest.substring(0,4)}-${rest.substring(4)}';
      if (rest.length >= 9) return '($ddd) ${rest.substring(0,5)}-${rest.substring(5,9)}';
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final name = c.get<String>('name') ?? '';
    final cpf = _fmtCpf(c.get<String>('cpfCnpj'));
    final phone = _fmtPhone(c.get<String>('phone'));
    final email = c.get<String>('email') ?? '';
    final last = c.get<DateTime>('lastPurchase');
    final lastStr = last == null ? '-' : DateFormat('dd/MM').format(last);

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            _HCell(flex: 2, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _HCell(flex: 2, child: Text(cpf, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _HCell(flex: 2, child: Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _HCell(flex: 2, child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis)),
            _HCell(flex: 1, child: Text(lastStr)),
            _HCell(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(tooltip: 'Editar', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                  IconButton(tooltip: 'Remover', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  const _HCell({this.flex, this.width, required this.child});
  final int? flex;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Align(alignment: Alignment.centerLeft, child: child);
    if (width != null) return SizedBox(width: width, child: content);
    return Expanded(flex: flex ?? 1, child: content);
  }
}
