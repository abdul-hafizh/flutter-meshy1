import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_method.dart';
import '../../models/physical_order.dart';
import '../../models/shipping_catalog.dart';
import '../../models/shipping_rate.dart';
import '../../models/user_address.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/order_payment_service.dart';
import '../../services/order_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/shipping_rate_service.dart';
import '../../services/user_address_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../addresses/address_list_screen.dart';
import 'order_payment_webview_screen.dart';

/// Address -> ongkir dicek otomatis (Biteship) -> pilih jenis pengiriman
/// (Instan / Reguler / Kargo / Internasional) -> pilih kurir -> metode
/// pembayaran -> "Pesan Sekarang". The package weight is decided by the
/// merchant (order/product weight) — the customer never enters it. Only reachable once `order.isPriced` (the
/// merchant has quoted an item price) — enforced both by the caller
/// (OrderDetailScreen) and by the backend checkout endpoint itself. The
/// final amount charged is the merchant's item price plus whichever live
/// courier rate the customer picks here.
class CheckoutScreen extends StatefulWidget {
  final PhysicalOrder order;

  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loadingOptions = true;
  String? _loadError;

  List<PaymentMethodOption> _paymentMethods = [];

  /// "Ambil di Toko" is the default; courier rates are only quoted once the
  /// customer switches to "Kirim" (see _setPickup).
  bool _isPickup = true;
  UserAddress? _selectedAddress;
  int? _selectedPaymentMethodId;

  bool _checkingRates = false;
  String? _ratesError;
  List<ShippingRateOption> _rates = [];
  ShippingRateOption? _selectedRate;

  /// Weight the rates were quoted for, and where it came from (see ShippingQuote).
  int? _packageWeightGrams;
  String? _packageWeightSource;
  bool _destinationHasCoordinates = true;
  bool _originHasCoordinates = true;

