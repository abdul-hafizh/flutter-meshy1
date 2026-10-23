import 'package:flutter/material.dart';

import '../../models/shipping_catalog.dart';
import '../../models/shipping_rate.dart';
import '../../models/user_address.dart';
import '../../theme/app_theme.dart';

// Shipping building blocks shared by the single-order CheckoutScreen and the
// cart's CartCheckoutScreen, so both present delivery choices the same way.

const _otherCategoryKey = 'OTHER';
const _categoryOrder = [
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
Map<String, List<ShippingRateOption>> groupRatesByCategory(
  List<ShippingRateOption> rates,
  List<ShippingMethodCategory> catalog,
) {
  final map = <String, List<ShippingRateOption>>{};
  for (final rate in rates) {
    final key = matchRateToCatalog(rate, catalog)?.method.shippingType ?? _otherCategoryKey;
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

String rateCategoryLabel(String key) => key == _otherCategoryKey ? 'Lainnya' : shippingCategoryLabel(key);

/// Why Instan (Gojek/Grab) is missing, when it is — Biteship only quotes
/// instant couriers for addresses that have a map pin.
String? instantShippingHint({
  required Map<String, List<ShippingRateOption>> grouped,
  required bool destinationHasCoordinates,
  required bool originHasCoordinates,
}) {
  if (grouped.containsKey('INSTANT_SHIPMENT')) return null;
  if (!destinationHasCoordinates) {
    return 'Pengiriman Instan (Gojek/Grab) butuh titik lokasi alamatmu. Ubah alamat lalu tekan "Gunakan Lokasi Saat Ini" untuk mengaktifkannya.';
  }
  if (!originHasCoordinates) {
    return 'Pengiriman Instan (Gojek/Grab) belum tersedia karena penjual belum menandai titik lokasi tokonya di peta. Kurir reguler & kargo tetap bisa dipilih.';
  }
  return null;
}

/// "Rp 12.500"
String rupiahLabel(int v) {
  final str = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    final posFromEnd = str.length - i;
    buf.write(str[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
  }
  return 'Rp $buf';
}

class CheckoutSectionTitle extends StatelessWidget {
  final String title;
  const CheckoutSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary));
  }
}

/// "Kirim" (courier, live Biteship rates) vs "Ambil di Toko" (pick up, free,
/// no address/rate step needed) — two equal-width segments.
class DeliveryModeToggle extends StatelessWidget {
  final bool isPickup;
  final ValueChanged<bool> onChanged;

  const DeliveryModeToggle({super.key, required this.isPickup, required this.onChanged});

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

class CheckoutAddressSection extends StatelessWidget {
  final UserAddress? address;
  final VoidCallback onChange;

  const CheckoutAddressSection({super.key, required this.address, required this.onChange});

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
class ShippingCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final String Function(String) labelOf;
  final ValueChanged<String> onSelect;

  const ShippingCategoryChips({
    super.key,
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

class ShippingRateList extends StatelessWidget {
  final List<ShippingRateOption> rates;
  final ShippingRateOption? selected;
  final ValueChanged<ShippingRateOption> onSelect;
  final String Function(int) rupiah;

  const ShippingRateList({super.key, required this.rates, required this.selected, required this.onSelect, required this.rupiah});

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
class PackageWeightNote extends StatelessWidget {
  final int grams;
  final String? source;

  const PackageWeightNote({super.key, required this.grams, this.source});

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

class CheckoutInfoNote extends StatelessWidget {
  final String text;

  const CheckoutInfoNote({super.key, required this.text});

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
