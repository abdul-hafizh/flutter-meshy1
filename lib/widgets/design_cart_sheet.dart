import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import 'checkout/shipping_widgets.dart' show rupiahLabel;
import 'gradient_button.dart';

/// Bottom sheet to put a finished AI design into the cart: pick one of the
/// store's materials (price follows the design's weight × that material)
/// and a quantity. Resolves to true when the cart was updated.
Future<bool> showDesignCartSheet(BuildContext context, {required String aiModelId}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _DesignCartSheet(aiModelId: aiModelId),
  );
  return added == true;
}

class _DesignCartSheet extends StatefulWidget {
  final String aiModelId;

  const _DesignCartSheet({required this.aiModelId});

  @override
  State<_DesignCartSheet> createState() => _DesignCartSheetState();
}

class _DesignCartSheetState extends State<_DesignCartSheet> {
  DesignCartOptions? _options;
  String? _error;
  int? _materialId;
  int _quantity = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final options = await CartService.designOptions(token: token, aiModelId: widget.aiModelId);
      if (!mounted) return;
      setState(() {
        _options = options;
        final inCart = options.cartMaterialId;
        _materialId = options.materials.any((m) => m.id == inCart)
            ? inCart
            : (options.materials.isNotEmpty ? options.materials.first.id : null);
        _quantity = options.cartQuantity ?? 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat pilihan material.');
    }
  }

  DesignMaterialOption? get _material {
    final options = _options;
    if (options == null) return null;
    for (final m in options.materials) {
      if (m.id == _materialId) return m;
    }
    return null;
  }

  Future<void> _save() async {
    final token = context.read<AuthController>().token;
    final material = _material;
    if (token == null || material == null) return;
    setState(() => _saving = true);
    try {
      final result = await CartService.addDesign(
        token: token,
        aiModelId: widget.aiModelId,
        materialId: material.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      context.read<CartController>().setCount(result.count);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final material = _material;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.orangeDeep, size: 32),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Tutup')),
                ],
              )
            : options == null
                ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        options.cartLineId != null ? 'Ubah di Keranjang' : 'Masukkan ke Keranjang',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${options.name}\nDicetak oleh ${options.storeName} · estimasi ± ${options.weightGrams.round()} g',
                        style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pilih Material',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (options.materials.isEmpty)
                        const Text(
                          'Toko ini belum punya material aktif. Hubungi toko lewat chat.',
                          style: TextStyle(fontSize: 13, color: AppColors.orangeDeep),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final m in options.materials)
                                  _MaterialTile(
                                    option: m,
                                    selected: m.id == _materialId,
                                    onTap: () => setState(() => _materialId = m.id),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'Jumlah',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            color: AppColors.purple,
                          ),
                          Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          IconButton(
                            onPressed: _quantity < 99 ? () => setState(() => _quantity++) : null,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: AppColors.purple,
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.border),
                      Row(
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          const Spacer(),
                          Text(
                            rupiahLabel((material?.unitPrice ?? 0) * _quantity),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.orangeDeep),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Belum termasuk ongkir, biaya layanan, dan pajak (dihitung saat checkout).',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        label: _saving
                            ? 'Menyimpan...'
                            : (options.cartLineId != null ? 'Simpan Perubahan' : 'Masukkan ke Keranjang'),
                        icon: Icons.add_shopping_cart_rounded,
                        onPressed: material != null && !_saving ? _save : null,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final DesignMaterialOption option;
  final bool selected;
  final VoidCallback onTap;

  const _MaterialTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.purple.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.purple : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.purple : AppColors.textFaint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  rupiahLabel(option.unitPrice),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.orangeDeep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
