// lib/ui/pages/pdv/widgets/pix_payment_dialog.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum PixDialogResult { approved, rejected, cancelled, expired, pending }

class PixPaymentDialog extends StatefulWidget {
  final String saleId;
  final String paymentId;     // recebido como texto; converteremos para número na chamada
  final String? qrCode;       // PIX copia-e-cola
  final String? qrBase64Png;  // QR em base64 (opcional)
  final String? ticketUrl;    // link de fallback/visualização

  const PixPaymentDialog({
    super.key,
    required this.saleId,
    required this.paymentId,
    this.qrCode,
    this.qrBase64Png,
    this.ticketUrl,
  });

  @override
  State<PixPaymentDialog> createState() => _PixPaymentDialogState();
}

class _PixPaymentDialogState extends State<PixPaymentDialog> {
  Timer? _timer;
  String _statusText = 'PENDING';
  int _attempts = 0;

  static const _interval = Duration(seconds: 2);
  static const _maxAttempts = 60; // ~120s

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _pollStatus());
  }

  bool _isApproved(String s) =>
      const {'approved', 'authorized', 'accredited'}.contains(s);

  bool _isTerminal(String s) =>
      const {'rejected','cancelled','canceled','expired','refunded','charged_back'}.contains(s);

  Future<void> _pollStatus() async {
    try {
      _attempts++;

      final pidNum = int.tryParse(widget.paymentId);
      final params = pidNum != null ? {'paymentId': pidNum} : {'paymentId': widget.paymentId};

      final fn = ParseCloudFunction('mpGetPixPaymentStatus');
      final resp = await fn.execute(parameters: params);

      if (!mounted) return;

      if (resp.success && resp.result is Map) {
        final map = (resp.result as Map).cast<String, dynamic>();
        final status = (map['status'] ?? '').toString().toLowerCase();

        setState(() => _statusText = status.isEmpty ? 'UNKNOWN' : status.toUpperCase());

        if (_isApproved(status)) {
          _timer?.cancel();
          Navigator.of(context).pop(PixDialogResult.approved);
          return;
        }
        if (_isTerminal(status)) {
          _timer?.cancel();
          Navigator.of(context).pop(_mapStatus(status));
          return;
        }
      }

      if (_attempts >= _maxAttempts) {
        _timer?.cancel();
        Navigator.of(context).pop(PixDialogResult.pending); // timeout
      }
    } catch (_) {
      // segue tentando silenciosamente
    }
  }

  PixDialogResult _mapStatus(String s) {
    switch (s) {
      case 'approved':
      case 'authorized':
      case 'accredited':
        return PixDialogResult.approved;
      case 'cancelled':
      case 'canceled':
        return PixDialogResult.cancelled;
      case 'expired':
        return PixDialogResult.expired;
      case 'rejected':
      case 'refunded':
      case 'charged_back':
        return PixDialogResult.rejected;
      default:
        return PixDialogResult.pending;
    }
  }

  Future<void> _openTicket() async {
    if (widget.ticketUrl == null) return;
    final uri = Uri.tryParse(widget.ticketUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildQr() {
    if (widget.qrBase64Png != null && widget.qrBase64Png!.isNotEmpty) {
      try {
        final bytes = base64Decode(widget.qrBase64Png!);
        return Image.memory(
          Uint8List.fromList(bytes),
          width: 240,
          height: 240,
          filterQuality: FilterQuality.medium,
        );
      } catch (_) {}
    }
    if (widget.qrCode != null && widget.qrCode!.isNotEmpty) {
      return QrImageView(
        data: widget.qrCode!,
        size: 240,
        gapless: true,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = (widget.qrCode ?? '').isNotEmpty;

    return AlertDialog(
      title: const Text('Pagamento PIX'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQr(),
          if (hasCode) const SizedBox(height: 12),
          if (hasCode)
            TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: widget.qrCode!)),
              child: const Text('Copiar código PIX'),
            ),
          if (widget.ticketUrl != null) const SizedBox(height: 8),
          if (widget.ticketUrl != null)
            TextButton(
              onPressed: _openTicket,
              child: const Text('Abrir boleto/QR no navegador'),
            ),
          const SizedBox(height: 12),
          Text('Status: $_statusText', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            _timer?.cancel();
            try {
              final pidNum = int.tryParse(widget.paymentId);
              final fn = ParseCloudFunction('mpApplyPaymentStatus');
              await fn.execute(parameters: {
                'saleId': widget.saleId,
                'status': 'cancelled',
                'mpPaymentId': pidNum ?? widget.paymentId,
              });
            } catch (_) {}
            if (!mounted) return;
            Navigator.of(context).pop(PixDialogResult.cancelled);
          },
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
