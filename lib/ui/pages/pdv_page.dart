// lib/ui/pages/pdv_page.dart
//
// REFACTOR: mesmo comportamento/visual do original, organizado em parts.
// NENHUMA lógica foi alterada. Apenas extração de widgets e utilitários.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

// ===== PARTS (precisam vir ANTES de qualquer declaração) =====================
part 'pdv/model.dart';
part 'pdv/overlay.dart';
part 'pdv/header.dart';
part 'pdv/search_bar.dart';
part 'pdv/items_table.dart';
part 'pdv/footer_items.dart';
part 'pdv/shortcuts_strip.dart';
part 'pdv/payment_grid.dart';
part 'pdv/bottom_nav_back.dart';
part 'pdv/finish_form.dart';

// ===== ENUMS ORIGINAIS =======================================================
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

// ===== PAGE =================================================================
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
  String _fmtQty(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

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

  double get _subtotal =>
      _items.fold(0.0, (p, e) => p + (e.qty * e.unitPrice));
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
                                : Image.network(imageUrl,
                                width: 40, height: 40, fit: BoxFit.cover),
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
              TextField(
                  decoration: const InputDecoration(labelText: 'Nome do produto'),
                  controller: nameCtl),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceCtl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor unitário'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Adicionar')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtl.text.trim();
      final qty = _parseDecimal(qtyCtl.text);
      final price = _parseDecimal(priceCtl.text);
      if (name.isEmpty || qty <= 0) return;
      setState(() {
        _items.add(_PdvItem(
            productId: null, name: name, qty: qty, unitPrice: price));
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
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantidade'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v > 0) setState(() => _items[i].qty = v);
    }
  }

  Future<void> _editUnit(int i) async {
    final ctl =
    TextEditingController(text: _items[i].unitPrice.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Alterar valor unitário (F5)'),
        content: TextField(
          controller: ctl,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration:
          const InputDecoration(labelText: 'Valor unitário'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Aplicar')),
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
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor do desconto'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Aplicar')),
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

    final close =
    _showBlockingOverlay(context, 'Finalizando venda...');
    try {
      final fn = ParseCloudFunction('finalizeSale');
      final resp =
      await fn.execute(parameters: {
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
            actions: [
              FilledButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: const Text('OK'))
            ],
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
                  onDec: (i) =>
                      setState(() => _items[i].qty = math.max(0.0, _items[i].qty - 1)),
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
              _BottomNavBack(
                text: 'VOLTAR (F11)',
                onBack: () => setState(() => _stage = _PdvStage.items),
              ),
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

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
