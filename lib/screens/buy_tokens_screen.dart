import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:provider/provider.dart';

import '../models/token_package.dart';
import '../providers/auth_controller.dart';
import '../services/ai_credit_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/play_billing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'payment_webview_screen.dart';
import 'token_history_screen.dart';

class BuyTokensScreen extends StatefulWidget {
  const BuyTokensScreen({super.key});

  @override
  State<BuyTokensScreen> createState() => _BuyTokensScreenState();
}

class _BuyTokensScreenState extends State<BuyTokensScreen> {
  TokenPackage _selected = TokenPackage.all.first;
  bool _submitting = false;
  String? _error;

  /// On Android, tokens are sold through Google Play Billing (Play policy for
  /// digital goods) — packages and prices come from Play Console. Other
  /// platforms keep the DOKU flow.
  final bool _usePlay = PlayBillingService.isSupported;
  bool _loadingProducts = false;
  List<ProductDetails> _playProducts = const [];
  String? _selectedProductId;
  StreamSubscription<PlayBillingEvent>? _playEvents;

  @override
  void initState() {
    super.initState();
    if (_usePlay) {
      _playEvents = PlayBillingService.instance.events.listen(_onPlayEvent);
      _loadPlayProducts();
    }
  }

  @override
  void dispose() {
    _playEvents?.cancel();
    super.dispose();
  }

  Future<void> _loadPlayProducts() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });
    try {
      final products = await PlayBillingService.instance.loadProducts();
      if (!mounted) return;
      setState(() {
        _playProducts = products;
        _selectedProductId = products.isNotEmpty ? products.first.id : null;
        if (products.isEmpty) {
          _error = 'Paket token belum tersedia. Pastikan aplikasi di-install dari Google Play.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat paket token dari Google Play.');
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _onPlayEvent(PlayBillingEvent event) {
    if (!mounted) return;
    switch (event) {
      case PlayBillingCredited(:final quantity):
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$quantity token berhasil ditambahkan.')),
        );
      case PlayBillingPending():
        setState(() {
          _submitting = false;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran sedang diproses Google Play. Token masuk otomatis setelah lunas.')),
        );
      case PlayBillingCanceled():
        setState(() => _submitting = false);
      case PlayBillingFailed(:final message):
        setState(() {
          _submitting = false;
          _error = message;
        });
    }
  }

  Future<void> _buyWithPlay() async {
    final product = _playProducts.where((p) => p.id == _selectedProductId).firstOrNull;
    if (product == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PlayBillingService.instance.buy(product);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Gagal membuka pembayaran Google Play.';
        });
      }
    }
  }

  Future<void> _buy() async {
    if (_usePlay) return _buyWithPlay();
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await AiCreditService.purchase(token: token, quantity: _selected.quantity);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            redirectUrl: result.redirectUrl,
            paymentId: result.paymentId,
            quantity: result.quantity,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {});
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<AuthController>().user?.credits ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beli Token AI'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TokenHistoryScreen()),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Riwayat'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowFor(AppColors.purple), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.toll_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Token kamu saat ini',
                          style: TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$credits Token',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Pilih Paket Token',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              '1x generate (text-to-3D atau image-to-3D) membutuhkan 40 token.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            if (_usePlay && _loadingProducts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_usePlay)
              for (final product in _playProducts) ...[
                _PackageCard(
                  quantity: PlayBillingService.quantityOf(product.id),
                  priceLabel: product.price,
                  selected: product.id == _selectedProductId,
                  onTap: () => setState(() => _selectedProductId = product.id),
                ),
                const SizedBox(height: 12),
              ]
            else
              for (final pkg in TokenPackage.all) ...[
                _PackageCard(
                  quantity: pkg.quantity,
                  priceLabel: 'Rp${_formatRupiah(pkg.price)}',
                  selected: pkg.quantity == _selected.quantity,
                  onTap: () => setState(() => _selected = pkg),
                ),
                const SizedBox(height: 12),
              ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0453A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0453A).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE0453A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFE0453A), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            GradientButton(
              label: _submitting ? 'Memproses...' : 'Beli Sekarang',
              icon: _submitting ? null : Icons.arrow_forward_rounded,
              onPressed: _submitting || (_usePlay && _selectedProductId == null) ? null : _buy,
            ),
            if (_usePlay && !_loadingProducts && _playProducts.isEmpty) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: _loadPlayProducts, child: const Text('Muat ulang paket')),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatRupiah(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

class _PackageCard extends StatelessWidget {
  final int quantity;

  /// Already formatted — Google Play's localized price, or our Rupiah price.
  final String priceLabel;
  final bool selected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.quantity,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.purple : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.brandGradient : null,
                  color: selected ? null : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.toll_rounded,
                  size: 22,
                  color: selected ? Colors.white : AppColors.textFaint,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$quantity Token',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceLabel,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.purple : AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
