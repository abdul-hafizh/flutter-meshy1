import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/ai_credit_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/invoice_service.dart';
import '../theme/app_theme.dart';

/// The user's token ledger: every purchase (+) and every generation that
/// spent tokens (-), newest first, with the balance after each entry.
/// Purchases offer that purchase's invoice.
class TokenHistoryScreen extends StatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  State<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends State<TokenHistoryScreen> {
  static const _success = Color(0xFF2FB380);

  final List<TokenTransaction> _items = [];
  int _balance = 0;
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _openingInvoiceFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AiCreditService.listHistory(token: token, page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _balance = page.balance;
        _page = 1;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat riwayat token.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final token = context.read<AuthController>().token;
    if (token == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AiCreditService.listHistory(token: token, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page += 1;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat data berikutnya.')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openInvoice(TokenTransaction entry) async {
    final token = context.read<AuthController>().token;
    final orderId = entry.orderId;
    if (token == null || orderId == null) return;
    setState(() => _openingInvoiceFor = entry.id);
    try {
      await InvoiceService.open(token: token, orderId: orderId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka invoice. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _openingInvoiceFor = null);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _title(TokenTransaction e) {
    if (e.description.isNotEmpty) return e.description;
    if (e.isPurchase) return 'Pembelian token';
    if (e.isUsage) return 'Pemakaian token';
    return 'Penyesuaian saldo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Token'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : RefreshIndicator(onRefresh: _load, child: _buildList()),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo token', style: TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600)),
                    Text('$_balance Token', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Belum ada riwayat token.\nBeli token untuk mulai membuat model 3D.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          )
        else ...[
          for (final entry in _items) ...[
            _buildEntry(entry),
            const SizedBox(height: 10),
          ],
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Memuat...' : 'Muat lebih banyak'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEntry(TokenTransaction e) {
    final positive = e.amount > 0;
    final color = positive ? _success : AppColors.purple;
    final canInvoice = e.isPurchase && e.orderId != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(
                  e.isPurchase
                      ? Icons.add_shopping_cart_rounded
                      : e.isUsage
                          ? Icons.auto_awesome_rounded
                          : Icons.tune_rounded,
                  size: 19,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(e.createdAt),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${positive ? '+' : ''}${e.amount}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text('Saldo ${e.balanceAfter}', style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
                ],
              ),
            ],
          ),
          if (canInvoice)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openingInvoiceFor == e.id ? null : () => _openInvoice(e),
                icon: _openingInvoiceFor == e.id
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Invoice'),
              ),
            ),
        ],
      ),
    );
  }
}
