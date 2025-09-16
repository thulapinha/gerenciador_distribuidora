import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session.dart';
import '../../core/rbac.dart';
import '../../core/csv_export.dart'; // para ações de exportação (botões)
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

// A SettingsPage é pensada para ADMIN (já protegido por PAGES.settings no backend).
// Mesmo assim, aqui validamos role/pages.

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  late TabController _tab;

  // Empresa
  final _companyName = TextEditingController();
  final _cnpjCpf = TextEditingController();
  final _ie = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  // PDV/Vendas
  String _defaultPayment = 'CASH';
  bool _decrementStockOnSale = true;
  bool _allowBelowCost = false;
  bool _printAfterSale = false;

  // Financeiro
  bool _enableDiscounts = true;
  double _maxDiscountPercent = 10.0;

  // Sincronização
  bool _enableAutoSync = true;
  int _syncIntervalMin = 5;

  // Segurança
  bool _allowNonAdminUserCreate = false;

  ParseObject? _configObj; // Config do Parse (key=GLOBAL)
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _companyName.dispose();
    _cnpjCpf.dispose();
    _ie.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1) tenta carregar do Parse
      final q = QueryBuilder<ParseObject>(ParseObject('Config'))..whereEqualTo('key', 'GLOBAL')..setLimit(1);
      final res = await q.query();
      if (res.success && res.results != null && res.results!.isNotEmpty) {
        _configObj = res.results!.first as ParseObject;
        _applyFromConfig(_configObj!);
      } else {
        _configObj = null;
      }

      // 2) carrega preferências locais (fallbacks)
      final sp = await SharedPreferences.getInstance();
      _defaultPayment = sp.getString('cfg.defaultPayment') ?? _defaultPayment;
      _decrementStockOnSale = sp.getBool('cfg.decrementStockOnSale') ?? _decrementStockOnSale;
      _allowBelowCost = sp.getBool('cfg.allowBelowCost') ?? _allowBelowCost;
      _printAfterSale = sp.getBool('cfg.printAfterSale') ?? _printAfterSale;

      _enableDiscounts = sp.getBool('cfg.enableDiscounts') ?? _enableDiscounts;
      _maxDiscountPercent = sp.getDouble('cfg.maxDiscountPercent') ?? _maxDiscountPercent;

      _enableAutoSync = sp.getBool('cfg.enableAutoSync') ?? _enableAutoSync;
      _syncIntervalMin = sp.getInt('cfg.syncIntervalMin') ?? _syncIntervalMin;

      _allowNonAdminUserCreate = sp.getBool('cfg.allowNonAdminUserCreate') ?? _allowNonAdminUserCreate;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar config: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFromConfig(ParseObject cfg) {
    setState(() {
      _companyName.text = cfg.get<String>('companyName') ?? '';
      _cnpjCpf.text = cfg.get<String>('cnpjCpf') ?? '';
      _ie.text = cfg.get<String>('ie') ?? '';
      _email.text = cfg.get<String>('email') ?? '';
      _phone.text = cfg.get<String>('phone') ?? '';
      _address.text = cfg.get<String>('address') ?? '';

      _defaultPayment = cfg.get<String>('defaultPayment') ?? _defaultPayment;
      _decrementStockOnSale = cfg.get<bool>('decrementStockOnSale') ?? _decrementStockOnSale;
      _allowBelowCost = cfg.get<bool>('allowBelowCost') ?? _allowBelowCost;
      _printAfterSale = cfg.get<bool>('printAfterSale') ?? _printAfterSale;

      _enableDiscounts = cfg.get<bool>('enableDiscounts') ?? _enableDiscounts;
      _maxDiscountPercent = (cfg.get<num>('maxDiscountPercent') ?? _maxDiscountPercent).toDouble();

      _enableAutoSync = cfg.get<bool>('enableAutoSync') ?? _enableAutoSync;
      _syncIntervalMin = (cfg.get<num>('syncIntervalMin') ?? _syncIntervalMin).toInt();

      _allowNonAdminUserCreate = cfg.get<bool>('allowNonAdminUserCreate') ?? _allowNonAdminUserCreate;
    });
  }

  Future<void> _save() async {
    if (!(Session.i.role == Roles.admin || Session.i.show(Pages.settings))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas Admin pode salvar configurações.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final obj = _configObj ?? ParseObject('Config')..set<String>('key', 'GLOBAL');
      obj
        ..set<String>('companyName', _companyName.text.trim())
        ..set<String>('cnpjCpf', _cnpjCpf.text.trim())
        ..set<String>('ie', _ie.text.trim())
        ..set<String>('email', _email.text.trim())
        ..set<String>('phone', _phone.text.trim())
        ..set<String>('address', _address.text.trim())
        ..set<String>('defaultPayment', _defaultPayment)
        ..set<bool>('decrementStockOnSale', _decrementStockOnSale)
        ..set<bool>('allowBelowCost', _allowBelowCost)
        ..set<bool>('printAfterSale', _printAfterSale)
        ..set<bool>('enableDiscounts', _enableDiscounts)
        ..set<num>('maxDiscountPercent', _maxDiscountPercent)
        ..set<bool>('enableAutoSync', _enableAutoSync)
        ..set<num>('syncIntervalMin', _syncIntervalMin)
        ..set<bool>('allowNonAdminUserCreate', _allowNonAdminUserCreate);

      final res = await obj.save();
      if (!res.success) {
        throw res.error?.message ?? 'Falha ao salvar no Parse';
      }
      _configObj = obj;

      // salva preferências locais
      final sp = await SharedPreferences.getInstance();
      await sp.setString('cfg.defaultPayment', _defaultPayment);
      await sp.setBool('cfg.decrementStockOnSale', _decrementStockOnSale);
      await sp.setBool('cfg.allowBelowCost', _allowBelowCost);
      await sp.setBool('cfg.printAfterSale', _printAfterSale);

      await sp.setBool('cfg.enableDiscounts', _enableDiscounts);
      await sp.setDouble('cfg.maxDiscountPercent', _maxDiscountPercent);

      await sp.setBool('cfg.enableAutoSync', _enableAutoSync);
      await sp.setInt('cfg.syncIntervalMin', _syncIntervalMin);

      await sp.setBool('cfg.allowNonAdminUserCreate', _allowNonAdminUserCreate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Export/Backup básico (pelo servidor) – gera CSVs simples das classes principais
  Future<void> _exportClass(String className, String filenamePrefix) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final rows = <List<dynamic>>[];

      // Cabeçalhos por classe (simplificado)
      List<String> headers;
      if (className == 'Product') {
        headers = ['objectId', 'name', 'barcode', 'price', 'stock', 'active', 'updatedAt'];
      } else if (className == 'Customer') {
        headers = ['objectId', 'name', 'cpf', 'phone', 'email', 'address', 'updatedAt'];
      } else if (className == 'Sale') {
        headers = ['objectId', 'number', 'subtotal', 'discount', 'total', 'received', 'change', 'paymentMethod', 'status', 'customerCpf', 'createdByRole', 'createdAt', 'updatedAt'];
      } else if (className == 'SaleItem') {
        headers = ['objectId', 'saleId', 'productId', 'qty', 'unitPrice', 'total', 'updatedAt'];
      } else {
        headers = ['objectId', 'updatedAt'];
      }
      rows.add(headers);

      // Busca
      final q = QueryBuilder<ParseObject>(ParseObject(className))
        ..orderByAscending('updatedAt')
        ..setLimit(1000);
      final res = await q.query();
      if (res.success && res.results != null) {
        final list = res.results!.cast<ParseObject>();
        for (final o in list) {
          if (className == 'Product') {
            rows.add([
              o.objectId,
              o.get<String>('name') ?? '',
              o.get<String>('barcode') ?? '',
              (o.get<num>('price') ?? 0).toDouble(),
              (o.get<num>('stock') ?? 0).toDouble(),
              (o.get<bool>('active') ?? true) ? 1 : 0,
              o.updatedAt?.toIso8601String() ?? '',
            ]);
          } else if (className == 'Customer') {
            rows.add([
              o.objectId,
              o.get<String>('name') ?? '',
              o.get<String>('cpf') ?? '',
              o.get<String>('phone') ?? '',
              o.get<String>('email') ?? '',
              o.get<String>('address') ?? '',
              o.updatedAt?.toIso8601String() ?? '',
            ]);
          } else if (className == 'Sale') {
            rows.add([
              o.objectId,
              o.get<String>('number') ?? '',
              (o.get<num>('subtotal') ?? 0).toDouble(),
              (o.get<num>('discount') ?? 0).toDouble(),
              (o.get<num>('total') ?? 0).toDouble(),
              (o.get<num>('received') ?? 0).toDouble(),
              (o.get<num>('change') ?? 0).toDouble(),
              o.get<String>('paymentMethod') ?? '',
              o.get<String>('status') ?? '',
              o.get<String>('customerCpf') ?? '',
              o.get<String>('createdByRole') ?? '',
              o.createdAt?.toIso8601String() ?? '',
              o.updatedAt?.toIso8601String() ?? '',
            ]);
          } else if (className == 'SaleItem') {
            rows.add([
              o.objectId,
              (o.get<ParseObject>('sale'))?.objectId ?? '',
              (o.get<ParseObject>('product'))?.objectId ?? '',
              (o.get<num>('qty') ?? 0).toDouble(),
              (o.get<num>('unitPrice') ?? 0).toDouble(),
              (o.get<num>('total') ?? 0).toDouble(),
              o.updatedAt?.toIso8601String() ?? '',
            ]);
          } else {
            rows.add([o.objectId, o.updatedAt?.toIso8601String() ?? '']);
          }
        }
      }

      final file = await saveCsv(
        '${filenamePrefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
        rows,
        dir,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV de $className salvo em: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export falhou: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(Session.i.role == Roles.admin || Session.i.show(Pages.settings))) {
      return const Center(child: Text('Acesso negado'));
    }

    return Column(
      children: [
        TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Empresa'),
            Tab(text: 'PDV & Vendas'),
            Tab(text: 'Financeiro'),
            Tab(text: 'Sincronização'),
            Tab(text: 'Segurança'),
            Tab(text: 'Export/Backup'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _EmpresaTab(
                companyName: _companyName,
                cnpjCpf: _cnpjCpf,
                ie: _ie,
                email: _email,
                phone: _phone,
                address: _address,
              ),
              _PdvVendasTab(
                defaultPayment: _defaultPayment,
                onPaymentChanged: (v) => setState(() => _defaultPayment = v),
                decrementStockOnSale: _decrementStockOnSale,
                onDecStockChanged: (v) => setState(() => _decrementStockOnSale = v),
                allowBelowCost: _allowBelowCost,
                onAllowBelowCostChanged: (v) => setState(() => _allowBelowCost = v),
                printAfterSale: _printAfterSale,
                onPrintAfterSaleChanged: (v) => setState(() => _printAfterSale = v),
              ),
              _FinanceiroTab(
                enableDiscounts: _enableDiscounts,
                onEnableDiscounts: (v) => setState(() => _enableDiscounts = v),
                maxDiscountPercent: _maxDiscountPercent,
                onMaxDiscountChanged: (v) => setState(() => _maxDiscountPercent = v),
              ),
              _SyncTab(
                enableAutoSync: _enableAutoSync,
                onEnableAutoSync: (v) => setState(() => _enableAutoSync = v),
                syncIntervalMin: _syncIntervalMin,
                onIntervalChanged: (v) => setState(() => _syncIntervalMin = v),
              ),
              _SegurancaTab(
                allowNonAdminUserCreate: _allowNonAdminUserCreate,
                onAllowNonAdminUserCreate: (v) => setState(() => _allowNonAdminUserCreate = v),
              ),
              _ExportTab(
                onExportProducts: () => _exportClass('Product', 'products'),
                onExportCustomers: () => _exportClass('Customer', 'customers'),
                onExportSales: () => _exportClass('Sale', 'sales'),
                onExportItems: () => _exportClass('SaleItem', 'sale_items'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_loading ? 'Salvando...' : 'Salvar'),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- TABS --------------------

class _EmpresaTab extends StatelessWidget {
  final TextEditingController companyName, cnpjCpf, ie, email, phone, address;
  const _EmpresaTab({
    required this.companyName,
    required this.cnpjCpf,
    required this.ie,
    required this.email,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Dados da Empresa', [
          TextField(controller: companyName, decoration: const InputDecoration(labelText: 'Nome da empresa')),
          const SizedBox(height: 8),
          TextField(controller: cnpjCpf, decoration: const InputDecoration(labelText: 'CNPJ/CPF')),
          const SizedBox(height: 8),
          TextField(controller: ie, decoration: const InputDecoration(labelText: 'IE (opcional)')),
          const SizedBox(height: 8),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefone')),
          const SizedBox(height: 8),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Endereço')),
        ]),
      ],
    );
  }
}

class _PdvVendasTab extends StatelessWidget {
  final String defaultPayment;
  final ValueChanged<String> onPaymentChanged;

  final bool decrementStockOnSale;
  final ValueChanged<bool> onDecStockChanged;

  final bool allowBelowCost;
  final ValueChanged<bool> onAllowBelowCostChanged;

  final bool printAfterSale;
  final ValueChanged<bool> onPrintAfterSaleChanged;

  const _PdvVendasTab({
    required this.defaultPayment,
    required this.onPaymentChanged,
    required this.decrementStockOnSale,
    required this.onDecStockChanged,
    required this.allowBelowCost,
    required this.onAllowBelowCostChanged,
    required this.printAfterSale,
    required this.onPrintAfterSaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('PDV', [
          DropdownButtonFormField<String>(
            value: defaultPayment,
            decoration: const InputDecoration(labelText: 'Pagamento padrão'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'CARD', child: Text('Cartão')),
              DropdownMenuItem(value: 'PIX', child: Text('PIX')),
              DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
            ],
            onChanged: (v) => onPaymentChanged(v ?? 'CASH'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Baixar estoque ao finalizar venda'),
            value: decrementStockOnSale,
            onChanged: onDecStockChanged,
          ),
          SwitchListTile(
            title: const Text('Permitir preço abaixo do custo'),
            value: allowBelowCost,
            onChanged: onAllowBelowCostChanged,
          ),
          SwitchListTile(
            title: const Text('Imprimir após venda'),
            value: printAfterSale,
            onChanged: onPrintAfterSaleChanged,
          ),
        ]),
      ],
    );
  }
}

class _FinanceiroTab extends StatelessWidget {
  final bool enableDiscounts;
  final ValueChanged<bool> onEnableDiscounts;
  final double maxDiscountPercent;
  final ValueChanged<double> onMaxDiscountChanged;

  const _FinanceiroTab({
    required this.enableDiscounts,
    required this.onEnableDiscounts,
    required this.maxDiscountPercent,
    required this.onMaxDiscountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: maxDiscountPercent.toStringAsFixed(2));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Regras Financeiras', [
          SwitchListTile(
            title: const Text('Permitir descontos'),
            value: enableDiscounts,
            onChanged: onEnableDiscounts,
          ),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Desconto máx. (%)'),
            onChanged: (v) {
              final d = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              onMaxDiscountChanged(d);
            },
          ),
        ]),
      ],
    );
  }
}

