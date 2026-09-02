import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/auth_controller.dart';
import '../../services/ai_credit_service.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../theme/app_theme.dart';

/// Embeds Midtrans's Snap payment page for a physical-order payment.
/// Same pattern as `PaymentWebViewScreen` (AI-credit purchases), generalized
/// to pop with a plain success flag instead of an AI-credit-specific message.
/// Status polling reuses `AiCreditService.checkStatus` — the underlying
/// endpoint (`GET /payments/:id/midtrans-status`) is generic to any payment.
class OrderPaymentWebViewScreen extends StatefulWidget {
  final String redirectUrl;
  final String paymentId;

  const OrderPaymentWebViewScreen({
    super.key,
    required this.redirectUrl,
    required this.paymentId,
  });

  @override
  State<OrderPaymentWebViewScreen> createState() => _OrderPaymentWebViewScreenState();
}

class _OrderPaymentWebViewScreenState extends State<OrderPaymentWebViewScreen> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _checking = false;
  bool _loadingPage = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingPage = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus({bool manual = false}) async {
    if (_checking) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;

    setState(() => _checking = true);
    try {
      final result = await AiCreditService.checkStatus(token: token, paymentId: widget.paymentId);
      if (!mounted) return;

      if (result.isPaid) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil! Pesanan kamu segera diproses.')),
        );
        return;
      }

      if (result.isFailed) {
        _pollTimer?.cancel();
        setState(() => _statusMessage = 'Pembayaran tidak berhasil (${result.localStatus}).');
        return;
      }

      if (manual) {
        setState(() => _statusMessage = 'Pembayaran masih menunggu diselesaikan.');
      }
    } on ApiException catch (e) {
      if (manual && mounted) setState(() => _statusMessage = e.message);
    } catch (_) {
      // Silent on background polls — the next tick will just retry.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surfaceMuted,
              child: Text(
                _statusMessage!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadingPage)
                  const Center(child: CircularProgressIndicator(color: AppColors.purple)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : () => _checkStatus(manual: true),
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.purple),
                  label: Text(
                    _checking ? 'Memeriksa...' : 'Sudah Bayar? Cek Status',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.purple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
