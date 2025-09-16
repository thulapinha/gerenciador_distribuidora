import 'package:flutter/material.dart';

import '../../domain/services/cash_service.dart';
import 'open_cash_dialog.dart';
import 'movement_dialog.dart';
import 'close_cash_dialog.dart';
import 'report_screen.dart';

class CashboxBar extends StatefulWidget {
  final VoidCallback? onChanged; // avisa o PDV para recarregar status
  const CashboxBar({super.key, this.onChanged});

  @override
  State<CashboxBar> createState() => _CashboxBarState();
}

class _CashboxBarState extends State<CashboxBar> {
  bool _loading = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _status = await CashService().status();
    } catch (_) {
      _status = {'open': false};
    }
    if (mounted) setState(() => _loading = false);
    widget.onChanged?.call();
  }

  Future<void> _open() async {
    final res = await showDialog(
      context: context,
      builder: (_) => const OpenCashDialog(),
    );
    if (res != null) _refresh();
  }

  Future<void> _suprimento() async {
    final ok = await showDialog(
      context: context,
      builder: (_) => const CashMovementDialog(isSangria: false),
    );
    if (ok == true) _refresh();
  }

  Future<void> _sangria() async {
    final ok = await showDialog(
      context: context,
      builder: (_) => const CashMovementDialog(isSangria: true),
    );
    if (ok == true) _refresh();
  }

  Future<void> _fechar() async {
    final report = await showDialog(
      context: context,
      builder: (_) => const CloseCashDialog(),
    );
    if (report != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CashReportScreen(
            report: Map<String, dynamic>.from(report as Map),
          ),
        ),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final open = (_status?['open'] == true);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Text(
              open ? 'Sessão ABERTA' : 'Sessão FECHADA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: open ? Colors.green : Colors.red,
              ),
            ),
            const Spacer(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!open)
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.lock_open),
                label: const Text('Abrir'),
              ),
            if (open) ...[
              OutlinedButton.icon(
                onPressed: _suprimento,
                icon: const Icon(Icons.add),
                label: const Text('Suprimento'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _sangria,
                icon: const Icon(Icons.remove),
                label: const Text('Sangria'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _fechar,
                icon: const Icon(Icons.lock),
                label: const Text('Fechar'),
              ),
            ],
            IconButton(
              onPressed: _refresh,
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}
