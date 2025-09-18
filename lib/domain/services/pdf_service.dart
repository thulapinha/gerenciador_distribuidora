// lib/domain/services/pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static final NumberFormat _currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String _money(num v) => _currency.format(v);
  static num _nzNum(dynamic v) => (v is num) ? v : 0;
  static String _fmtDate(dynamic v) {
    if (v == null) return '-';
    if (v is DateTime) return _dateTime.format(v);
    if (v is String && v.isNotEmpty) {
      try {
        return _dateTime.format(DateTime.parse(v));
      } catch (_) {}
      return v;
    }
    return '-';
  }

  // ========== API pública ==========
  static Future<void> printCashboxReport(
      BuildContext context, {
        required Map<String, dynamic> summary,
        required List<Map<String, dynamic>> sales,
        required List<Map<String, dynamic>> movements,
      }) async {
    final bytes = await _buildCashboxReportBytes(summary: summary, sales: sales, movements: movements);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareCashboxReport({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> sales,
    required List<Map<String, dynamic>> movements,
  }) async {
    final bytes = await _buildCashboxReportBytes(summary: summary, sales: sales, movements: movements);
    await Printing.sharePdf(bytes: bytes, filename: 'extrato_caixa.pdf');
  }

  // ========== Builder ==========
  static Future<Uint8List> _buildCashboxReportBytes({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> sales,
    required List<Map<String, dynamic>> movements,
  }) async {
    final doc = pw.Document();

    // Resumos básicos
    final totals = Map<String, dynamic>.from(summary['totals'] ?? {});
    final byMethod = Map<String, dynamic>.from(totals['byMethod'] ?? {});
    final openingAmount = _nzNum(summary['openingAmount']);
    final declared = _nzNum(summary['declaredClosingAmount']);
    final expectedCash = _nzNum(summary['expectedCash']);
    final difference = _nzNum(summary['difference']);

    final operatorDisplay = (summary['operatorName'] ??
        summary['operator'] ??
        summary['operatorId'] ??
        '-')
        .toString();

    final diffColor = difference == 0
        ? PdfColors.green600
        : (difference > 0 ? PdfColors.orange600 : PdfColors.red);

    final baseText = pw.TextStyle(fontSize: 10);
    final label = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(28, 36, 28, 36),
          theme: pw.ThemeData.withFont(),
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('Extrato do Caixa',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Gerado em: ${_dateTime.format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text('Página ${ctx.pageNumber}/${ctx.pagesCount}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, height: 1),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          // Bloco: Cabeçalho da sessão
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Sessão:', (summary['sessionId'] ?? '-').toString(), label, baseText),
                _kv('Operador:', operatorDisplay, label, baseText),
                _kv('Status:', (summary['status'] ?? '-').toString().toUpperCase(), label, baseText),
                _kv('Abertura:', _fmtDate(summary['openedAt']), label, baseText),
                _kv('Fechamento:', _fmtDate(summary['closedAt']), label, baseText),
                pw.SizedBox(height: 6),
                _kv('Troco inicial:', _money(openingAmount), label, baseText),
                _kv('Declarado no fechamento:', _money(declared), label, baseText),
                _kv('Esperado em caixa:', _money(expectedCash), label, baseText),
                pw.Row(children: [
                  pw.Text('Diferença: ', style: label),
                  pw.Text(_money(difference),
                      style: baseText.copyWith(
                        color: diffColor,
                        fontWeight: pw.FontWeight.bold,
                      )),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Bloco: Totais
          pw.Text('Totais', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('Bruto'),
                  _th('Desconto'),
                  _th('Líquido'),
                ],
              ),
              pw.TableRow(
                children: [
                  _td(_money(_nzNum(totals['gross']))),
                  _td(_money(_nzNum(totals['discount']))),
                  _td(_money(_nzNum(totals['net']))),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Bloco: Por método de pagamento
          pw.Text('Por método de pagamento',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _byMethodTable(byMethod),

          pw.SizedBox(height: 14),

          // Bloco: Vendas
          pw.Text('Vendas', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (sales.isEmpty)
            pw.Text('Nenhuma venda no período.', style: baseText)
          else
            _salesTable(sales),

          pw.SizedBox(height: 14),

          // Bloco: Movimentos de Caixa
          pw.Text('Movimentos de Caixa',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (movements.isEmpty)
            pw.Text('Sem movimentos.', style: baseText)
          else
            _movesTable(movements),
        ],
      ),
    );

    return doc.save();
  }

  // ========== widgets helpers (pdf) ==========
  static pw.Widget _kv(String k, String v, pw.TextStyle kStyle, pw.TextStyle vStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 140, child: pw.Text(k, style: kStyle)),
          pw.Expanded(child: pw.Text(v, style: vStyle)),
        ],
      ),
    );
  }

  static pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Text(text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _td(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );

  static pw.Widget _byMethodTable(Map<String, dynamic> byMethod) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _th('Método'),
          _th('Qtde'),
          _th('Bruto'),
          _th('Líquido'),
          _th('Recebido'),
          _th('Troco'),
        ],
      ),
    ];

    final keys = byMethod.keys.toList()..sort();
    for (final k in keys) {
      final m = Map<String, dynamic>.from(byMethod[k] as Map);
      rows.add(
        pw.TableRow(
          children: [
            _td(k),
            _td('${_nzNum(m['count'])}'),
            _td(_money(_nzNum(m['subtotal']))),
            _td(_money(_nzNum(m['total']))),
            _td(_money(_nzNum(m['received']))),
            _td(_money(_nzNum(m['change']))),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _salesTable(List<Map<String, dynamic>> sales) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _th('Número'),
          _th('Data'),
          _th('Pagamento'),
          _th('Bruto'),
          _th('Desc.'),
          _th('Líquido'),
          _th('Recebido'),
          _th('Troco'),
        ],
      ),
    ];

    for (final s in sales) {
      rows.add(
        pw.TableRow(
          children: [
            _td((s['number'] ?? s['objectId'] ?? '').toString()),
            _td(_fmtDate(s['createdAt'])),
            _td((s['paymentMethod'] ?? '').toString()),
            _td(_money(_nzNum(s['subtotal']))),
            _td(_money(_nzNum(s['discount']))),
            _td(_money(_nzNum(s['total']))),
            _td(_money(_nzNum(s['received']))),
            _td(_money(_nzNum(s['change']))),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(0.9),
        4: pw.FlexColumnWidth(0.9),
        5: pw.FlexColumnWidth(0.9),
        6: pw.FlexColumnWidth(0.9),
        7: pw.FlexColumnWidth(0.9),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _movesTable(List<Map<String, dynamic>> moves) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _th('Tipo'),
          _th('Data'),
          _th('Valor'),
          _th('Obs.'),
        ],
      ),
    ];

    for (final m in moves) {
      rows.add(
        pw.TableRow(
          children: [
            _td((m['type'] ?? '').toString()),
            _td(_fmtDate(m['createdAt'])),
            _td(_money(_nzNum(m['amount']))),
            _td((m['note'] ?? '').toString()),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.8),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(0.8),
        3: pw.FlexColumnWidth(2.2),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}
