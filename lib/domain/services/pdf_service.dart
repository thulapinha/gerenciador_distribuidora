// lib/domain/services/pdf_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<void> showReceipt({
    required String saleNumber,
    String? customerCpf,
    required DateTime date,
    required List<Map<String, dynamic>> items, // {desc, qty, unitPrice, total}
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
    required double received,
    required double change,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (c) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Recibo de Venda', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Venda: $saleNumber'),
            if (customerCpf != null && customerCpf.isNotEmpty) pw.Text('CPF: $customerCpf'),
            pw.Text('Data: $date'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Descrição', 'Qtd', 'Unit', 'Total'],
              data: items.map((e) => [e['desc'], e['qty'], e['unitPrice'].toStringAsFixed(2), e['total'].toStringAsFixed(2)]).toList(),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
            pw.Text('Desconto: ${discount.toStringAsFixed(2)}'),
            pw.Text('Total: ${total.toStringAsFixed(2)}'),
            pw.SizedBox(height: 8),
            pw.Text('Pagamento: $paymentMethod'),
            pw.Text('Recebido: ${received.toStringAsFixed(2)}'),
            pw.Text('Troco: ${change.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
