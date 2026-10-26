import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart.dart';
import '../../models/payment_method.dart';
import '../../models/shipping_catalog.dart';
import '../../models/shipping_rate.dart';
import '../../models/user_address.dart';
import '../../providers/auth_controller.dart';
import '../../providers/cart_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/cart_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/shipping_rate_service.dart';
import '../../services/user_address_service.dart';
import '../../services/location_gate.dart';
import '../../providers/active_address_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/store_status.dart';
import '../../widgets/checkout/shipping_widgets.dart';
import '../../widgets/gradient_button.dart';
import '../addresses/address_list_screen.dart';
import '../orders/order_payment_webview_screen.dart';

/// Delivery choice for one store's part of the cart.
class _StoreShipping {
  bool isPickup = true;
  bool checking = false;
  String? error;
  List<ShippingRateOption> rates = [];
  String? category;
  ShippingRateOption? rate;
  bool destinationHasCoordinates = true;
  bool originHasCoordinates = true;
  int? weightGrams;
  String? weightSource;
  final TextEditingController note = TextEditingController();

  /// Bumped on every new quote so a slow, outdated response is ignored.
  int requestId = 0;

  bool get ready => isPickup || rate != null;
  int get shippingCost => isPickup ? 0 : (rate?.price ?? 0);
}

/// Checkout of the selected cart lines. Every store is its own order with
/// its own delivery — courier rates are quoted from THAT store's address,
/// or "Ambil di Toko" (default) — and all of them are paid on one DOKU page.
class CartCheckoutScreen extends StatefulWidget {
  final List<String> cartItemIds;

  const CartCheckoutScreen({super.key, required this.cartItemIds});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  bool _loading = true;
  String? _loadError;
  List<CartCheckoutGroup> _groups = [];
  final Map<String, _StoreShipping> _shipping = {};
  List<PaymentMethodOption> _paymentMethods = [];
  List<ShippingMethodCategory> _catalog = [];
  UserAddress? _address;
  int? _paymentMethodId;
  bool _submitting = false;
  String? _submitError;

  String? get _token => context.read<AuthController>().token;

  _StoreShipping _shipFor(CartCheckoutGroup g) => _shipping.putIfAbsent(g.merchantId, () => _StoreShipping());

  bool get _anyCourier => _groups.any((g) => !_shipFor(g).isPickup);
  int get _grandTotal => _groups.fold(0, (sum, g) => sum + g.totalAmount + _shipFor(g).shippingCost - g.promoDiscount);

  // A store's order holding AI designs waits for the store to confirm the
  // print weight (= the price) — it's paid later from "Pesanan".
  bool _awaitsStore(CartCheckoutGroup g) => g.items.any((i) => i.isDesign);
  bool get _anyAwaiting => _groups.any(_awaitsStore);
  int get _payNowTotal =>
      _groups.where((g) => !_awaitsStore(g)).fold(0, (sum, g) => sum + g.totalAmount + _shipFor(g).shippingCost - g.promoDiscount);

