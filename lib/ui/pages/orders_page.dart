// lib/ui/pages/orders_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// Se existir no seu projeto, será usado; senão o código faz fallback para Query direta.
import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _prodRepo = ProductRepository();
  ParseObject? _selectedCustomer;
  ParseObject? _selectedProduct;

  double _qty = 1;

  _OrderDraft? _draft;

  // últimos pedidos
  List<ParseObject> _recentOrders = [];
  bool _loadingRecent = false;

  // =============================================================================
  // Helpers
  // =============================================================================
  String _money(num v) => 'R\$ ' + v.toStringAsFixed(2).replaceAll('.', ',');
  String _fmtQty(num v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void initState() {
    super.initState();
    _loadRecentOrders();
  }

  // =============================================================================
  // Busca: CLIENTES (Parse)
  // =============================================================================
  Future<List<ParseObject>> _searchCustomers(String term,
      {int limit = 40}) async {
    try {
      final base = ParseObject('Customer');

      if (term.trim().isEmpty) {
        final q = QueryBuilder<ParseObject>(base)
          ..orderByAscending('name')
          ..setLimit(limit);
        final r = await q.query().timeout(const Duration(seconds: 12));
        if (!r.success) return <ParseObject>[];
        return (r.results ?? []).cast<ParseObject>();
      }

      final nameQ = QueryBuilder<ParseObject>(ParseObject('Customer'))
        ..whereContains('name', term, caseSensitive: false);
      final cpfQ = QueryBuilder<ParseObject>(ParseObject('Customer'))
        ..whereContains('cpf', term, caseSensitive: false);
      final phoneQ = QueryBuilder<ParseObject>(ParseObject('Customer'))
        ..whereContains('phone', term, caseSensitive: false);
      final emailQ = QueryBuilder<ParseObject>(ParseObject('Customer'))
        ..whereContains('email', term, caseSensitive: false);

      final orQ = QueryBuilder.or(base, [nameQ, cpfQ, phoneQ, emailQ])
        ..orderByAscending('name')
        ..setLimit(limit);

      final r = await orQ.query().timeout(const Duration(seconds: 12));
      if (!r.success) return <ParseObject>[];
      return (r.results ?? []).cast<ParseObject>();
    } on TimeoutException {
      _snack('Tempo esgotado buscando clientes.');
      return <ParseObject>[];
    } catch (e) {
      _snack('Erro ao buscar clientes: $e');
      return <ParseObject>[];
    }
  }

  Future<void> _openCustomerPicker() async {
    final termCtl = TextEditingController();
    List<ParseObject> results = [];
    bool loading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) {
          Future<void> doSearch() async {
            setDState(() => loading = true);
            results = await _searchCustomers(termCtl.text.trim(), limit: 60);
            setDState(() => loading = false);
          }

          return AlertDialog(
            title: const Text('Selecionar Cliente'),
            content: SizedBox(
              width: 720,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    controller: termCtl,
                    onSubmitted: (_) => doSearch(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome/CPF/telefone/e-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                        ? const Center(child: Text('Nada encontrado'))
                        : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = results[i];
                        final name = c.get<String>('name') ?? '-';
                        final cpf = c.get<String>('cpf') ?? '';
                        final phone = c.get<String>('phone') ?? '';
                        final email = c.get<String>('email') ?? '';
                        final sub = [cpf, phone, email]
                            .where((e) => e.trim().isNotEmpty)
                            .join(' • ');
                        return ListTile(
                          leading:
                          const Icon(Icons.person_outline),
                          title: Text(name),
                          subtitle:
                          sub.isEmpty ? null : Text(sub),
                          onTap: () {
                            setState(() => _selectedCustomer = c);
                            Navigator.of(dctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('Fechar')),
              FilledButton(
                  onPressed: doSearch, child: const Text('Buscar')),
            ],
          );
        },
      ),
    );
  }

  // =============================================================================
  // Busca: PRODUTOS (Repo -> fallback Parse)
  // =============================================================================
  Future<List<ParseObject>> _searchProducts(String term,
      {int limit = 40}) async {
    // 1) tenta via repositório (se existir)
    try {
      final viaRepo = await _prodRepo
          .searchProducts(term, limit: limit)
          .timeout(const Duration(seconds: 12));
      return viaRepo;
    } catch (_) {
      // 2) fallback: QueryBuilder direto no Parse
      try {
        final base = ParseObject('Product');

        if (term.trim().isEmpty) {
          final q = QueryBuilder<ParseObject>(base)
            ..whereEqualTo('active', true)
            ..orderByAscending('name')
            ..setLimit(limit);
          final r = await q.query().timeout(const Duration(seconds: 12));
          if (!r.success) return <ParseObject>[];
          return (r.results ?? []).cast<ParseObject>();
        }

        final nameQ =
        QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereContains('name', term, caseSensitive: false);
        final skuQ =
        QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereContains('sku', term, caseSensitive: false);
        final codeQ =
        QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereContains('code', term, caseSensitive: false);
        final bcQ =
        QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereContains('barcode', term, caseSensitive: false);

        final orQ = QueryBuilder.or(base, [nameQ, skuQ, codeQ, bcQ])
          ..whereEqualTo('active', true)
          ..orderByAscending('name')
          ..setLimit(limit);

        final r = await orQ.query().timeout(const Duration(seconds: 12));
        if (!r.success) return <ParseObject>[];
        return (r.results ?? []).cast<ParseObject>();
      } on TimeoutException {
        _snack('Tempo esgotado buscando produtos.');
        return <ParseObject>[];
      } catch (e) {
        _snack('Erro ao buscar produtos: $e');
        return <ParseObject>[];
      }
    }
  }

  Future<void> _openProductPicker() async {
    final termCtl = TextEditingController();
    List<ParseObject> results = [];
    bool loading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) {
          Future<void> doSearch() async {
            setDState(() => loading = true);
            results =
            await _searchProducts(termCtl.text.trim(), limit: 60);
            setDState(() => loading = false);
          }

          return AlertDialog(
            title: const Text('Selecionar Produto'),
            content: SizedBox(
              width: 720,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    controller: termCtl,
                    onSubmitted: (_) => doSearch(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome/sku/código/barras',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                        ? const Center(child: Text('Nada encontrado'))
                        : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = results[i];
                        final name =
                            p.get<String>('name') ?? '-';
                        final sku = p.get<String>('sku') ??
                            p.get<String>('code') ??
                            p.get<String>('barcode') ??
                            '';
                        final unit =
                            p.get<String>('unit') ?? 'UN';
                        final price = (p.get<num>('price') ?? 0)
                            .toDouble();

                        return ListTile(
                          leading: const Icon(
                              Icons.inventory_2_outlined),
                          title: Text(name),
                          subtitle:
                          Text('Cód: $sku • Unid: $unit'),
                          trailing: Text(_money(price)),
                          onTap: () {
                            setState(() =>
                            _selectedProduct = p);
                            Navigator.of(dctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('Fechar')),
              FilledButton(
                  onPressed: doSearch, child: const Text('Buscar')),
            ],
          );
        },
      ),
    );
  }

  // =============================================================================
  // Pedido (rascunho)
  // =============================================================================
  void _createDraft() {
    if (_selectedCustomer == null) {
      _snack('Selecione um cliente antes.');
      return;
    }
    setState(() {
      _draft = _OrderDraft(
        customerId: _selectedCustomer!.objectId!,
        customerName:
        _selectedCustomer!.get<String>('name') ?? 'Cliente',
      );
    });
  }

  void _addItemToDraft() {
    if (_selectedCustomer == null) {
      _snack('Selecione um cliente.');
      return;
    }
    if (_selectedProduct == null) {
      _snack('Selecione um produto.');
      return;
    }
    if (_qty <= 0) {
      _snack('Quantidade deve ser maior que zero.');
      return;
    }
    _draft ??= _OrderDraft(
      customerId: _selectedCustomer!.objectId!,
      customerName:
      _selectedCustomer!.get<String>('name') ?? 'Cliente',
    );

    final id = _selectedProduct!.objectId!;
    final name = _selectedProduct!.get<String>('name') ?? 'Produto';
    final unit = _selectedProduct!.get<String>('unit') ?? 'UN';
    final price =
    (_selectedProduct!.get<num>('price') ?? 0).toDouble();

    setState(() {
      _draft!.addItem(_OrderItem(
        productId: id,
        name: name,
        unit: unit,
        qty: _qty,
        unitPrice: price,
      ));
    });
  }

  Future<void> _finalizeDraft() async {
    if (_draft == null || _draft!.items.isEmpty) {
      _snack('Crie o pedido e adicione itens.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Finalizar pedido'),
        content: Text(
            'Confirmar finalização?\n\nCliente: ${_draft!.customerName}\nItens: ${_draft!.items.length}\nTotal: ${_money(_draft!.total)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm != true) return;

    final close = _showBlockingOverlay(context, 'Salvando pedido...');
    try {
      // monta objeto Order (com items como array de maps)
      final order = ParseObject('Order')
        ..set<String>('customerName', _draft!.customerName)
        ..set<String>('status', 'open')
        ..set<num>('total', _draft!.total)
        ..set<List<dynamic>>(
          'items',
          _draft!.items
              .map((e) => {
            'productId': e.productId,
            'name': e.name,
            'unit': e.unit,
            'qty': e.qty,
            'unitPrice': e.unitPrice,
          })
              .toList(),
        )
        ..set<ParseObject>(
          'customer',
          (ParseObject('Customer')..objectId = _draft!.customerId),
        );

      final resp =
      await order.save().timeout(const Duration(seconds: 18));
      if (!resp.success) {
        throw resp.error?.message ?? 'Falha ao salvar pedido.';
      }

      final id = (resp.results?.first as ParseObject).objectId!;

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Pedido salvo'),
          content: Text(
              'Pedido #${id.substring(0, 6).toUpperCase()} salvo com sucesso!\nTotal: ${_money(_draft!.total)}'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(dctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );

      // limpa rascunho e recarrega "últimos pedidos"
      setState(() {
        _draft = null;
      });
      await _loadRecentOrders();
    } on TimeoutException {
      _snack('Tempo esgotado ao salvar pedido.');
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      close();
    }
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _loadingRecent = true);
    try {
      final q = QueryBuilder<ParseObject>(ParseObject('Order'))
        ..orderByDescending('createdAt')
        ..setLimit(20);
      final r = await q.query().timeout(const Duration(seconds: 12));
      if (r.success) {
        setState(() => _recentOrders =
            (r.results ?? []).cast<ParseObject>());
      } else {
        setState(() => _recentOrders = []);
      }
    } catch (_) {
      setState(() => _recentOrders = []);
    } finally {
      setState(() => _loadingRecent = false);
    }
  }

  // =============================================================================
  // UI
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [cs.primary, cs.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _openCustomerPicker,
            icon: const Icon(Icons.person_search),
            label: Text(_selectedCustomer == null
                ? 'Selecione o cliente'
                : _selectedCustomer!.get<String>('name') ?? 'Cliente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _openProductPicker,
            icon: const Icon(Icons.search),
            label: Text(_selectedProduct == null
                ? 'Selecione o produto'
                : (_selectedProduct!.get<String>('name') ?? 'Produto')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Qtd:',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 220,
                  child: Slider(
                    value: _qty,
                    min: 1,
                    max: 999,
                    divisions: 998,
                    label: _fmtQty(_qty),
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_fmtQty(_qty),
                      style:
                      const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
              onPressed: _createDraft,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Criar pedido')),
          const SizedBox(width: 8),
          FilledButton.icon(
              onPressed: _addItemToDraft,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Adicionar item')),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
              onPressed: () => _snack('Reserva FEFO: em breve'),
              icon: const Icon(Icons.safety_check),
              label: const Text('Reservar (FEFO)')),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed:
            (_draft != null && _draft!.items.isNotEmpty) ? _finalizeDraft : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Finalizar pedido'),
          ),
        ],
      ),
    );

    final leftDraft = Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeader('Pedido em edição'),
              Expanded(
                child: _draft == null
                    ? const Center(
                    child: Text('Nenhum pedido em edição'))
                    : ListView.separated(
                  itemCount: _draft!.items.length + 1,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return ListTile(
                        title: Text(
                            'Cliente: ${_draft!.customerName}'),
                        subtitle: Text(
                            'Itens: ${_draft!.items.length} • Total: ${_money(_draft!.total)}'),
                      );
                    }
                    final it = _draft!.items[i - 1];
                    return ListTile(
                      leading: const Icon(
                          Icons.inventory_2_outlined),
                      title: Text(it.name),
                      subtitle: Text(
                          '${_fmtQty(it.qty)} ${it.unit}  •  ${_money(it.unitPrice)}'),
                      trailing: Text(
                        _money(it.qty * it.unitPrice),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final rightLatest = Expanded(
      flex: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeader('Últimos pedidos'),
              Expanded(
                child: _loadingRecent
                    ? const Center(
                    child: CircularProgressIndicator())
                    : _recentOrders.isEmpty
                    ? const Center(
                    child: Text(
                        'Nenhum pedido encontrado'))
                    : ListView.separated(
                  itemCount: _recentOrders.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context)
                          .dividerColor),
                  itemBuilder: (_, i) {
                    final o = _recentOrders[i];
                    final id = o.objectId ?? '';
                    final customerName =
                        o.get<String>('customerName') ??
                            'Cliente';
                    final total =
                    (o.get<num>('total') ?? 0)
                        .toDouble();
                    final items =
                        (o.get<List>('items') ?? [])
                            .length;
                    final status =
                        o.get<String>('status') ?? '-';
                    return ListTile(
                      title: Text(
                          '#${id.substring(0, 6).toUpperCase()} • $customerName'),
                      subtitle:
                      Text('Itens: $items • Status: $status'),
                      trailing: Text(_money(total),
                          style: const TextStyle(
                              fontWeight:
                              FontWeight.w700)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: Row(
              children: [leftDraft, rightLatest],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child:
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================================
// Modelos simples do rascunho (somente UI/cliente)
// ============================================================================
class _OrderDraft {
  _OrderDraft({required this.customerId, required this.customerName});
  final String customerId;
  final String customerName;
  final List<_OrderItem> items = [];

  void addItem(_OrderItem it) {
    // se já existir o mesmo produto, soma quantidade
    final idx = items.indexWhere((e) =>
    e.productId == it.productId &&
        e.unit == it.unit &&
        e.unitPrice == it.unitPrice);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(qty: items[idx].qty + it.qty);
    } else {
      items.add(it);
    }
  }

  double get total =>
      items.fold(0.0, (p, e) => p + e.qty * e.unitPrice);
}

class _OrderItem {
  const _OrderItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
  });

  final String productId;
  final String name;
  final String unit;
  final double qty;
  final double unitPrice;

  _OrderItem copyWith({
    String? productId,
    String? name,
    String? unit,
    double? qty,
    double? unitPrice,
  }) {
    return _OrderItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

// ===== Overlay progress (mesmo padrão do PDV) =================================
VoidCallback _showBlockingOverlay(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  var removed = false;

  entry = OverlayEntry(
    builder: (_) => Stack(children: [
      const ModalBarrier(dismissible: false, color: Colors.black54),
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4)),
              const SizedBox(width: 12),
              Flexible(child: Text(message)),
            ]),
          ),
        ),
      ),
    ]),
  );

  overlay.insert(entry);

  final timer = Timer(const Duration(seconds: 20), () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
  });
  return () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
    timer.cancel();
  };
}
