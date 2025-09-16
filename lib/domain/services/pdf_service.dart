// lib/domain/services/pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart' show BuildContext;

class PdfService {
  // ===== Helpers ============================================================
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static String _money(num v) => _brl.format(v);
  static String _dt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(d.toLocal());
  }

  // ===== API pública ========================================================
  /// Constrói o PDF do extrato do caixa.
  static Future<Uint8List> buildCashboxReport({
    required Map<String, dynamic> summary,
    required List<dynamic> sales,
    required List<dynamic> movements,
    String title = 'Extrato do Caixa',
  }) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    final totals = (summary['totals'] as Map<String, dynamic>? ?? {});
    final byMethod = (totals['byMethod'] as Map<String, dynamic>? ?? {});
    final openingAmount = summary['openingAmount'] ?? 0;
    final declared = summary['declaredClosingAmount'] ?? 0;
    final expectedCash = summary['expectedCash'] ?? 0;
    final difference = summary['difference'];
    final isClosed = (summary['status'] ?? '').toString().toUpperCase() == 'CLOSED';

    pw.Widget _kv(String k, String v, {PdfColor? color}) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 3, child: pw.Text(k, style:  pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 7, child: pw.Text(v, style: pw.TextStyle(color: color))),
      ],
    );

    // Cabeçalho
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          final widgets = <pw.Widget>[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),

            // Bloco identificação
            pw.Container(
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(children: [
                _kv('Sessão:', summary['sessionId'] ?? '-'),
                _kv('Operador:', summary['operatorId'] ?? '-'),
                _kv('Status:', (summary['status'] ?? '-').toString().toUpperCase()),
                _kv('Abertura:', _dt(summary['openedAt'])),
                _kv('Fechamento:', _dt(summary['closedAt'])),
                pw.SizedBox(height: 6),
                _kv('Troco inicial:', _money((openingAmount as num?) ?? 0)),
                _kv('Declarado no fechamento:', _money((declared as num?) ?? 0)),
                _kv('Esperado em caixa:', _money((expectedCash as num?) ?? 0)),
                _kv(
                  'Diferença:',
                  _money((difference is num ? difference : 0)),
                  color: (difference is num && difference != 0) ? PdfColors.red : PdfColors.black,
                ),
              ]),
            ),

            pw.SizedBox(height: 12),

            // Totais gerais
            pw.Text('Totais', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Bruto')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_money((totals['gross'] ?? 0) as num))),
                    ],
                  ),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Desconto')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_money((totals['discount'] ?? 0) as num))),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Líquido')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_money((totals['net'] ?? 0) as num))),
                  ]),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Por método de pagamento
            pw.Text('Por método de pagamento', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
                5: pw.FlexColumnWidth(2),
              },
              children: [
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
                ...byMethod.entries.map((e) {
                  final m = e.key;
                  final v = (e.value as Map).map((k, val) => MapEntry(k.toString(), (val as num?) ?? 0));
                  return pw.TableRow(children: [
                    _td(m),
                    _td('${v['count'] ?? 0}'),
                    _td(_money(v['subtotal'] ?? 0)),
                    _td(_money(v['total'] ?? 0)),
                    _td(_money(v['received'] ?? 0)),
                    _td(_money(v['change'] ?? 0)),
                  ]);
                }),
              ],
            ),

            pw.SizedBox(height: 12),

            // Vendas
            pw.Text('Vendas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            sales.isEmpty
                ? pw.Text('Nenhuma venda registrada.')
                : pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2), // nº
                1: pw.FlexColumnWidth(2.8), // data
                2: pw.FlexColumnWidth(2.2), // método
                3: pw.FlexColumnWidth(2.2), // bruto
                4: pw.FlexColumnWidth(2.2), // desconto
                5: pw.FlexColumnWidth(2.2), // líquido
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Número'),
                    _th('Data'),
                    _th('Pagamento'),
                    _th('Bruto'),
                    _th('Desc.'),
                    _th('Líquido'),
                  ],
                ),
                ...sales.map<pw.TableRow>((s) {
                  final sm = (s as Map<String, dynamic>);
                  return pw.TableRow(children: [
                    _td((sm['number'] ?? '-') as String? ?? '-'),
                    _td(_dt(sm['createdAt'] as String?)),
                    _td((sm['paymentMethod'] ?? '-') as String),
                    _td(_money((sm['subtotal'] ?? 0) as num)),
                    _td(_money((sm['discount'] ?? 0) as num)),
                    _td(_money((sm['total'] ?? 0) as num)),
                  ]);
                }),
              ],
            ),

            pw.SizedBox(height: 12),

            // Movimentos
            pw.Text('Movimentos de Caixa', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            movements.isEmpty
                ? pw.Text('Sem movimentos.')
                : pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.8), // data
                1: pw.FlexColumnWidth(2.0), // tipo
                2: pw.FlexColumnWidth(2.2), // valor
                3: pw.FlexColumnWidth(5.0), // obs
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Data'),
                    _th('Tipo'),
                    _th('Valor'),
                    _th('Observação'),
                  ],
                ),
                ...movements.map<pw.TableRow>((m) {
                  final mm = (m as Map<String, dynamic>);
                  return pw.TableRow(children: [
                    _td(_dt(mm['createdAt'] as String?)),
                    _td((mm['type'] ?? '-') as String),
                    _td(_money((mm['amount'] ?? 0) as num)),
                    _td((mm['note'] ?? '') as String),
                  ]);
                }),
              ],
            ),

            pw.SizedBox(height: 18),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                isClosed ? 'Documento gerado para conferência do fechamento.' : 'Documento parcial (sessão aberta).',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          ];

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  /// Abre a caixa de diálogo de **impressão** usando o PDF gerado.
  static Future<void> printCashboxReport(
      BuildContext context, {
        required Map<String, dynamic> summary,
        required List<dynamic> sales,
        required List<dynamic> movements,
      }) async {
    final data = await buildCashboxReport(
      summary: summary,
      sales: sales,
      movements: movements,
    );
    await Printing.layoutPdf(onLayout: (format) async => data);
  }

  /// Abre a caixa para **salvar/compartilhar** o PDF (útil no mobile).
  static Future<void> shareCashboxReport({
    required Map<String, dynamic> summary,
    required List<dynamic> sales,
    required List<dynamic> movements,
    String filename = 'extrato_caixa.pdf',
  }) async {
    final data = await buildCashboxReport(
      summary: summary,
      sales: sales,
      movements: movements,
    );
    await Printing.sharePdf(bytes: data, filename: filename);
  }

  // ===== Table cells helpers ===============================================
  static pw.Widget _th(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
  static pw.Widget _td(String text) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));
}