  bool get _canSubmit =>
      !_submitting &&
      _groups.isNotEmpty &&
      (_paymentMethodId != null || _payNowTotal == 0) &&
      _groups.every((g) => _shipFor(g).ready) &&
      (!_anyCourier || _address != null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final s in _shipping.values) {
      s.note.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        CartService.preview(token: token, cartItemIds: widget.cartItemIds),
        UserAddressService.listMine(token: token),
        PaymentMethodService.listDokuMethods(token: token),
      ]);
      final addresses = results[1] as List<UserAddress>;
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<CartCheckoutGroup>;
        _paymentMethods = results[2] as List<PaymentMethodOption>;
        if (addresses.isNotEmpty) {
          // The delivery address chosen on the home screen, else the main one.
          final activeId = context.read<ActiveAddressController>().address?.id;
          _address = addresses.firstWhere(
            (a) => a.id == activeId,
            orElse: () => addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first),
          );
        }
      });
      try {
        final catalog = await ShippingRateService.listCatalog(token: token);
        if (mounted) setState(() => _catalog = catalog);
      } catch (_) {
        // Rates just aren't grouped by category without it.
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Gagal menyiapkan checkout.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quote(CartCheckoutGroup g) async {
    final token = _token;
    final address = _address;
    final ship = _shipFor(g);
    if (token == null || address == null || ship.isPickup) return;
    final requestId = ++ship.requestId;
    setState(() {
      ship
        ..checking = true
        ..error = null
        ..rates = []
        ..rate = null
        ..category = null;
    });
    try {
      final quote = await CartService.shippingRates(
        token: token,
        cartItemIds: widget.cartItemIds,
        merchantId: g.merchantId,
        userAddressId: address.id,
      );
      if (!mounted || requestId != ship.requestId) return;
      setState(() {
        ship
          ..rates = quote.rates
          ..weightGrams = quote.packageWeightGrams
          ..weightSource = quote.packageWeightSource
          ..destinationHasCoordinates = quote.destinationHasCoordinates
          ..originHasCoordinates = quote.originHasCoordinates;
        if (quote.rates.isEmpty) ship.error = 'Tidak ada kurir yang tersedia untuk rute ini.';
      });
    } on ApiException catch (e) {
      if (mounted && requestId == ship.requestId) setState(() => ship.error = e.message);
    } catch (_) {
      if (mounted && requestId == ship.requestId) setState(() => ship.error = 'Gagal mengecek ongkos kirim. Coba lagi.');
    } finally {
      if (mounted && requestId == ship.requestId) setState(() => ship.checking = false);
    }
  }

  void _setPickup(CartCheckoutGroup g, bool pickup) {
    final ship = _shipFor(g);
    setState(() => ship.isPickup = pickup);
    if (!pickup && ship.rates.isEmpty && !ship.checking) unawaited(_quote(g));
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<UserAddress>(
      MaterialPageRoute(builder: (_) => const AddressListScreen(selectMode: true)),
    );
    if (result == null || !mounted) return;
    unawaited(context.read<ActiveAddressController>().select(result));
    setState(() => _address = result);
    // Every store shipping by courier needs a fresh quote to the new address.
    for (final g in _groups.where((g) => !_shipFor(g).isPickup)) {
      unawaited(_quote(g));
    }
  }

  Future<void> _submit() async {
    final token = _token;
    if (token == null || !_canSubmit) return;
    if (!await LocationGate.ensureEnabled(context) || !mounted) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final shipping = <String, Map<String, dynamic>>{};
      final notes = <String, String>{};
      for (final g in _groups) {
        final ship = _shipFor(g);
        if (ship.isPickup) {
          shipping[g.merchantId] = {'IsPickup': true};
        } else {
          final rate = ship.rate!;
          final match = matchRateToCatalog(rate, _catalog);
          shipping[g.merchantId] = {
            'IsPickup': false,
            'CourierCompany': rate.courierCompany,
            'CourierType': rate.courierType,
            'CourierServiceName': rate.courierServiceName,
            'ShippingMethodId': match?.method.id,
            'ShippingServiceId': match?.service?.id,
          };
        }
        final note = ship.note.text.trim();
        if (note.isNotEmpty) notes[g.merchantId] = note;
      }

      final result = await CartService.checkout(
        token: token,
        cartItemIds: widget.cartItemIds,
        shipping: shipping,
        notes: notes,
        userAddressId: _anyCourier ? _address?.id : null,
        paymentMethodId: _paymentMethodId,
      );
      if (!mounted) return;
      // The bought lines are gone from the cart now.
      unawaited(context.read<CartController>().refresh(token));

      const awaitingText = 'Pesanan desain AI dikirim ke toko. Toko akan memeriksa berat cetak dan mengonfirmasi harganya — '
          'setelah itu kamu bisa membayarnya dari menu Pesanan.';
      if (!result.hasPayment) {
        await _info(
          result.awaitingConfirmation > 0 && result.paymentError == null ? 'Menunggu konfirmasi toko' : 'Pesanan sudah dibuat',
          result.paymentError ??
              (result.awaitingConfirmation > 0
                  ? awaitingText
                  : 'Halaman pembayaran gagal dibuka. Kamu bisa membayar dari menu Pesanan.'),
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OrderPaymentWebViewScreen(redirectUrl: result.redirectUrl!, paymentId: result.paymentId!),
        ),
      );
      if (!mounted) return;
      if (paid != true) {
        await _info(
          'Menunggu pembayaran',
          '${result.orderIds.length} pesanan sudah dibuat. Selesaikan pembayaran sebelum batas waktunya — '
              'kamu bisa melanjutkannya dari menu Pesanan.',
        );
      }
      if (mounted && result.awaitingConfirmation > 0) await _info('Menunggu konfirmasi toko', awaitingText);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _submitError = e.message);
    } catch (_) {
      if (mounted) setState(() => _submitError = 'Gagal memproses checkout. Coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _info(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout Keranjang'), backgroundColor: AppColors.surface, elevation: 0),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (_anyCourier) ...[
                        const CheckoutSectionTitle('Alamat Pengiriman'),
                        const SizedBox(height: 10),
                        CheckoutAddressSection(address: _address, onChange: _pickAddress),
                        const SizedBox(height: 18),
                      ],
                      if (_anyAwaiting) ...[
                        const CheckoutInfoNote(
                          text: 'Desain AI: berat di aplikasi masih perkiraan. Toko akan memeriksa berat cetak dan '
                              'mengonfirmasi harganya dulu — kamu membayarnya dari menu Pesanan setelah dikonfirmasi.',
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_groups.length > 1) ...[
                        CheckoutInfoNote(
                          text: 'Produk dari ${_groups.length} toko berbeda dikirim terpisah — pilih pengiriman untuk '
                              'tiap toko. Semua dibayar sekaligus dalam satu pembayaran.',
                        ),
                        const SizedBox(height: 14),
                      ],
                      for (final g in _groups) ...[
                        _StoreCheckoutCard(
                          group: g,
                          ship: _shipFor(g),
                          catalog: _catalog,
                          hasAddress: _address != null,
                          onPickup: (v) => _setPickup(g, v),
                          onRetry: () => _quote(g),
                          onSelectCategory: (key) => setState(() {
                            final ship = _shipFor(g);
                            if (ship.category != key) ship.rate = null;
                            ship.category = key;
                          }),
                          onSelectRate: (r) => setState(() => _shipFor(g).rate = r),
                          onPickAddress: _pickAddress,
                        ),
                        const SizedBox(height: 14),
                      ],
                      const CheckoutSectionTitle('Metode Pembayaran'),
                      const SizedBox(height: 10),
                      if (_paymentMethods.isEmpty)
                        const Text('Belum ada metode pembayaran aktif.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _paymentMethodId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          ),
                          hint: const Text('Pilih metode pembayaran'),
                          items: [for (final pm in _paymentMethods) DropdownMenuItem(value: pm.id, child: Text(pm.name))],
                          onChanged: (v) => setState(() => _paymentMethodId = v),
                        ),
                      const SizedBox(height: 18),
                      _GrandTotalCard(groups: _groups, shippingOf: (g) => _shipFor(g), total: _grandTotal),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0453A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _submitError!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFE0453A), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      GradientButton(
                        label: _submitting
                            ? 'Memproses...'
                            : _payNowTotal == 0
                                ? 'Kirim ke Toko untuk Konfirmasi'
                                : 'Bayar ${rupiahLabel(_payNowTotal)}',
                        icon: _submitting ? null : Icons.lock_rounded,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                      if (!_canSubmit && !_submitting) ...[
                        const SizedBox(height: 8),
                        Text(
                          _paymentMethodId == null && _payNowTotal > 0
                              ? 'Pilih metode pembayaran untuk melanjutkan.'
                              : (_anyCourier && _address == null)
                                  ? 'Tambahkan alamat pengiriman untuk toko yang dikirim kurir.'
                                  : 'Pilih kurir untuk setiap toko yang dikirim.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _StoreCheckoutCard extends StatelessWidget {
  final CartCheckoutGroup group;
  final _StoreShipping ship;
  final List<ShippingMethodCategory> catalog;
  final bool hasAddress;
  final ValueChanged<bool> onPickup;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<ShippingRateOption> onSelectRate;
  final VoidCallback onPickAddress;

  const _StoreCheckoutCard({
    required this.group,
    required this.ship,
    required this.catalog,
    required this.hasAddress,
    required this.onPickup,
    required this.onRetry,
    required this.onSelectCategory,
    required this.onSelectRate,
    required this.onPickAddress,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = groupRatesByCategory(ship.rates, catalog);
    final hint = instantShippingHint(
      grouped: grouped,
      destinationHasCoordinates: ship.destinationHasCoordinates,
      originHasCoordinates: ship.originHasCoordinates,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceMuted,
                backgroundImage: group.merchantAvatar != null ? NetworkImage(group.merchantAvatar!) : null,
                child: group.merchantAvatar == null
                    ? const Icon(Icons.storefront_rounded, size: 15, color: AppColors.purple)
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  group.storeName,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              StoreStatusBadge(status: group.operatingStatus),
            ],
          ),
          if (group.operatingStatus?.isClosed == true) ...[
            const SizedBox(height: 10),
            ClosedStoreNotice(status: group.operatingStatus),
          ],
          const SizedBox(height: 10),
          for (final line in group.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.displayName} × ${line.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(rupiahLabel(line.lineTotal), style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                ],
              ),
            ),
          const Divider(height: 22, color: AppColors.border),
          const Text('Pengiriman', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          DeliveryModeToggle(isPickup: ship.isPickup, onChanged: onPickup),
          const SizedBox(height: 10),
          if (ship.isPickup)
            Text(
              'Ambil langsung di ${group.storeName} — gratis. Penjual akan menghubungimu saat pesanan siap diambil.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else if (!hasAddress)
            Row(
              children: [
                const Expanded(
                  child: Text('Tambahkan alamat untuk cek ongkir.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ),
                TextButton(onPressed: onPickAddress, child: const Text('Pilih Alamat')),
              ],
            )
          else ...[
            if (ship.weightGrams != null) ...[
              PackageWeightNote(grams: ship.weightGrams!, source: ship.weightSource),
              const SizedBox(height: 10),
            ],
            if (ship.checking)
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Mengecek ongkos kirim...', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              )
            else if (ship.error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ship.error!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFE0453A), fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Cek ulang')),
                ],
              )
            else if (ship.rates.isNotEmpty) ...[
              ShippingCategoryChips(
                categories: grouped.keys.toList(),
                selected: ship.category,
                labelOf: rateCategoryLabel,
                onSelect: onSelectCategory,
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                CheckoutInfoNote(text: hint),
              ],
              const SizedBox(height: 10),
              if (ship.category == null)
                const Text(
                  'Pilih jenis pengiriman untuk melihat kurir.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                )
              else
                ShippingRateList(
                  rates: grouped[ship.category] ?? const [],
                  selected: ship.rate,
                  onSelect: onSelectRate,
                  rupiah: rupiahLabel,
                ),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            controller: ship.note,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Catatan untuk penjual (opsional)',
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const Divider(height: 22, color: AppColors.border),
          _priceRow('Harga barang', rupiahLabel(group.subtotalAmount)),
          if (group.discountAmount > 0)
            _priceRow('Diskon tier', '-${rupiahLabel(group.discountAmount)}', valueColor: const Color(0xFF1FAA59)),
          if (group.appFeeAmount > 0) _priceRow('Biaya layanan aplikasi', rupiahLabel(group.appFeeAmount)),
          if (group.taxAmount > 0) _priceRow('PPN', rupiahLabel(group.taxAmount)),
          _priceRow(
            'Ongkos kirim',
            ship.isPickup ? 'Gratis' : (ship.rate != null ? rupiahLabel(ship.rate!.price) : '-'),
          ),
          if (group.promoDiscount > 0)
            _priceRow(
              group.promoTitle != null ? 'Promo: ${group.promoTitle}' : 'Promo Petope',
              '-${rupiahLabel(group.promoDiscount)}',
              valueColor: const Color(0xFF1FAA59),
            ),
          _priceRow('Subtotal toko', rupiahLabel(group.totalAmount + ship.shippingCost - group.promoDiscount), bold: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false, Color? valueColor}) {
    final weight = bold ? FontWeight.w800 : FontWeight.w400;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: weight, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: weight, color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _GrandTotalCard extends StatelessWidget {
  final List<CartCheckoutGroup> groups;
  final _StoreShipping Function(CartCheckoutGroup) shippingOf;
  final int total;

  const _GrandTotalCard({required this.groups, required this.shippingOf, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = groups.fold(0, (sum, g) => sum + g.totalAmount);
    final shipping = groups.fold(0, (sum, g) => sum + shippingOf(g).shippingCost);
    final promo = groups.fold(0, (sum, g) => sum + g.promoDiscount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Total belanja (${groups.length} toko)', rupiahLabel(items)),
          _row('Total ongkos kirim', rupiahLabel(shipping)),
          if (promo > 0) _row('Promo Petope', '-${rupiahLabel(promo)}'),
          const Divider(height: 20, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(rupiahLabel(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      );
}
