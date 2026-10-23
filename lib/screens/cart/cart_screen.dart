import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart.dart';
import '../../providers/auth_controller.dart';
import '../../providers/cart_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/cart_service.dart';
import '../../services/location_gate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/store_status.dart';
import '../../widgets/checkout/shipping_widgets.dart' show rupiahLabel;
import '../../widgets/gradient_button.dart';
import 'cart_checkout_screen.dart';

/// "Keranjang": ready-made marketplace products only (never AI designs),
/// grouped per store. The customer ticks what to buy now — items of several
/// stores can be checked out together (CartCheckoutScreen).
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = true;
  String? _error;
  List<CartGroup> _groups = [];
  final Set<String> _selected = {};
  final Set<String> _busy = {};
  bool _initialized = false;

  String? get _token => context.read<AuthController>().token;

  List<CartLine> get _allLines => [for (final g in _groups) ...g.items];
  List<CartLine> get _availableLines => _allLines.where((l) => l.available).toList();
  List<CartLine> get _selectedLines => _availableLines.where((l) => _selected.contains(l.id)).toList();
  int get _selectedTotal => _selectedLines.fold(0, (sum, l) => sum + l.lineTotal);
  int get _selectedQuantity => _selectedLines.fold(0, (sum, l) => sum + l.quantity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = _groups.isEmpty;
      _error = null;
    });
    try {
      final groups = await CartService.getCart(token: token);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        final ids = _allLines.where((l) => l.available).map((l) => l.id).toSet();
        // First load: everything buyable is ticked, like most shops.
        if (!_initialized) {
          _selected
            ..clear()
            ..addAll(ids);
          _initialized = true;
        } else {
          _selected.removeWhere((id) => !ids.contains(id));
        }
      });
      context.read<CartController>().setCount(_allLines.length);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat keranjang.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeQuantity(CartLine line, int quantity) async {
    final token = _token;
    if (token == null || quantity < 1) return;
    setState(() => _busy.add(line.id));
    try {
      await CartService.updateQuantity(token: token, itemId: line.id, quantity: quantity);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(line.id));
    }
  }

  Future<void> _editNotes(CartLine line) async {
    final token = _token;
    if (token == null) return;
    final controller = TextEditingController(text: line.notes ?? '');
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deskripsi untuk toko'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Contoh: warna merah, tinggi 10 cm, finishing halus'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();
    if (notes == null || notes == (line.notes ?? '')) return;
    setState(() => _busy.add(line.id));
    try {
      await CartService.updateNotes(token: token, itemId: line.id, notes: notes);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(line.id));
    }
  }

  Future<void> _remove(CartLine line) async {
    final token = _token;
    if (token == null) return;
    setState(() => _busy.add(line.id));
    try {
      await CartService.remove(token: token, itemId: line.id);
      _selected.remove(line.id);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(line.id));
    }
  }

  Future<void> _removeSelected() async {
    final lines = _selectedLines;
    if (lines.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('${lines.length} produk akan dihapus dari keranjang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final token = _token;
    if (token == null) return;
    for (final line in lines) {
      try {
        await CartService.remove(token: token, itemId: line.id);
      } catch (_) {
        // Best-effort per line; the reload below shows what's left.
      }
    }
    _selected.clear();
    await _load();
  }

  void _toggleGroup(CartGroup group, bool select) {
    setState(() {
      for (final line in group.items.where((l) => l.available)) {
        select ? _selected.add(line.id) : _selected.remove(line.id);
      }
    });
  }

  void _toggleAll(bool select) {
    setState(() {
      _selected.clear();
      if (select) _selected.addAll(_availableLines.map((l) => l.id));
    });
  }

  Future<void> _checkout() async {
    final ids = _selectedLines.map((l) => l.id).toList();
    if (ids.isEmpty) return;
    if (!await LocationGate.ensureEnabled(context) || !mounted) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CartCheckoutScreen(cartItemIds: ids)),
    );
    if (!mounted) return;
    await _load();
    if (done == true && mounted) Navigator.of(context).pop();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _availableLines.isNotEmpty && _selectedLines.length == _availableLines.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_allLines.isEmpty ? 'Keranjang' : 'Keranjang (${_allLines.length})'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_selectedLines.isNotEmpty)
            TextButton(onPressed: _removeSelected, child: const Text('Hapus')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _CenteredMessage(
                  icon: Icons.error_outline_rounded,
                  title: _error!,
                  actionLabel: 'Coba lagi',
                  onAction: _load,
                )
              : _groups.isEmpty
                  ? const _CenteredMessage(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Keranjang masih kosong',
                      subtitle: 'Tambahkan produk dari menu Market untuk dibeli sekaligus.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          for (final group in _groups) ...[
                            _StoreCard(
                              group: group,
                              selected: _selected,
                              busy: _busy,
                              onToggleGroup: (v) => _toggleGroup(group, v),
                              onToggleLine: (line, v) => setState(() => v ? _selected.add(line.id) : _selected.remove(line.id)),
                              onQuantity: _changeQuantity,
                              onNotes: _editNotes,
                              onRemove: _remove,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
      bottomNavigationBar: _groups.isEmpty || _loading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      activeColor: AppColors.purple,
                      onChanged: _availableLines.isEmpty ? null : (v) => _toggleAll(v ?? false),
                    ),
                    const Text('Semua', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const Spacer(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total harga barang (belum termasuk PPN & ongkir)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        Text(
                          rupiahLabel(_selectedTotal),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: GradientButton(
                        label: 'Checkout ($_selectedQuantity)',
                        onPressed: _selectedLines.isEmpty ? null : _checkout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final CartGroup group;
  final Set<String> selected;
  final Set<String> busy;
  final ValueChanged<bool> onToggleGroup;
  final void Function(CartLine line, bool value) onToggleLine;
  final void Function(CartLine line, int quantity) onQuantity;
  final void Function(CartLine line) onNotes;
  final ValueChanged<CartLine> onRemove;

  const _StoreCard({
    required this.group,
    required this.selected,
    required this.busy,
    required this.onToggleGroup,
    required this.onToggleLine,
    required this.onQuantity,
    required this.onNotes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final available = group.items.where((l) => l.available).toList();
    final allSelected = available.isNotEmpty && available.every((l) => selected.contains(l.id));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  activeColor: AppColors.purple,
                  onChanged: available.isEmpty ? null : (v) => onToggleGroup(v ?? false),
                ),
                const Icon(Icons.storefront_rounded, size: 18, color: AppColors.purple),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    group.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 6),
                StoreStatusBadge(status: group.operatingStatus),
                const Spacer(),
              ],
            ),
          ),
          // Store rating and city.
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 0, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: group.rating != null ? const Color(0xFFF5A623) : AppColors.textFaint,
                ),
                const SizedBox(width: 2),
                Text(
                  group.rating != null
                      ? '${group.rating!.toStringAsFixed(1).replaceAll('.0', '')} (${group.totalReviews})'
                      : 'Belum ada rating',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (group.cityName != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.textFaint),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      group.cityName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final line in group.items)
            _CartLineTile(
              line: line,
              selected: selected.contains(line.id),
              busy: busy.contains(line.id),
              onToggle: (v) => onToggleLine(line, v),
              onQuantity: (q) => onQuantity(line, q),
              onNotes: () => onNotes(line),
              onRemove: () => onRemove(line),
            ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQuantity;
  final VoidCallback onNotes;
  final VoidCallback onRemove;

  const _CartLineTile({
    required this.line,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onQuantity,
    required this.onNotes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final image = line.imageUrl;
    final design = line.design;
    return Opacity(
      opacity: line.available ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: line.available && selected,
              activeColor: AppColors.purple,
              onChanged: line.available ? (v) => onToggle(v ?? false) : null,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: image != null && image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ThumbFallback(),
                      )
                    : const _ThumbFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  if (design != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (design.materialName != null) 'Material ${design.materialName}',
                        if (design.weightGrams != null) '± ${design.weightGrams!.round()} g',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: busy ? null : onNotes,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.purple),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                line.notes ?? 'Tambah deskripsi untuk toko',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: line.notes == null ? FontStyle.normal : FontStyle.italic,
                                  fontWeight: line.notes == null ? FontWeight.w600 : FontWeight.w400,
                                  color: line.notes == null ? AppColors.purple : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    rupiahLabel(line.unitPrice),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.orangeDeep),
                  ),
                  if (line.issue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      line.issue!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE0453A)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: busy ? null : onRemove,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Hapus',
                      ),
                      const Spacer(),
                      if (line.product != null || design != null)
                        _Stepper(
                          quantity: line.quantity,
                          max: line.maxQuantity,
                          busy: busy,
                          onChanged: onQuantity,
                        ),
                    ],
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

class _Stepper extends StatelessWidget {
  final int quantity;
  final int max;
  final bool busy;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.quantity, required this.max, required this.busy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: busy || quantity <= 1 ? null : () => onChanged(quantity - 1),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_rounded, size: 16)),
          ),
          SizedBox(
            width: 30,
            child: busy
                ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)))
                : Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
          ),
          InkWell(
            onTap: busy || quantity >= max ? null : () => onChanged(quantity + 1),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 16)),
          ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradientSoft),
      child: const Icon(Icons.inventory_2_rounded, color: AppColors.purple, size: 24),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
