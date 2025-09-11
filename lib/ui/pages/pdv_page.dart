// lib/ui/pages/pdv_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

enum _PdvStage { items, payment, finish }
enum _PayMethod {
  cash, // F1
  check, // F2
  cardCredit, // F3
  cardDebit, // F4
  storeCredit, // F5
  foodVoucher, // F6
  mealVoucher, // F7
  giftCard, // F8
  fuelVoucher, // F9
  other, // F10
  pix, // P
  mercadoPago, // M
}

class PdvPage extends StatefulWidget {
  const PdvPage({super.key});
  static const route = '/pdv';

  @override
  State<PdvPage> createState() => _PdvPageState();
}

class _PdvPageState extends State<PdvPage> {
  final FocusNode _focusNode = FocusNode();
  final _repo = ProductRepository();

  // Busca
  final TextEditingController _codeCtl = TextEditingController();

  // Desconto e recebido
  double _discount = 0.0;
  double _received = 0.0;

  // Tabela
  final List<_PdvItem> _items = [];
  int? _selectedIndex;

  // Etapas / pagamento
  _PdvStage _stage = _PdvStage.items;
  _PayMethod? _selectedMethod;

  // UI
  String _priceTier = 'Preço Padrão';

  // ===== Helpers base ========================================================
  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtQty(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // Parser robusto (BR/US): "1.234,56" => 1234.56; "1,50" => 1.50
  double _parseDecimal(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0.0;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0.0;
  }

  double get _subtotal => _items.fold(0.0, (p, e) => p + (e.qty * e.unitPrice));
  double get _total => math.max(0, _subtotal - _discount);
  double get _change => math.max(0, _received - _total);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  // ====================== Produtos ==========================================
  Future<void> _addByCodeOrSearch() async {
    final term = _codeCtl.text.trim();
    if (term.isEmpty) {
      _openLookupDialog();
      return;
    }

    final close = _showBlockingOverlay(context, 'Buscando produto...');
    try {
      final p = await _repo.findByAnyCode(term).timeout(const Duration(seconds: 12));
      if (p == null) {
        _snack('Produto não encontrado.');
        return;
      }
      _addProductParse(p);
      _codeCtl.clear();
    } on TimeoutException {
      _snack('Tempo esgotado na busca. Tente novamente.');
    } catch (e) {
      _snack('Erro na busca: $e');
    } finally {
      close();
    }
  }

  void _addProductParse(ParseObject p) {
    final name = p.get<String>('name') ?? 'Produto';
    final price = (p.get<num>('price') ?? 0).toDouble();
    final id = p.objectId!;
    final imageUrl = p.get<ParseFileBase>('image')?.url;

    setState(() {
      // se já existe, só soma 1
      final idx = _items.indexWhere((e) => e.productId == id);
      if (idx >= 0) {
        _items[idx].qty += 1;
        _selectedIndex = idx;
      } else {
        _items.add(_PdvItem(
          productId: id,
          name: name,
          qty: 1,
          unitPrice: price,
          imageUrl: imageUrl,
        ));
        _selectedIndex = _items.length - 1;
      }
    });
  }

  Future<void> _openLookupDialog() async {
    final termCtl = TextEditingController(text: _codeCtl.text);
    List<ParseObject> results = [];
    bool loading = false;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) {
          Future<void> doSearchLocal() async {
            setDState(() => loading = true);
            try {
              results = await _repo.searchProducts(termCtl.text.trim(), limit: 40);
            } catch (_) {
              results = [];
            } finally {
              setDState(() => loading = false);
            }
          }

          return AlertDialog(
            title: const Text('Buscar Produto (F2)'),
            content: SizedBox(
              width: 580,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: termCtl,
                    onSubmitted: (_) => doSearchLocal(),
                    decoration: const InputDecoration(
                      hintText: 'Digite nome/sku/código de barras',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                        ? const Center(child: Text('Sem resultados'))
                        : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = results[i];
                        final name = p.get<String>('name') ?? '';
                        final price = (p.get<num>('price') ?? 0).toDouble();
                        final sku = p.get<String>('sku') ??
                            p.get<String>('barcode') ??
                            p.get<String>('code') ??
                            '';
                        final imageUrl = p.get<ParseFileBase>('image')?.url;
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: imageUrl == null
                                ? Container(
                              width: 40,
                              height: 40,
                              color: Colors.black12,
                              child: const Icon(Icons.inventory_2, size: 22),
                            )
                                : Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                          ),
                          title: Text(name),
                          subtitle: Text('SKU: $sku'),
                          trailing: Text(_money(price)),
                          onTap: () {
                            Navigator.of(dctx).pop();
                            _addProductParse(p);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Fechar')),
              FilledButton(onPressed: doSearchLocal, child: const Text('Buscar')),
            ],
          );
        },
      ),
    );
  }

  // Manuais/edição
  Future<void> _addManualDialog() async {
    final nameCtl = TextEditingController();
    final qtyCtl = TextEditingController(text: '1');
    final priceCtl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Adicionar Produto (F3)'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Nome do produto'), controller: nameCtl),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor unitário'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Adicionar')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtl.text.trim();
      final qty = _parseDecimal(qtyCtl.text);
      final price = _parseDecimal(priceCtl.text);
      if (name.isEmpty || qty <= 0) return;
      setState(() {
        _items.add(_PdvItem(productId: null, name: name, qty: qty, unitPrice: price));
        _selectedIndex = _items.length - 1;
      });
    }
  }

  Future<void> _editQty(int i) async {
    final ctl = TextEditingController(text: _fmtQty(_items[i].qty));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Alterar quantidade (F4)'),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantidade'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v > 0) setState(() => _items[i].qty = v);
    }
  }

  Future<void> _editUnit(int i) async {
    final ctl = TextEditingController(text: _items[i].unitPrice.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Alterar valor unitário (F5)'),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor unitário'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v >= 0) setState(() => _items[i].unitPrice = v);
    }
  }

  Future<void> _editDiscount() async {
    final ctl = TextEditingController(text: _discount.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Desconto (F10)'),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor do desconto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v >= 0) setState(() => _discount = v);
    }
  }

  // ====================== Finalização / pagamento ============================
  void _goPayment() {
    if (_items.isEmpty) {
      _snack('Inclua pelo menos um produto.');
      return;
    }
    setState(() {
      _stage = _PdvStage.payment;
      _selectedMethod = null;
      _received = 0;
    });
  }

  void _selectMethod(_PayMethod m) {
    setState(() {
      _selectedMethod = m;
      _stage = _PdvStage.finish;
      _received = _total; // pré-preenche
    });
  }

  Future<void> _finalizeSale() async {
    if (_items.isEmpty) {
      _snack('Inclua itens.');
      return;
    }
    if (_selectedMethod == null) {
      _snack('Escolha a forma de pagamento.');
      return;
    }

    final close = _showBlockingOverlay(context, 'Finalizando venda...');
    try {
      final fn = ParseCloudFunction('finalizeSale');
      final resp = await fn.execute(parameters: {
        'items': _items
            .map((e) => {
          'productId': e.productId,
          'qty': e.qty,
          'unitPrice': e.unitPrice,
        })
            .toList(),
        'discount': _discount,
        'paymentMethod': _methodString(_selectedMethod!),
        'received': _received,
      }).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      if (resp.success) {
        close(); // fecha overlay antes do diálogo
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (dctx) => AlertDialog(
            title: const Text('Venda concluída'),
            content: Text('Total: ${_money((resp.result?['total'] ?? _total) as num)}'),
            actions: [FilledButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('OK'))],
          ),
        );
        if (!mounted) return;
        setState(() {
          _items.clear();
          _discount = 0;
          _received = 0;
          _codeCtl.clear();
          _selectedIndex = null;
          _selectedMethod = null;
          _stage = _PdvStage.items;
        });
      } else {
        throw resp.error?.message ?? 'Falha ao finalizar venda';
      }
    } on TimeoutException {
      _snack('Tempo esgotado ao finalizar. Verifique a conexão.');
      close();
    } catch (e) {
      close();
      _snack('Erro: $e');
    }
  }

  String _methodString(_PayMethod m) {
    switch (m) {
      case _PayMethod.cash:
        return 'CASH';
      case _PayMethod.pix:
        return 'PIX';
      case _PayMethod.cardCredit:
        return 'CARD_CREDIT';
      case _PayMethod.cardDebit:
        return 'CARD_DEBIT';
      case _PayMethod.check:
        return 'CHECK';
      case _PayMethod.storeCredit:
        return 'STORE_CREDIT';
      case _PayMethod.foodVoucher:
        return 'FOOD_VOUCHER';
      case _PayMethod.mealVoucher:
        return 'MEAL_VOUCHER';
      case _PayMethod.giftCard:
        return 'GIFT_CARD';
      case _PayMethod.fuelVoucher:
        return 'FUEL_VOUCHER';
      case _PayMethod.other:
        return 'OTHER';
      case _PayMethod.mercadoPago:
        return 'MERCADO_PAGO';
    }
  }

  // ====================== Atalhos ===========================================
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (_stage == _PdvStage.items) {
      if (k == LogicalKeyboardKey.f2) {
        _openLookupDialog();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f3) {
        _addManualDialog();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f4 && _selectedIndex != null) {
        _editQty(_selectedIndex!);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f5 && _selectedIndex != null) {
        _editUnit(_selectedIndex!);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f6 && _selectedIndex != null) {
        setState(() => _items.removeAt(_selectedIndex!));
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f8) {
        _goPayment();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f10) {
        _editDiscount();
        return KeyEventResult.handled;
      }
    } else if (_stage == _PdvStage.payment) {
      if (k == LogicalKeyboardKey.f1) {
        _selectMethod(_PayMethod.cash);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f2) {
        _selectMethod(_PayMethod.check);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f3) {
        _selectMethod(_PayMethod.cardCredit);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f4) {
        _selectMethod(_PayMethod.cardDebit);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f5) {
        _selectMethod(_PayMethod.storeCredit);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f6) {
        _selectMethod(_PayMethod.foodVoucher);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f7) {
        _selectMethod(_PayMethod.mealVoucher);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f8) {
        _selectMethod(_PayMethod.giftCard);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f9) {
        _selectMethod(_PayMethod.fuelVoucher);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f10) {
        _selectMethod(_PayMethod.other);
        return KeyEventResult.handled;
      }
      if (k.keyLabel.toUpperCase() == 'P') {
        _selectMethod(_PayMethod.pix);
        return KeyEventResult.handled;
      }
      if (k.keyLabel.toUpperCase() == 'M') {
        _selectMethod(_PayMethod.mercadoPago);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f11) {
        setState(() => _stage = _PdvStage.items);
        return KeyEventResult.handled;
      }
    } else if (_stage == _PdvStage.finish) {
      if (k == LogicalKeyboardKey.f11) {
        setState(() => _stage = _PdvStage.payment);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.f8 || k == LogicalKeyboardKey.f12) {
        _finalizeSale();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ====================== UI =================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            _Header(priceTier: _priceTier, stage: _stage),
            const SizedBox(height: 8),
            if (_stage == _PdvStage.items) ...[
              _SearchBar(
                controller: _codeCtl,
                onSubmitted: _addByCodeOrSearch,
                onAddManual: _addManualDialog,
                onLookup: _openLookupDialog,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _ItemsTable(
                  items: _items,
                  selectedIndex: _selectedIndex,
                  onSelect: (i) => setState(() => _selectedIndex = i),
                  onInc: (i) => setState(() => _items[i].qty += 1),
                  onDec: (i) => setState(() => _items[i].qty = math.max(0.0, _items[i].qty - 1)),
                  onEditQty: _editQty,
                  onEditUnit: _editUnit,
                  onRemove: (i) {
                    setState(() {
                      _items.removeAt(i);
                      if (_selectedIndex == i) _selectedIndex = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              _FooterItems(
                itemsCount: _items.length,
                discount: _discount,
                subtotal: _subtotal,
                total: _total,
                onDiscount: _editDiscount,
                onProceed: _goPayment,
              ),
              const SizedBox(height: 6),
              _ShortcutsStripItems(),
              const SizedBox(height: 8),
            ] else if (_stage == _PdvStage.payment) ...[
              Expanded(child: _PaymentGrid(onSelect: _selectMethod)),
              const SizedBox(height: 6),
              _BottomNavBack(text: 'VOLTAR (F11)', onBack: () => setState(() => _stage = _PdvStage.items)),
              const SizedBox(height: 12),
            ] else ...[
              _FinishForm(
                method: _selectedMethod!,
                total: _total,
                received: _received,
                change: _change,
                onReceivedChanged: (v) => setState(() => _received = v),
                onFinalize: _finalizeSale,
                onBack: () => setState(() => _stage = _PdvStage.payment),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// ===== Header / Steps ========================================================
class _Header extends StatelessWidget {
  const _Header({required this.priceTier, required this.stage});
  final String priceTier;
  final _PdvStage stage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color dot(bool active) => active ? Colors.white : Colors.white.withOpacity(.55);
    return Container(
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
        children: [
          Text('$_Header', style: const TextStyle(fontSize: 0)), // evita warning
          const SizedBox(height: 4),
          const Text('Preço Padrão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            children: [
              _StepDot(label: 'Nova venda', color: dot(stage == _PdvStage.items)),
              _StepDot(label: 'Forma de pagamento', color: dot(stage == _PdvStage.payment)),
              _StepDot(label: 'Finalizar venda', color: dot(stage == _PdvStage.finish)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ===== Search / Items ========================================================
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted, required this.onAddManual, required this.onLookup});
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onAddManual;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.qr_code_scanner),
                hintText: 'Informe o código/sku/barras e pressione Enter ou use F2 para buscar…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), tooltip: 'Buscar (F2)', onPressed: onLookup),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddManual,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('ADICIONAR PRODUTO (F3)'),
          )
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onInc,
    required this.onDec,
    required this.onEditQty,
    required this.onEditUnit,
    required this.onRemove,
  });
  final List<_PdvItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onInc;
  final ValueChanged<int> onDec;
  final ValueChanged<int> onEditQty;
  final ValueChanged<int> onEditUnit;
  final ValueChanged<int> onRemove;

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtQty(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  _HCell(width: 64, child: Text('Nº', style: headerStyle)),
                  _HCell(flex: 3, child: Text('Nome do Produto', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Quantidade (F4)', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Valor Unitário (F5)', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Valor Total', style: headerStyle)),
                  _HCell(width: 56, child: const SizedBox()),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Nenhum item adicionado'))
                  : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final selected = i == selectedIndex;
                  return InkWell(
                    onTap: () => onSelect(i),
                    child: Container(
                      color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _HCell(width: 64, child: Text('${i + 1}')),
                          _HCell(
                            flex: 3,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: it.imageUrl != null
                                      ? Image.network(it.imageUrl!, width: 36, height: 36, fit: BoxFit.cover)
                                      : Container(
                                    width: 36,
                                    height: 36,
                                    color: Colors.black12,
                                    child: const Icon(Icons.inventory_2, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: Row(
                              children: [
                                IconButton(onPressed: () => onDec(i), icon: const Icon(Icons.remove_circle_outline)),
                                GestureDetector(
                                  onTap: () => onEditQty(i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_fmtQty(it.qty)),
                                  ),
                                ),
                                IconButton(onPressed: () => onInc(i), icon: const Icon(Icons.add_circle_outline)),
                              ],
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () => onEditUnit(i),
                              child: Align(alignment: Alignment.centerLeft, child: Text(_money(it.unitPrice))),
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: Text(_money(it.qty * it.unitPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          _HCell(width: 56, child: IconButton(onPressed: () => onRemove(i), icon: const Icon(Icons.delete_outline))),
                        ],
                      ),
                    ),
                  );
                },
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

class _FooterItems extends StatelessWidget {
  const _FooterItems({
    required this.itemsCount,
    required this.discount,
    required this.subtotal,
    required this.total,
    required this.onDiscount,
    required this.onProceed,
  });

  final int itemsCount;
  final double discount;
  final double subtotal;
  final double total;
  final VoidCallback onDiscount;
  final VoidCallback onProceed;

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          _InfoTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: 'Operante', subtitle: 'Status SEFAZ'),
          const SizedBox(width: 12),
          _InfoTile(title: '$itemsCount', subtitle: 'Item${itemsCount == 1 ? '' : 's'}'),
          const SizedBox(width: 12),
          Expanded(child: InkWell(onTap: onDiscount, borderRadius: BorderRadius.circular(14), child: _InfoTile(title: _money(discount), subtitle: 'Desconto (F10)'))),
          const SizedBox(width: 12),
          _InfoTile(title: _money(total), subtitle: 'Total'),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('FINALIZAR (F8)'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({this.leading, required this.title, required this.subtitle});
  final Widget? leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
          ])
        ],
      ),
    );
  }
}

class _ShortcutsStripItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: const [
          _KbdHint('F2', 'Buscar Produto'),
          _KbdHint('F3', 'Adicionar Produto'),
          _KbdHint('F4', 'Alterar quantidade'),
          _KbdHint('F5', 'Alterar valor'),
          _KbdHint('F6', 'Remover produto'),
          _KbdHint('F8', 'Prosseguir'),
          _KbdHint('F10', 'Desconto'),
        ],
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  const _KbdHint(this.k, this.label);
  final String k;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: cs.outlineVariant)),
        child: Text(k, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

// ===== Payment grid ==========================================================
class _PaymentGrid extends StatelessWidget {
  const _PaymentGrid({required this.onSelect});
  final ValueChanged<_PayMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile(String label, IconData icon, _PayMethod m, {String? hint}) {
      return InkWell(
        onTap: () => onSelect(m),
        child: Container(
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(.25),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (hint != null) Text(hint, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    }

    final tiles = [
      tile('Dinheiro', Icons.attach_money, _PayMethod.cash, hint: 'F1'),
      tile('Cheque', Icons.receipt_long, _PayMethod.check, hint: 'F2'),
      tile('Cartão de Crédito', Icons.credit_card, _PayMethod.cardCredit, hint: 'F3'),
      tile('Cartão de Débito', Icons.credit_card_rounded, _PayMethod.cardDebit, hint: 'F4'),
      tile('Crédito Loja', Icons.store, _PayMethod.storeCredit, hint: 'F5'),
      tile('Vale Alimentação', Icons.lunch_dining, _PayMethod.foodVoucher, hint: 'F6'),
      tile('Vale Refeição', Icons.restaurant, _PayMethod.mealVoucher, hint: 'F7'),
      tile('Vale Presente', Icons.card_giftcard, _PayMethod.giftCard, hint: 'F8'),
      tile('Vale Combustível', Icons.local_gas_station, _PayMethod.fuelVoucher, hint: 'F9'),
      tile('Outros', Icons.payments, _PayMethod.other, hint: 'F10'),
      tile('PIX', Icons.qr_code_2, _PayMethod.pix, hint: 'P'),
      tile('Mercado Pago', Icons.account_balance_wallet, _PayMethod.mercadoPago, hint: 'M'),
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.count(
        crossAxisCount: 6,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        children: tiles,
      ),
    );
  }
}

class _BottomNavBack extends StatelessWidget {
  const _BottomNavBack({required this.text, required this.onBack});
  final String text;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: Text(text)),
    );
  }
}

// ===== Finish form ===========================================================
class _FinishForm extends StatelessWidget {
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

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController(text: received.toStringAsFixed(2).replaceAll('.', ','));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_title(method), style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctl,
                    onChanged: (t) => onReceivedChanged(_parseFinish(t)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor recebido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: onBack, icon: const Icon(Icons.arrow_back), tooltip: 'Voltar (F11)'),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: onFinalize, icon: const Icon(Icons.check), label: const Text('FINALIZAR (F12/F8)')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _FinishCard(title: _money(total), subtitle: 'Valor total do pedido'),
                const SizedBox(width: 12),
                _FinishCard(title: _money(received), subtitle: 'Valor recebido'),
                const SizedBox(width: 12),
                _FinishCard(title: _money(change), subtitle: 'Troco'),
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
      case _PayMethod.cash:
        return '1 - Dinheiro';
      case _PayMethod.check:
        return '1 - Cheque';
      case _PayMethod.cardCredit:
        return '1 - Cartão de Crédito';
      case _PayMethod.cardDebit:
        return '1 - Cartão de Débito';
      case _PayMethod.storeCredit:
        return '1 - Crédito Loja';
      case _PayMethod.foodVoucher:
        return '1 - Vale Alimentação';
      case _PayMethod.mealVoucher:
        return '1 - Vale Refeição';
      case _PayMethod.giftCard:
        return '1 - Vale Presente';
      case _PayMethod.fuelVoucher:
        return '1 - Vale Combustível';
      case _PayMethod.other:
        return '1 - Outros';
      case _PayMethod.pix:
        return '1 - PIX';
      case _PayMethod.mercadoPago:
        return '1 - Mercado Pago';
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

// ===== Model ================================================================
class _PdvItem {
  _PdvItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.imageUrl,
  });
  String? productId;
  String name;
  double qty;
  double unitPrice;
  String? imageUrl;
}

// ===== Overlay progress (não trava) =========================================
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              const SizedBox(width: 12),
              Flexible(child: Text(message)),
            ]),
          ),
        ),
      ),
    ]),
  );

  overlay.insert(entry);

  final timer = Timer(const Duration(seconds: 25), () {
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
