// lib/ui/pages/pdv_page.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';
import 'package:gerenciador_distribuidora/features/cashbox/cashbox_bar.dart';

// ===== PARTS ================================================================
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

// ===== ENUMS ================================================================
enum _PdvStage { items, payment, finish }
enum _PayMethod {
  cash, check, cardCredit, cardDebit, storeCredit, foodVoucher, mealVoucher,
  giftCard, fuelVoucher, other, pix, mercadoPago
}

// ===== Helpers GLOBAIS (disponíveis para as parts) ==========================
/// Formata dinheiro no padrão brasileiro.
/// (Função global para que `search_bar.dart` possa chamar sem erro.)
String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

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

  // Status servidor + usuário + caixa
  bool _serverOnline = true;
  String _userName = '-';
  String _role = 'admin';       // admin | cashier | ...
  bool _cashOpen = true;        // admin ignora; cashier precisa estar true
  Timer? _hb;

  // ===== Helpers =============================================================
  String _fmtQty(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

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
  bool get _isAdmin => _role == 'admin';
  bool get _needsCashOpen => !_isAdmin && _role == 'cashier' && !_cashOpen;

  // ------------------------- lifecycle --------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refocus());
    _resolveUserAndRole();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _codeCtl.dispose();
    _hb?.cancel();
    super.dispose();
  }

  void _refocus() {
    if (mounted) FocusScope.of(context).requestFocus(_focusNode);
  }

  // ---------- usuário/role + heartbeat --------------------------------------
  Future<void> _resolveUserAndRole() async {
    try {
      final u = await ParseUser.currentUser() as ParseUser?;
      final name = (u?.get<String>('name')) ?? (u?.get<String>('fullName')) ?? u?.username ?? '-';
      String role = 'admin';

      // consulta perfil
      try {
        final r = await ParseCloudFunction('getAccessProfile').execute();
        if (r.success && r.result is Map && (r.result['role'] is String)) {
          role = (r.result['role'] as String).toLowerCase();
        }
      } catch (_) {}

      // status do caixa (para operador)
      bool open = true;
      if (role == 'cashier') {
        open = await _fetchCashOpen();
      }

      if (!mounted) return;
      setState(() {
        _userName = name;
        _role = role;
        _cashOpen = open || role != 'cashier';
      });
    } catch (_) {}
  }

  Future<bool> _fetchCashOpen() async {
    try {
      final r = await ParseCloudFunction('getCashSessionStatus').execute();
      if (r.success && r.result is Map) {
        return (r.result['open'] == true);
      }
    } catch (_) {}
    return false;
  }

  void _startHeartbeat() {
    Future<void> ping() async {
      try {
        final r = await (QueryBuilder<ParseObject>(ParseObject('Product'))..setLimit(1)).query();
        if (mounted) setState(() => _serverOnline = r.success);
      } catch (_) {
        if (mounted) setState(() => _serverOnline = false);
      }
      // Atualiza status do caixa a cada batimento
      if (_role == 'cashier') {
        final open = await _fetchCashOpen();
        if (mounted) setState(() => _cashOpen = open);
      }
    }

    // primeiro ping imediato
    ping();
    _hb = Timer.periodic(const Duration(seconds: 30), (_) => ping());
  }

  // --------------------------- guardas de caixa ------------------------------
  Future<bool> _ensureCashOpen({bool silent = false}) async {
    if (_isAdmin) return true;            // admin sempre pode
    if (_role != 'cashier') return true;  // outros papéis não bloqueados aqui

    final open = await _fetchCashOpen();
    if (mounted) _cashOpen = open;

    if (open) return true;

    if (!silent) {
      _snack('Caixa fechado. Clique no botão "Caixa" acima e escolha "Abrir".');
    }
    return false;
  }

  // ====================== Produtos ==========================================
  Future<void> _addByCodeOrSearch() async {
    if (!await _ensureCashOpen()) return;

    final term = _codeCtl.text.trim();
    if (term.isEmpty) {
      await _openLookupDialog();
      return;
    }

    final close = _showBlockingOverlay(context, 'Buscando produto...');
    try {
      final p = await _repo.findByAnyCode(term).timeout(const Duration(seconds: 12));
      if (p == null) {
        _snack('Produto não encontrado.');
        return;
      }
      _addProductParse(p); // padrão UN
      _codeCtl.clear();
    } on TimeoutException {
      _snack('Tempo esgotado na busca. Tente novamente.');
    } catch (e) {
      _snack('Erro na busca: $e');
    } finally {
      close();
      _refocus();
    }
  }

  void _addProductParse(
      ParseObject p, {
        String uom = 'UN',
        double? multiplier,
        double? overridePrice,
      }) {
    final baseName = p.get<String>('name') ?? 'Produto';
    final id = p.objectId!;
    final imageUrl = p.get<ParseFileBase>('image')?.url;

    final packQty = (p.get<num>('packQty') ?? p.get<num>('packSize') ?? 1).toDouble();
    final isCx = uom.toUpperCase() == 'CX';
    final mult = isCx ? (multiplier ?? (packQty <= 0 ? 1.0 : packQty)) : 1.0;

    final priceUn = (p.get<num>('price') ?? 0).toDouble();
    final priceCx = (p.get<num>('packPrice') ?? 0).toDouble();
    final displayPrice = overridePrice ?? (isCx ? priceCx : priceUn);

    final label = isCx ? '${baseName.toUpperCase()} cx' : '${baseName.toUpperCase()} un';

    setState(() {
      final idx = _items.indexWhere((e) => e.productId == id && e.uom == uom.toUpperCase());
      if (idx >= 0) {
        _items[idx].qty += 1;
        _selectedIndex = idx;
      } else {
        _items.add(_PdvItem(
          productId: id,
          name: label,
          qty: 1,
          unitPrice: displayPrice,
          imageUrl: imageUrl,
          uom: uom.toUpperCase(),
          multiplier: mult,
        ));
        _selectedIndex = _items.length - 1;
      }
    });
  }

  Future<void> _openLookupDialog() async {
    if (!await _ensureCashOpen()) return;

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
            } finally {
              setDState(() => loading = false);
            }
          }

          return AlertDialog(
            title: const Text('Buscar Produto (F2)'),
            content: SizedBox(
              width: 580, height: 420,
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
                        final name = (p.get<String>('name') ?? '').toUpperCase();
                        final sku = p.get<String>('sku') ??
                            p.get<String>('barcode') ??
                            p.get<String>('code') ??
                            '';
                        final imageUrl = p.get<ParseFileBase>('image')?.url;

                        final priceUn = (p.get<num>('price') ?? 0).toDouble();
                        final packPrice = (p.get<num>('packPrice') ?? 0).toDouble();
                        final packQty = (p.get<num>('packQty') ?? 0).toDouble();

                        final hasCx = packQty > 0 && packPrice > 0;

                        Widget thumb() => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: imageUrl == null
                              ? Container(
                            width: 40, height: 40, color: Colors.black12,
                            child: const Icon(Icons.inventory_2, size: 22),
                          )
                              : Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                        );

                        final unTile = ListTile(
                          leading: thumb(),
                          title: Text('$name un'),
                          subtitle: Text('SKU: $sku'),
                          trailing: Text(_money(priceUn)),
                          onTap: () {
                            Navigator.of(dctx).pop();
                            _addProductParse(p, uom: 'UN', overridePrice: priceUn);
                            _refocus();
                          },
                        );

                        final cxTile = hasCx
                            ? ListTile(
                          leading: thumb(),
                          title: Text('$name cx'),
                          subtitle: Text('CX com ${packQty.toStringAsFixed(packQty.truncateToDouble()==packQty?0:2)} un'),
                          trailing: Text(_money(packPrice)),
                          onTap: () {
                            Navigator.of(dctx).pop();
                            _addProductParse(
                              p,
                              uom: 'CX',
                              multiplier: packQty,
                              overridePrice: packPrice,
                            );
                            _refocus();
                          },
                        )
                            : null;

                        return Column(children: [unTile, if (cxTile != null) cxTile]);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { Navigator.of(dctx).pop(); _refocus(); }, child: const Text('Fechar')),
              FilledButton(onPressed: () async { await doSearchLocal(); }, child: const Text('Buscar')),
            ],
          );
        },
      ),
    );
    _refocus();
  }

  // Manuais/edição
  Future<void> _addManualDialog() async {
    if (!await _ensureCashOpen()) return;

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
          TextButton(onPressed: () { Navigator.of(dctx).pop(false); _refocus(); }, child: const Text('Cancelar')),
          FilledButton(onPressed: () { Navigator.of(dctx).pop(true); }, child: const Text('Adicionar')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtl.text.trim();
      final qty = _parseDecimal(qtyCtl.text);
      final price = _parseDecimal(priceCtl.text);
      if (name.isEmpty || qty <= 0) { _refocus(); return; }
      setState(() {
        _items.add(_PdvItem(productId: null, name: '$name un', qty: qty, unitPrice: price, uom: 'UN', multiplier: 1));
        _selectedIndex = _items.length - 1;
      });
    }
    _refocus();
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
          TextButton(onPressed: () { Navigator.of(dctx).pop(false); _refocus(); }, child: const Text('Cancelar')),
          FilledButton(onPressed: () { Navigator.of(dctx).pop(true); }, child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v > 0) setState(() => _items[i].qty = v);
    }
    _refocus();
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
          TextButton(onPressed: () { Navigator.of(dctx).pop(false); _refocus(); }, child: const Text('Cancelar')),
          FilledButton(onPressed: () { Navigator.of(dctx).pop(true); }, child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v >= 0) setState(() => _items[i].unitPrice = v);
    }
    _refocus();
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
          TextButton(onPressed: () { Navigator.of(dctx).pop(false); _refocus(); }, child: const Text('Cancelar')),
          FilledButton(onPressed: () { Navigator.of(dctx).pop(true); }, child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v >= 0) setState(() => _discount = v);
    }
    _refocus();
  }

  // ====================== Finalização / pagamento ============================
  void _goPayment() async {
    if (!await _ensureCashOpen()) return;
    if (_items.isEmpty) {
      _snack('Inclua pelo menos um produto.');
      return;
    }
    setState(() {
      _stage = _PdvStage.payment;
      _selectedMethod = null;
      _received = 0;
    });
    _refocus();
  }

  void _selectMethod(_PayMethod m) {
    setState(() {
      _selectedMethod = m;
      _stage = _PdvStage.finish;
      _received = _total;
    });
    _refocus();
  }

  Future<void> _finalizeSale() async {
    if (!await _ensureCashOpen()) return;

    if (_items.isEmpty) { _snack('Inclua itens.'); return; }
    if (_selectedMethod == null) { _snack('Escolha a forma de pagamento.'); return; }

    final close = _showBlockingOverlay(context, 'Finalizando venda...');
    try {
      final itemsPayload = _items.map((e) {
        final base = {
          'qty': e.qty,
          'unitPrice': e.unitPrice,  // preço mostrado (UN ou CX)
          'uom': e.uom,              // 'UN' | 'CX'
          'multiplier': e.multiplier // itens por caixa (1 para UN)
        };
        if (e.productId != null) {
          return {'productId': e.productId, ...base};
        } else {
          return {'manual': true, 'name': e.name, ...base};
        }
      }).toList();

      final fn = ParseCloudFunction('finalizeSale');
      final resp = await fn.execute(parameters: {
        'items': itemsPayload,
        'discount': _discount,
        'paymentMethod': _methodString(_selectedMethod!),
        'received': _received,
        'clientTotals': {'subtotal': _subtotal, 'discount': _discount, 'total': _total, 'received': _received},
      }).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      if (resp.success) {
        num? serverTotal;
        final r = resp.result;
        if (r is Map && r['total'] is num) serverTotal = r['total'] as num;
        final showTotal = (serverTotal == null || serverTotal <= 0) ? _total : serverTotal;

        close();
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (dctx) => AlertDialog(
            title: const Text('Venda concluída'),
            content: Text('Total: ${_money(showTotal)}'),
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
        _refocus();
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
      case _PayMethod.cash:         return 'CASH';
      case _PayMethod.pix:          return 'PIX';
      case _PayMethod.cardCredit:   return 'CARD_CREDIT';
      case _PayMethod.cardDebit:    return 'CARD_DEBIT';
      case _PayMethod.check:        return 'CHECK';
      case _PayMethod.storeCredit:  return 'STORE_CREDIT';
      case _PayMethod.foodVoucher:  return 'FOOD_VOUCHER';
      case _PayMethod.mealVoucher:  return 'MEAL_VOUCHER';
      case _PayMethod.giftCard:     return 'GIFT_CARD';
      case _PayMethod.fuelVoucher:  return 'FUEL_VOUCHER';
      case _PayMethod.other:        return 'OTHER';
      case _PayMethod.mercadoPago:  return 'MERCADO_PAGO';
    }
  }

  // ====================== Atalhos ===========================================
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    // Se caixa fechado para operador, ignoramos atalhos de inclusão/edição
    if (_needsCashOpen) {
      if (k == LogicalKeyboardKey.f8 || k == LogicalKeyboardKey.enter) {
        _snack('Caixa fechado. Abra o caixa para prosseguir.');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (_stage == _PdvStage.items) {
      if (k == LogicalKeyboardKey.enter) { _addByCodeOrSearch(); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f2)   { _openLookupDialog();  return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f3)   { _addManualDialog();   return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f4 && _selectedIndex != null) { _editQty(_selectedIndex!); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f5 && _selectedIndex != null) { _editUnit(_selectedIndex!); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f6 && _selectedIndex != null) { setState(() => _items.removeAt(_selectedIndex!)); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f8)   { _goPayment();         return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f10)  { _editDiscount();      return KeyEventResult.handled; }
    } else if (_stage == _PdvStage.payment) {
      if (k == LogicalKeyboardKey.f1)  { _selectMethod(_PayMethod.cash);        return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f2)  { _selectMethod(_PayMethod.check);       return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f3)  { _selectMethod(_PayMethod.cardCredit);  return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f4)  { _selectMethod(_PayMethod.cardDebit);   return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f5)  { _selectMethod(_PayMethod.storeCredit); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f6)  { _selectMethod(_PayMethod.foodVoucher); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f7)  { _selectMethod(_PayMethod.mealVoucher); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f8)  { _selectMethod(_PayMethod.giftCard);    return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f9)  { _selectMethod(_PayMethod.fuelVoucher); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f10) { _selectMethod(_PayMethod.other);       return KeyEventResult.handled; }
      if (k.keyLabel.toUpperCase() == 'P') { _selectMethod(_PayMethod.pix);          return KeyEventResult.handled; }
      if (k.keyLabel.toUpperCase() == 'M') { _selectMethod(_PayMethod.mercadoPago);  return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f11) { setState(() => _stage = _PdvStage.items); _refocus(); return KeyEventResult.handled; }
    } else if (_stage == _PdvStage.finish) {
      if (k == LogicalKeyboardKey.f11) { setState(() => _stage = _PdvStage.payment); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.f8 || k == LogicalKeyboardKey.f12 || k == LogicalKeyboardKey.enter) {
        _finalizeSale(); return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ====================== UI =================================================
  @override
  Widget build(BuildContext context) {
    final closedBanner = _needsCashOpen
        ? Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFFFF3CD),
      child: const Text('Sessão FECHADA — abra o caixa para registrar produtos.',
          style: TextStyle(color: Color(0xFF856404))),
    )
        : const SizedBox.shrink();

    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            _Header(priceTier: _priceTier, stage: _stage),
            const CashboxBar(), // sua barra de caixa
            closedBanner,
            const SizedBox(height: 8),

            if (_stage == _PdvStage.items) ...[
              AbsorbPointer(
                absorbing: _needsCashOpen,
                child: Opacity(
                  opacity: _needsCashOpen ? 0.45 : 1,
                  child: Column(
                    children: [
                      _SearchBar(
                        controller: _codeCtl,
                        onSubmitted: _addByCodeOrSearch,
                        onAddManual: _addManualDialog,
                        onLookup: _openLookupDialog,
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 8), // separador
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _needsCashOpen,
                  child: Opacity(
                    opacity: _needsCashOpen ? 0.5 : 1,
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
                serverOnline: _serverOnline,
                userName: _userName,
              ),
              const SizedBox(height: 6),
              _ShortcutsStripItems(
                onF2Search: _openLookupDialog,
                onF3Add: _addManualDialog,
                onF4Qty: () { if (_selectedIndex != null) _editQty(_selectedIndex!); else _snack('Selecione um item.'); },
                onF5Val: () { if (_selectedIndex != null) _editUnit(_selectedIndex!); else _snack('Selecione um item.'); },
                onF6Remove: () {
                  if (_selectedIndex != null) {
                    setState(() => _items.removeAt(_selectedIndex!));
                    _selectedIndex = null;
                  } else {
                    _snack('Selecione um item para remover.');
                  }
                },
                onF8Proceed: _goPayment,
                onF10Discount: _editDiscount,
              ),
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
