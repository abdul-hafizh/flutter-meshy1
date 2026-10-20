import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nearby_merchant.dart';
import '../../models/user_address.dart';
import '../../providers/active_address_controller.dart';
import '../../providers/auth_controller.dart';
import '../../providers/chat_controller.dart';
import '../../screens/addresses/address_form_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/chat_service.dart';
import '../../services/merchant_service.dart';
import '../../theme/app_theme.dart';
import '../store_picker.dart';
import '../store_status.dart';

/// "Toko Terdekat" on the home screen — stores within the admin's radius of
/// the active delivery address. Reloads whenever that address changes.
class NearbyStoresSection extends StatefulWidget {
  const NearbyStoresSection({super.key});

  @override
  State<NearbyStoresSection> createState() => _NearbyStoresSectionState();
}

class _NearbyStoresSectionState extends State<NearbyStoresSection> {
  String? _loadedFor;
  bool _loading = false;
  String? _error;
  List<NearbyMerchant> _stores = const [];
  double? _radiusKm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final address = context.watch<ActiveAddressController>().address;
    final key = address == null ? null : '${address.id}:${address.latitude}:${address.longitude}';
    if (address != null && key != _loadedFor) {
      _loadedFor = key;
      _load(address);
    }
  }

  Future<void> _load(UserAddress address) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await MerchantService.listNearbyResult(
        token: token,
        latitude: address.latitude,
        longitude: address.longitude,
        cityId: address.cityId,
        nearbyOnly: true,
      );
      if (!mounted || _loadedFor == null) return;
      setState(() {
        _stores = result.stores;
        _radiusKm = result.radiusKm;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat toko terdekat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ActiveAddressController>();
    final address = ctrl.address;
    if (address == null) return const SizedBox.shrink();
    final pinned = address.latitude != null && address.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Toko Terdekat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            if (_radiusKm != null && pinned)
              Text('radius ${_radiusKm!.round()} km', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          pinned ? 'Dari alamat ${address.label}' : 'Alamat ${address.label} belum di-pin — sementara ditampilkan toko di kota yang sama.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (!pinned)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => AddressFormScreen(existing: address)),
              );
              if (saved == true && context.mounted) await ctrl.load(context.read<AuthController>().token);
            },
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Pin alamat di peta'),
          ),
        const SizedBox(height: 10),
        if (_loading && _stores.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Row(
            children: [
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              TextButton(onPressed: () => _load(address), child: const Text('Coba lagi')),
            ],
          )
        else if (_stores.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.storefront_outlined, color: AppColors.textFaint, size: 30),
                SizedBox(height: 6),
                Text('Tidak ada toko terdekat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text(
                  'Belum ada toko di sekitar alamat ini. Coba pilih alamat lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final store in _stores.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StoreSummaryTile(store: store, onTap: () => _showStore(context, store)),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _showStore(BuildContext context, NearbyMerchant store) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StoreSheet(store: store),
    );
  }
}

class _StoreSheet extends StatefulWidget {
  final NearbyMerchant store;

  const _StoreSheet({required this.store});

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  bool _opening = false;

  Future<void> _chat() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _opening = true);
    try {
      final client = await context.read<ChatController>().ensureConnected(token);
      final info = await ChatService.createOrGetChannel(token: token, merchantId: widget.store.id);
      final channel = client.channel(info.channelType, id: info.channelId);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      await nav.push(MaterialPageRoute(builder: (_) => ChatScreen(client: client, channel: channel)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka chat.')));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreSummaryTile(store: s, trailing: const SizedBox.shrink()),
            const SizedBox(height: 10),
            if (s.address != null && s.address!.isNotEmpty)
              Text(s.address!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            StoreStatusLine(status: s.operatingStatus),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _opening ? null : _chat,
                icon: _opening
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat Toko'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