  List<ShippingMethodCategory> _catalog = [];
  String? _selectedCategoryType;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        UserAddressService.listMine(token: token),
        PaymentMethodService.listDokuMethods(token: token),
      ]);
      final addresses = results[0] as List<UserAddress>;
      final paymentMethods = results[1] as List<PaymentMethodOption>;

      if (!mounted) return;
      setState(() {
        _paymentMethods = paymentMethods;
        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        }
      });

      // Best-effort — without it, live rates just aren't grouped by
      // category (everything falls under "Lainnya"), checkout still works.
      try {
        final catalog = await ShippingRateService.listCatalog(token: token);
        if (mounted) setState(() => _catalog = catalog);
      } catch (_) {
        // ignore
      }

      // Rates are quoted straight away — nothing for the customer to fill in.
      if (mounted && !_isPickup && _selectedAddress != null) unawaited(_checkRates());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Gagal memuat opsi checkout.');
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<UserAddress>(
      MaterialPageRoute(builder: (_) => const AddressListScreen(selectMode: true)),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result;
        _rates = [];
        _selectedRate = null;
      });
      unawaited(_checkRates());
    }
  }

  void _setPickup(bool pickup) {
    setState(() => _isPickup = pickup);
    if (!pickup && _rates.isEmpty && !_checkingRates && _selectedAddress != null) {
      unawaited(_checkRates());
    }
  }

  Future<void> _checkRates() async {
    final token = _token;
    final address = _selectedAddress;
    if (token == null || address == null) return;

    setState(() {
      _checkingRates = true;
      _ratesError = null;
      _rates = [];
      _selectedRate = null;
      _selectedCategoryType = null;
    });

    try {
      final quote = await ShippingRateService.checkRates(
        token: token,
        orderId: widget.order.id,
        userAddressId: address.id,
      );
      if (!mounted) return;
      final rates = quote.rates;
      setState(() {
        _rates = rates;
        // The customer picks the delivery type first (Instan / Reguler / ...),
        // then the courier within it.
        _selectedCategoryType = null;
        _packageWeightGrams = quote.packageWeightGrams;
        _packageWeightSource = quote.packageWeightSource;
        _destinationHasCoordinates = quote.destinationHasCoordinates;
        _originHasCoordinates = quote.originHasCoordinates;
      });
      if (rates.isEmpty) {
        setState(() => _ratesError = 'Tidak ada kurir yang tersedia untuk rute ini.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ratesError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ratesError = 'Gagal mengecek ongkos kirim. Coba lagi.');
    } finally {
      if (mounted) setState(() => _checkingRates = false);
    }
  }

  static const _otherCategoryKey = 'OTHER';
  static const _categoryOrder = [
    'INSTANT_SHIPMENT',
    'REGULAR_SHIPMENT',
    'REGULAR_CARGO_SHIPMENT',
    'INTERNATIONAL_CARGO_SHIPMENT',
    'INTERNAL_SHIPMENT',
    _otherCategoryKey,
  ];

  /// Groups live Biteship rates by our shipping catalog's category — a rate
  /// whose courier isn't in the catalog yet falls under "Lainnya" instead
  /// of being dropped. Ordered Instant -> Regular -> Cargo -> International
  /// -> Lainnya, matching how the categories read in the dashboard.
  Map<String, List<ShippingRateOption>> _groupRatesByCategory(List<ShippingRateOption> rates) {
    final map = <String, List<ShippingRateOption>>{};
    for (final rate in rates) {
      final key = matchRateToCatalog(rate, _catalog)?.method.shippingType ?? _otherCategoryKey;
      map.putIfAbsent(key, () => []).add(rate);
    }
    final ordered = <String, List<ShippingRateOption>>{};
    for (final key in _categoryOrder) {
      if (map.containsKey(key)) ordered[key] = map[key]!;
    }
    for (final entry in map.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  String _categoryLabel(String key) => key == _otherCategoryKey ? 'Lainnya' : shippingCategoryLabel(key);

  /// Why Instan (Gojek/Grab) is missing, when it is — Biteship only quotes
  /// instant couriers for addresses that have a map pin.
  String? get _instantHint {
    if (_groupRatesByCategory(_rates).containsKey('INSTANT_SHIPMENT')) return null;
    if (!_destinationHasCoordinates) {
      return 'Pengiriman Instan (Gojek/Grab) butuh titik lokasi alamatmu. Ubah alamat lalu tekan "Gunakan Lokasi Saat Ini" untuk mengaktifkannya.';
    }
    if (!_originHasCoordinates) {
      return 'Pengiriman Instan (Gojek/Grab) belum tersedia karena lokasi toko penjual belum diatur.';
    }
    return null;
  }

  bool get _canSubmit =>
      _isPickup
          ? (_selectedPaymentMethodId != null && !_submitting)
          : (_selectedAddress != null &&
              _selectedRate != null &&
              _selectedPaymentMethodId != null &&
              !_submitting);

  Future<void> _submit() async {
    final token = _token;
    if (token == null || _selectedPaymentMethodId == null) return;

    if (!_isPickup) {
      final address = _selectedAddress;
      final rate = _selectedRate;
      if (address == null || rate == null) return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      if (_isPickup) {
        await OrderService.checkoutPickup(token: token, orderId: widget.order.id);
      } else {
        final address = _selectedAddress!;
        final rate = _selectedRate!;
        final match = matchRateToCatalog(rate, _catalog);
        await OrderService.checkout(
          token: token,
          orderId: widget.order.id,
          userAddressId: address.id,
          courierCompany: rate.courierCompany,
          courierType: rate.courierType,
          courierServiceName: rate.courierServiceName,
          shippingCost: rate.price,
          shippingMethodId: match?.method.id,
          shippingServiceId: match?.service?.id,
        );
      }

      final payment = await OrderPaymentService.createCheckout(
        token: token,
        orderId: widget.order.id,
        paymentMethodId: _selectedPaymentMethodId,
      );

      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OrderPaymentWebViewScreen(
            redirectUrl: payment.redirectUrl,
            paymentId: payment.paymentId,
          ),
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } catch (_) {
      setState(() => _submitError = 'Gagal memproses pesanan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  Widget _priceRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final itemAmount = order.totalAmount ?? 0;
    final totalAmount = itemAmount + (_isPickup ? 0 : (_selectedRate?.price ?? 0));
    final subtotalAmount = order.subtotalAmount;
    final discountAmount = order.discountAmount ?? 0;
    final taxAmount = order.taxAmount;
    final appFeeAmount = order.appFeeAmount;
    final hasBreakdown = subtotalAmount != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _loadingOptions
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      const _SectionTitle('Metode Pengiriman'),
                      const SizedBox(height: 10),
                      _DeliveryModeToggle(
                        isPickup: _isPickup,
                        onChanged: _setPickup,
                      ),
                      const SizedBox(height: 22),
                      if (_isPickup) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.storefront_rounded, size: 20, color: AppColors.purple),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.merchant?.fullName ?? 'Toko Merchant',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Ambil pesanan langsung di toko — gratis, tanpa ongkos kirim. Merchant akan menghubungimu saat pesanan siap diambil.',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const _SectionTitle('Alamat Pengiriman'),
                        const SizedBox(height: 10),
                        _AddressSection(address: _selectedAddress, onChange: _pickAddress),
                        const SizedBox(height: 22),
                        if (_packageWeightGrams != null) ...[
                          _PackageWeightNote(grams: _packageWeightGrams!, source: _packageWeightSource),
                          const SizedBox(height: 14),
                        ],
                        if (_checkingRates)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Mengecek ongkos kirim...', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        if (_ratesError != null && !_checkingRates) ...[
                          Text(_ratesError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFE0453A), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _selectedAddress == null ? null : _checkRates,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Cek Ulang Ongkir'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.purple),
                              foregroundColor: AppColors.purple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(double.infinity, 0),
                            ),
                          ),
                        ],
                        if (_rates.isNotEmpty && !_checkingRates) ...[
                          const _SectionTitle('Jenis Pengiriman'),
                          const SizedBox(height: 10),
                          _ShippingCategoryChips(
                            categories: _groupRatesByCategory(_rates).keys.toList(),
                            selected: _selectedCategoryType,
                            labelOf: _categoryLabel,
                            onSelect: (key) => setState(() {
                              if (_selectedCategoryType != key) _selectedRate = null;
                              _selectedCategoryType = key;
                            }),
                          ),
                          if (_instantHint != null) ...[
                            const SizedBox(height: 10),
                            _InfoNote(text: _instantHint!),
                          ],
                          const SizedBox(height: 16),
                          if (_selectedCategoryType == null)
                            const Text(
                              'Pilih jenis pengiriman untuk melihat kurir yang tersedia.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            )
                          else ...[
                            _SectionTitle('Kurir ${_categoryLabel(_selectedCategoryType!)}'),
                            const SizedBox(height: 10),
                            _ShippingRateList(
                              rates: _groupRatesByCategory(_rates)[_selectedCategoryType] ?? const [],
                              selected: _selectedRate,
                              onSelect: (r) => setState(() => _selectedRate = r),
                              rupiah: _rupiah,
                            ),
                          ],
                        ],
                      ],
                      const SizedBox(height: 22),
                      const _SectionTitle('Metode Pembayaran'),
                      const SizedBox(height: 10),
                      if (_paymentMethods.isEmpty)
                        const Text('Belum ada metode pembayaran aktif.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _selectedPaymentMethodId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          ),
                          hint: const Text('Pilih metode pembayaran'),
                          items: [
                            for (final pm in _paymentMethods) DropdownMenuItem(value: pm.id, child: Text(pm.name)),
                          ],
                          onChanged: (v) => setState(() => _selectedPaymentMethodId = v),
                        ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            if (hasBreakdown) ...[
                              _priceRow('Harga Barang', _rupiah(subtotalAmount)),
                              if (discountAmount > 0) _priceRow(order.tierDiscountLabel, '-${_rupiah(discountAmount)}', valueColor: const Color(0xFF1FAA59)),
                              if (taxAmount != null) _priceRow('PPN', _rupiah(taxAmount)),
                              if (appFeeAmount != null) _priceRow('Biaya Layanan Aplikasi', _rupiah(appFeeAmount)),
                            ] else
                              _priceRow('Harga Barang', _rupiah(itemAmount)),
                            _priceRow(
                              'Ongkos Kirim',
                              _isPickup
                                  ? 'Gratis (Ambil di Toko)'
                                  : (_selectedRate != null ? _rupiah(_selectedRate!.price) : '-'),
                            ),
                            const Divider(height: 20, color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pembayaran', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text(
                                  _rupiah(totalAmount),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0453A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(_submitError!, style: const TextStyle(fontSize: 13, color: Color(0xFFE0453A), fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GradientButton(
                        label: _submitting ? 'Memproses...' : 'Pesan Sekarang',
                        icon: _submitting ? null : Icons.shopping_bag_rounded,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary));
  }
}

/// "Kirim" (courier, live Biteship rates) vs "Ambil di Toko" (pick up, free,
/// no address/rate step needed) — two equal-width segments.
class _DeliveryModeToggle extends StatelessWidget {
  final bool isPickup;
  final ValueChanged<bool> onChanged;

  const _DeliveryModeToggle({required this.isPickup, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(label: 'Kirim', icon: Icons.local_shipping_outlined, selected: !isPickup, onTap: () => onChanged(false))),
          Expanded(child: _segment(label: 'Ambil di Toko', icon: Icons.storefront_rounded, selected: isPickup, onTap: () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  final UserAddress? address;
  final VoidCallback onChange;

  const _AddressSection({required this.address, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: a == null
          ? Row(
              children: [
                const Expanded(
                  child: Text('Belum ada alamat tersimpan', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
                TextButton(onPressed: onChange, child: const Text('Tambah')),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 20, color: AppColors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.label} · ${a.recipientName ?? ''}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(a.summaryLine, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(onPressed: onChange, child: const Text('Ganti')),
              ],
            ),
    );
  }
}

/// Category selector shown above the courier list — "Instan / Reguler /
/// Kargo / Internasional / Lainnya", only the categories that actually have
/// a live rate for this route/weight.
class _ShippingCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final String Function(String) labelOf;
  final ValueChanged<String> onSelect;

  const _ShippingCategoryChips({
    required this.categories,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in categories)
          ChoiceChip(
            label: Text(labelOf(key)),
            selected: key == selected,
            onSelected: (_) => onSelect(key),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: key == selected ? Colors.white : AppColors.textPrimary,
            ),
            selectedColor: AppColors.purple,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: key == selected ? AppColors.purple : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
      ],
    );
  }
}

class _ShippingRateList extends StatelessWidget {
  final List<ShippingRateOption> rates;
  final ShippingRateOption? selected;
  final ValueChanged<ShippingRateOption> onSelect;
  final String Function(int) rupiah;

  const _ShippingRateList({required this.rates, required this.selected, required this.onSelect, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final rate in rates)
            RadioListTile<String>(
              value: '${rate.courierCompany}_${rate.courierType}',
              groupValue: selected != null ? '${selected!.courierCompany}_${selected!.courierType}' : null,
              onChanged: (_) => onSelect(rate),
              dense: true,
              activeColor: AppColors.purple,
              title: Text(rate.courierDisplayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: rate.duration != null ? Text('Estimasi ${rate.duration}', style: const TextStyle(fontSize: 11.5)) : null,
              secondary: Text(
                rupiah(rate.price),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}


/// "Berat paket: 500 gram" — read-only; the merchant decides it.
class _PackageWeightNote extends StatelessWidget {
  final int grams;
  final String? source;

  const _PackageWeightNote({required this.grams, this.source});

  @override
  Widget build(BuildContext context) {
    final weight = grams >= 1000 && grams % 100 == 0 ? '${(grams / 1000).toStringAsFixed(grams % 1000 == 0 ? 0 : 1)} kg' : '$grams gram';
    final note = source == 'DEFAULT' ? 'perkiraan standar' : 'ditentukan penjual';
    return Row(
      children: [
        const Icon(Icons.scale_rounded, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('Berat paket: $weight', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        Text(' · $note', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;

  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
