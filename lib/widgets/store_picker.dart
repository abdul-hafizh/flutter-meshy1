import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nearby_merchant.dart';
import '../providers/active_address_controller.dart';
import '../providers/auth_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/merchant_service.dart';
import '../theme/app_theme.dart';
import 'store_status.dart';

enum _StoreSort { nearest, rating, sold }

/// Full-screen store chooser (the prompt screen, and "Produk Siap Print" on
/// the home screen) — city, distance, rating and total grams sold per store,
/// like an online marketplace. Pops the chosen [NearbyMerchant].
class StorePickerScreen extends StatefulWidget {
  final String? selectedId;
  final String title;

  /// Shown above the list — what picking a store leads to.
  final String? subtitle;

  const StorePickerScreen({super.key, this.selectedId, this.title = 'Pilih Toko', this.subtitle});

  @override
  State<StorePickerScreen> createState() => _StorePickerScreenState();
}

class _StorePickerScreenState extends State<StorePickerScreen> {
  final TextEditingController _search = TextEditingController();
  List<NearbyMerchant> _stores = [];
  bool _loading = true;
  String? _error;
  _StoreSort _sort = _StoreSort.nearest;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stores = await MerchantService.listNearbyForMe(
        token: token,
        address: context.read<ActiveAddressController>().address,
      );
      if (!mounted) return;
      setState(() => _stores = stores);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat daftar toko.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NearbyMerchant> get _visible {
    final q = _search.text.trim().toLowerCase();
    final list = _stores
        .where((s) => q.isEmpty || s.fullName.toLowerCase().contains(q) || s.locationLine.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case _StoreSort.rating:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case _StoreSort.sold:
        list.sort((a, b) => b.soldGrams.compareTo(a.soldGrams));
      case _StoreSort.nearest:
        list.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stores = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(widget.subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama toko atau kota',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final entry in const {
                  _StoreSort.nearest: 'Terdekat',
                  _StoreSort.rating: 'Rating Tertinggi',
                  _StoreSort.sold: 'Terlaris',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _sort == entry.key,
                      onSelected: (_) => setState(() => _sort = entry.key),
                      selectedColor: AppColors.purple.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _sort == entry.key ? AppColors.purple : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _Message(text: _error!, onRetry: _load)
                    : stores.isEmpty
                        ? const _Message(text: 'Toko tidak ditemukan.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: stores.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => StoreSummaryTile(
                                store: stores[i],
                                selected: stores[i].id == widget.selectedId,
                                onTap: () => Navigator.of(context).pop(stores[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ],
        ),
      ),
    );
  }
}

/// One store: avatar, name (+ "Tutup"), city, rating, grams sold, distance.
class StoreSummaryTile extends StatelessWidget {
  final NearbyMerchant store;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const StoreSummaryTile({super.key, required this.store, this.selected = false, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.purple : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceMuted,
                backgroundImage: store.avatar != null && store.avatar!.isNotEmpty ? NetworkImage(store.avatar!) : null,
                child: store.avatar == null || store.avatar!.isEmpty
                    ? const Icon(Icons.storefront_rounded, size: 20, color: AppColors.purple)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.fullName.isNotEmpty ? store.fullName : 'Toko',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        if (store.operatingStatus?.isClosed == true) ...[
                          const SizedBox(width: 6),
                          StoreStatusBadge(status: store.operatingStatus),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 13, color: AppColors.textFaint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            store.cityName ?? store.locationLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        if (store.distanceLabel.isNotEmpty)
                          Text(
                            ' · ~${store.distanceLabel}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                            const SizedBox(width: 2),
                            Text(
                              store.hasRating ? '${store.rating} (${store.totalReviews})' : 'Belum ada rating',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.scale_outlined, size: 13, color: AppColors.purple),
                            const SizedBox(width: 3),
                            Text(
                              store.soldLabel,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.purple),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                    color: AppColors.purple,
                    size: selected ? 22 : 24,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