class _SyncTab extends StatelessWidget {
  final bool enableAutoSync;
  final ValueChanged<bool> onEnableAutoSync;
  final int syncIntervalMin;
  final ValueChanged<int> onIntervalChanged;

  const _SyncTab({
    required this.enableAutoSync,
    required this.onEnableAutoSync,
    required this.syncIntervalMin,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: syncIntervalMin.toString());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Sincronização', [
          SwitchListTile(
            title: const Text('Sincronização automática'),
            value: enableAutoSync,
            onChanged: onEnableAutoSync,
          ),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Intervalo (minutos)'),
            onChanged: (v) => onIntervalChanged(int.tryParse(v) ?? 5),
          ),
        ]),
      ],
    );
  }
}

class _SegurancaTab extends StatelessWidget {
  final bool allowNonAdminUserCreate;
  final ValueChanged<bool> onAllowNonAdminUserCreate;

  const _SegurancaTab({
    required this.allowNonAdminUserCreate,
    required this.onAllowNonAdminUserCreate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Segurança', [
          SwitchListTile(
            title: const Text('Permitir criação de usuários por não-admin'),
            subtitle: const Text('O backend ainda valida por capacidades (users.manage).'),
            value: allowNonAdminUserCreate,
            onChanged: onAllowNonAdminUserCreate,
          ),
        ]),
      ],
    );
  }
}

class _ExportTab extends StatelessWidget {
  final VoidCallback onExportProducts;
  final VoidCallback onExportCustomers;
  final VoidCallback onExportSales;
  final VoidCallback onExportItems;

  const _ExportTab({
    required this.onExportProducts,
    required this.onExportCustomers,
    required this.onExportSales,
    required this.onExportItems,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card('Exportar CSV (servidor)', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: onExportProducts, child: const Text('Produtos')),
              FilledButton.tonal(onPressed: onExportCustomers, child: const Text('Clientes')),
              FilledButton.tonal(onPressed: onExportSales, child: const Text('Vendas')),
              FilledButton.tonal(onPressed: onExportItems, child: const Text('Itens de Venda')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Os CSVs são salvos em Documentos do aplicativo.'),
        ]),
      ],
    );
  }
}

// -------------------- Helpers UI --------------------

Widget _card(String title, List<Widget> children) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
