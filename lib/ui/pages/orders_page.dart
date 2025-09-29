// lib/ui/pages/orders_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
                        final cpf = c.get<String>('cpf') ?? c.get<String>('cpfCnpj') ?? '';
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

  // ====== Limite de crédito (cliente) ======
  bool _violatesCreditLimit(double total) {
    if (_selectedCustomer == null) return false; // sem cliente não valida
    final limit = (_selectedCustomer!.get<num>('creditLimit') ?? 0).toDouble();
    final open  = (_selectedCustomer!.get<num>('balance') ?? 0).toDouble();
    final available = (limit - open);
    return total > available && limit > 0; // só bloqueia se há limite configurado
  }

  Future<void> _finalizeDraft() async {
    if (_draft == null || _draft!.items.isEmpty) {
      _snack('Crie o pedido e adicione itens.');
      return;
    }

    // Valida limite de crédito
    if (_violatesCreditLimit(_draft!.total)) {
      final limit = (_selectedCustomer!.get<num>('creditLimit') ?? 0).toDouble();
      final open  = (_selectedCustomer!.get<num>('balance') ?? 0).toDouble();
      final available = (limit - open);
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Limite de crédito'),
          content: Text(
              'Total do pedido: ${_money(_draft!.total)}\n'
                  'Disponível: ${_money(available)}\n\n'
                  'O total excede o limite de crédito do cliente.'),
          actions: [
            FilledButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(_draft!.editingOrderId == null ? 'Finalizar pedido' : 'Atualizar pedido'),
        content: Text(
            'Confirmar ${_draft!.editingOrderId == null ? 'finalização' : 'atualização'}?\n\nCliente: ${_draft!.customerName}\nItens: ${_draft!.items.length}\nTotal: ${_money(_draft!.total)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(_draft!.editingOrderId == null ? 'Finalizar' : 'Salvar')),
        ],
      ),
    );
    if (confirm != true) return;

    final close = _showBlockingOverlay(context, _draft!.editingOrderId == null ? 'Salvando pedido...' : 'Salvando alterações...');
    try {
      // monta itens
      final itemsArr = _draft!.items
          .map((e) => {
        'productId': e.productId,
        'name': e.name,
        'unit': e.unit,
        'qty': e.qty,
        'unitPrice': e.unitPrice,
      })
          .toList();

      if (_draft!.editingOrderId != null) {
        // ====== atualizar pedido existente ======
        final order = ParseObject('Order')..objectId = _draft!.editingOrderId!;
        order
          ..set<String>('customerName', _draft!.customerName)
          ..set<num>('total', _draft!.total)
          ..set<List<dynamic>>('items', itemsArr)
          ..set<ParseObject>('customer', ParseObject('Customer')..objectId = _draft!.customerId);
        final resp = await order.save().timeout(const Duration(seconds: 18));
        if (!resp.success) {
          throw resp.error?.message ?? 'Falha ao salvar alterações.';
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Pedido atualizado'),
            content: Text('Alterações salvas com sucesso!\nTotal: ${_money(_draft!.total)}'),
            actions: [
              FilledButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('OK')),
            ],
          ),
        );

        // opcional: re-gerar boleto (se desejar manter o comportamento)
        final boleto = await _createBoleto(_draft!.editingOrderId!, _draft!.total, _draft!.customerId);
        if (boleto != null && mounted) {
          await _showBoletoDialog(boleto);
        }
      } else {
        // ====== criar novo pedido (fluxo existente) ======
        final order = ParseObject('Order')
          ..set<String>('customerName', _draft!.customerName)
          ..set<String>('status', 'open')
          ..set<num>('total', _draft!.total)
          ..set<List<dynamic>>('items', itemsArr)
          ..set<ParseObject>('customer', (ParseObject('Customer')..objectId = _draft!.customerId));

        final resp = await order.save().timeout(const Duration(seconds: 18));
        if (!resp.success) {
          throw resp.error?.message ?? 'Falha ao salvar pedido.';
        }

        final saved = (resp.results?.first as ParseObject);
        final id = saved.objectId!;

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

        // === Gere o boleto automaticamente ===
        final boleto = await _createBoleto(id, _draft!.total, _draft!.customerId);
        if (boleto != null && mounted) {
          await _showBoletoDialog(boleto);
        }
      }

      // limpa rascunho e recarrega "últimos pedidos"
      setState(() {
        _draft = null;
      });
      await _loadRecentOrders();
    } on TimeoutException {
      _snack('Tempo esgotado ao salvar.');
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

  // ==== chama cloud para gerar boleto ====
  Future<_BoletoInfo?> _createBoleto(String orderId, double amount, String customerId) async {
    try {
      final fn = ParseCloudFunction('mpCreateBoleto');
      final resp = await fn.execute(parameters: {
        'orderId': orderId,
        'amount': amount,
        'customerId': customerId,
        'description': 'Pedido $orderId',
        'daysToExpire': 3,
      }).timeout(const Duration(seconds: 20));

      if (resp.success && resp.result is Map) {
        final m = (resp.result as Map).cast<String, dynamic>();
        final url = (m['boleto_url'] ?? m['external_resource_url'] ?? m['pdf_url'])?.toString();
        final status = (m['status'] ?? 'pending').toString();
        final barcode = (m['barcode'] ?? '').toString();
        return _BoletoInfo(url: url, status: status, barcode: barcode);
      } else {
        _snack('Falha ao gerar boleto.');
      }
    } catch (e) {
      _snack('Erro ao gerar boleto: $e');
    }
    return null;
  }

  Future<void> _showBoletoDialog(_BoletoInfo boleto) async {
    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Boleto gerado'),
        content: Text('Link do boleto pronto para o cliente.\nStatus: ${boleto.status ?? 'pending'}'),
        actions: [
          TextButton(
            onPressed: () async {
              final url = boleto.url!;
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) {
                Navigator.of(dctx).pop();
                _snack('Link copiado.');
              }
            },
            child: const Text('Copiar link'),
          ),
          FilledButton(
            onPressed: () async {
              final url = boleto.url!;
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Abrir boleto (PDF)'),
          ),
        ],
      ),
    );
  }

  // ======= AÇÕES SOBRE UM PEDIDO LISTADO (menu contextual) =======
  Future<void> _openOrderActions(ParseObject o) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final id = o.objectId ?? '';
        final boletoUrl = (o.get<String>('boletoUrl') ?? '').trim();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar pedido'),
                subtitle: Text('#${id.substring(0,6).toUpperCase()}'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _loadOrderIntoDraft(o);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(boletoUrl.isEmpty ? 'Gerar boleto' : 'Abrir boleto (reimprimir)'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _openOrCreateBoleto(o);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: const Text('Copiar link do boleto'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final url = (o.get<String>('boletoUrl') ?? '').trim();
                  if (url.isEmpty) {
                    _snack('Pedido ainda não possui boleto.');
                    return;
                  }
                  await Clipboard.setData(ClipboardData(text: url));
                  _snack('Link copiado.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('Alterar status / pagamento'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _changeOrderStatus(o);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openOrCreateBoleto(ParseObject o) async {
    final orderId = o.objectId!;
    final urlSaved = (o.get<String>('boletoUrl') ?? '').trim();
    if (urlSaved.isNotEmpty) {
      final uri = Uri.tryParse(urlSaved);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final total = (o.get<num>('total') ?? 0).toDouble();
    final custRef = o.get<ParseObject>('customer');
    final custId = custRef?.objectId ?? '';
    final boleto = await _createBoleto(orderId, total, custId);
    if (boleto != null) await _showBoletoDialog(boleto);
  }

  Future<void> _changeOrderStatus(ParseObject o) async {
    String status = (o.get<String>('status') ?? 'open').toLowerCase();
    String payStatus = (o.get<String>('paymentStatus') ?? 'pending').toLowerCase();
    String payMethod = (o.get<String>('paymentMethod') ?? '').toUpperCase();

    final statusOpts = ['open','done','cancelled'];
    final payStatusOpts = ['pending','approved','cancelled','rejected','expired'];
    final payMethodOpts = ['','BOLETO','PIX','DINHEIRO','CARTAO','OUTRO'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Alterar status / pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dropdownRow('Status', status, statusOpts, (v)=> status=v),
            const SizedBox(height: 8),
            _dropdownRow('Situação do pagamento', payStatus, payStatusOpts, (v)=> payStatus=v),
            const SizedBox(height: 8),
            _dropdownRow('Forma de pagamento', payMethod, payMethodOpts, (v)=> payMethod=v.toUpperCase()),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: ()=>Navigator.of(dctx).pop(true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok != true) return;

    final close = _showBlockingOverlay(context, 'Atualizando...');
    try {
      final order = ParseObject('Order')..objectId = o.objectId!;
      order
        ..set<String>('status', status)
        ..set<String>('paymentStatus', payStatus)
        ..set<String>('paymentMethod', payMethod);
      final resp = await order.save().timeout(const Duration(seconds: 12));
      if (!resp.success) throw resp.error?.message ?? 'Falha ao atualizar.';
      _snack('Atualizado.');
      await _loadRecentOrders();
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      close();
    }
  }

  Widget _dropdownRow(String label, String value, List<String> options, void Function(String) onChanged) {
    return Row(
      children: [
        SizedBox(width: 170, child: Text(label)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: options.contains(value) ? value : options.first,
            items: options.map((e)=>DropdownMenuItem(value:e,child: Text(e.toUpperCase()))).toList(),
            onChanged: (v){ if(v!=null) onChanged(v); },
          ),
        ),
      ],
    );
  }

  Future<void> _loadOrderIntoDraft(ParseObject o) async {
    final items = (o.get<List>('items') ?? []).cast<dynamic>();
    final custRef = o.get<ParseObject>('customer');
    final custId = custRef?.objectId ?? '';
    final custName = o.get<String>('customerName') ?? 'Cliente';

    final d = _OrderDraft(customerId: custId, customerName: custName, editingOrderId: o.objectId);
    for (final raw in items) {
      if (raw is Map) {
        final m = raw.cast<String, dynamic>();
        d.addItem(_OrderItem(
          productId: (m['productId'] ?? '').toString(),
          name: (m['name'] ?? 'Produto').toString(),
          unit: (m['unit'] ?? 'UN').toString(),
          qty: (m['qty'] is num) ? (m['qty'] as num).toDouble() : double.tryParse('${m['qty']}') ?? 0,
          unitPrice: (m['unitPrice'] is num) ? (m['unitPrice'] as num).toDouble() : double.tryParse('${m['unitPrice']}') ?? 0,
        ));
      }
    }

    setState(() {
      _draft = d;
      // Também posiciona o cliente selecionado para manter a consistência do cabeçalho
      _selectedCustomer = custRef;
    });

    _snack('Pedido carregado para edição.');
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
            label: Text(_draft?.editingOrderId == null ? 'Finalizar pedido' : 'Salvar alterações'),
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
                        trailing: _draft!.editingOrderId == null
                            ? null
                            : const Chip(label: Text('Edição')),
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
                      onTap: () => _openOrderActions(o),
                      title: Text(
                          '#${id.substring(0, 6).toUpperCase()} • $customerName'),
                      subtitle:
                      Text('Itens: $items • Status: $status'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_money(total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            tooltip: 'Ações',
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _loadOrderIntoDraft(o);
                              } else if (v == 'boleto') {
                                await _openOrCreateBoleto(o);
                              } else if (v == 'copy') {
                                final url = (o.get<String>('boletoUrl') ?? '').trim();
                                if (url.isEmpty) {
                                  _snack('Sem boleto ainda.');
                                } else {
                                  await Clipboard.setData(ClipboardData(text: url));
                                  _snack('Link copiado.');
                                }
                              } else if (v == 'status') {
                                await _changeOrderStatus(o);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                              const PopupMenuItem(value: 'boleto', child: ListTile(leading: Icon(Icons.print_outlined), title: Text('Abrir/gerar boleto'))),
                              const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.link_outlined), title: Text('Copiar link do boleto'))),
                              const PopupMenuItem(value: 'status', child: ListTile(leading: Icon(Icons.rule_folder_outlined), title: Text('Alterar status'))),
                            ],
                          ),
                        ],
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
  _OrderDraft({required this.customerId, required this.customerName, this.editingOrderId});
  final String customerId;
  final String customerName;
  final String? editingOrderId;
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

class _BoletoInfo {
  final String? url;
  final String? status;
  final String? barcode;
  _BoletoInfo({this.url, this.status, this.barcode});
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
