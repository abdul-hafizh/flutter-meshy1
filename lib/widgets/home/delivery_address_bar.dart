import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_address.dart';
import '../../providers/active_address_controller.dart';
import '../../providers/auth_controller.dart';
import '../../screens/addresses/address_form_screen.dart';
import '../../screens/addresses/address_list_screen.dart';
import '../../theme/app_theme.dart';

String addressOneLine(UserAddress a) =>
    [a.address, a.city?.name, a.province?.name].where((p) => p != null && p.trim().isNotEmpty).join(', ');

/// "Dikirim ke …" on the home screen: the address used for nearby stores
/// and preselected at checkout. Tap to switch or add one.
class DeliveryAddressBar extends StatelessWidget {
  const DeliveryAddressBar({super.key});

  Future<void> _openPicker(BuildContext context) async {
    final ctrl = context.read<ActiveAddressController>();
    final token = context.read<AuthController>().token;
    if (ctrl.addresses.isEmpty) {
      final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddressFormScreen()));
      if (added == true) await ctrl.load(token);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddressPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ActiveAddressController>();
    final a = ctrl.address;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.orangeDeep, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: ctrl.loading && !ctrl.loaded
                    ? const Text('Memuat alamat…', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                    : a == null
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Belum ada alamat pengiriman',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              Text('Tambahkan alamat untuk melihat toko terdekat',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Dikirim ke ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Flexible(
                                    child: Text(
                                      a.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  if (a.isDefault) ...[
                                    const SizedBox(width: 6),
                                    const _Chip(text: 'Utama'),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [if (a.recipientName != null && a.recipientName!.isNotEmpty) a.recipientName!, addressOneLine(a)]
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
              ),
              const SizedBox(width: 6),
              Icon(a == null ? Icons.add_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.purple)),
      );
}

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ActiveAddressController>();
    final token = context.read<AuthController>().token;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Kirim ke alamat mana?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Toko terdekat dan alamat checkout mengikuti pilihan ini.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final a in ctrl.addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: a.id == ctrl.address?.id ? AppColors.purple.withValues(alpha: 0.07) : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            ctrl.select(a);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: a.id == ctrl.address?.id ? AppColors.purple : AppColors.border,
                                width: a.id == ctrl.address?.id ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  a.id == ctrl.address?.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: a.id == ctrl.address?.id ? AppColors.purple : AppColors.textFaint,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(a.label,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                          ),
                                          if (a.isDefault) ...[const SizedBox(width: 6), const _Chip(text: 'Utama')],
                                        ],
                                      ),
                                      if (a.recipientName != null)
                                        Text('${a.recipientName}${a.phone != null ? ' · ${a.phone}' : ''}',
                                            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                                      Text(addressOneLine(a), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (a.latitude == null || a.longitude == null)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text('Belum di-pin di peta',
                                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.orangeDeep)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final added = await nav.push<bool>(MaterialPageRoute(builder: (_) => const AddressFormScreen()));
                        if (added == true) await ctrl.load(token);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Alamat Baru'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressListScreen()));
                        await ctrl.load(token);
                      },
                      icon: const Icon(Icons.edit_location_alt_outlined),
                      label: const Text('Kelola'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
