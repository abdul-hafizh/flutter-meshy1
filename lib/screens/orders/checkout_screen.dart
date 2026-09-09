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

/// Address -> berat paket -> cek ongkir (Biteship) -> pilih kurir -> metode
/// pembayaran -> "Pesan Sekarang". Only reachable once `order.isPriced` (the
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

  UserAddress? _selectedAddress;
  int? _selectedPaymentMethodId;

  final _weightCtrl = TextEditingController(text: '500');

  bool _checkingRates = false;
  String? _ratesError;
  List<ShippingRateOption> _rates = [];
  ShippingRateOption? _selectedRate;

  List<ShippingMethodCategory> _catalog = [];
  String? _selectedCategoryType;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
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
        PaymentMethodService.listMidtransMethods(token: token),
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
    }
  }

  Future<void> _checkRates() async {
    final token = _token;
    final address = _selectedAddress;
    final weight = int.tryParse(_weightCtrl.text.trim());
    if (token == null || address == null) return;
    if (weight == null || weight <= 0) {
      setState(() => _ratesError = 'Berat paket harus lebih dari 0 gram');
      return;
    }

    setState(() {
      _checkingRates = true;
      _ratesError = null;
      _rates = [];
      _selectedRate = null;
      _selectedCategoryType = null;
    });

    try {
      final rates = await ShippingRateService.checkRates(
        token: token,
        orderId: widget.order.id,
        userAddressId: address.id,
        packageWeightGrams: weight,
      );
      if (!mounted) return;
      final grouped = _groupRatesByCategory(rates);
      setState(() {
        _rates = rates;
        _selectedCategoryType = grouped.isNotEmpty ? grouped.keys.first : null;
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

  bool get _canSubmit =>
      _selectedAddress != null &&
      _selectedRate != null &&
      _selectedPaymentMethodId != null &&
      !_submitting;

  Future<void> _submit() async {
    final token = _token;
    final address = _selectedAddress;
    final rate = _selectedRate;
    if (token == null || address == null || rate == null || _selectedPaymentMethodId == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final match = matchRateToCatalog(rate, _catalog);
      await OrderService.checkout(
        token: token,
        orderId: widget.order.id,
        userAddressId: address.id,
        courierCompany: rate.courierCompany,
        courierType: rate.courierType,
        courierServiceName: rate.courierServiceName,
        packageWeightGrams: int.tryParse(_weightCtrl.text.trim()) ?? 500,
        shippingCost: rate.price,
        shippingMethodId: match?.method.id,
        shippingServiceId: match?.service?.id,
      );

      final payment = await OrderPaymentService.createSnapToken(
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

  @override
  Widget build(BuildContext context) {
    final itemAmount = widget.order.totalAmount ?? 0;
    final totalAmount = itemAmount + (_selectedRate?.price ?? 0);

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
                      const _SectionTitle('Alamat Pengiriman'),
                      const SizedBox(height: 10),
                      _AddressSection(address: _selectedAddress, onChange: _pickAddress),
                      const SizedBox(height: 22),
                      const _SectionTitle('Berat Paket'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          suffixText: 'gram',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _selectedAddress == null || _checkingRates ? null : _checkRates,
                        icon: _checkingRates
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.local_shipping_outlined, size: 18),
                        label: Text(_checkingRates ? 'Mengecek ongkos kirim...' : 'Cek Ongkir'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: AppColors.purple),
                          foregroundColor: AppColors.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                      ),
                      if (_ratesError != null) ...[
                        const SizedBox(height: 10),
                        Text(_ratesError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFE0453A), fontWeight: FontWeight.w600)),
                      ],
                      if (_rates.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const _SectionTitle('Kategori Pengiriman'),
                        const SizedBox(height: 10),
                        _ShippingCategoryChips(
                          categories: _groupRatesByCategory(_rates).keys.toList(),
                          selected: _selectedCategoryType,
                          labelOf: _categoryLabel,
                          onSelect: (key) => setState(() => _selectedCategoryType = key),
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle('Pilih Kurir'),
                        const SizedBox(height: 10),
                        _ShippingRateList(
                          rates: _groupRatesByCategory(_rates)[_selectedCategoryType] ?? const [],
                          selected: _selectedRate,
                          onSelect: (r) => setState(() => _selectedRate = r),
                          rupiah: _rupiah,
                        ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Harga Barang', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                Text(_rupiah(itemAmount), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ongkos Kirim', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                Text(
                                  _selectedRate != null ? _rupiah(_selectedRate!.price) : '-',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ],
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

