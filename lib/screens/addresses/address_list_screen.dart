import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_address.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/user_address_service.dart';
import '../../theme/app_theme.dart';
import 'address_form_screen.dart';

/// Lists the logged-in user's saved addresses. When [selectMode] is true
/// (opened from checkout), tapping a row returns it via `Navigator.pop`
/// instead of opening the edit form.
class AddressListScreen extends StatefulWidget {
  final bool selectMode;

  const AddressListScreen({super.key, this.selectMode = false});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  bool _loading = true;
  List<UserAddress> _addresses = [];
  String? _error;
  final Set<String> _busyIds = {};

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
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await UserAddressService.listMine(token: token);
      if (!mounted) return;
      setState(() => _addresses = addresses);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat alamat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({UserAddress? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressFormScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _setDefault(UserAddress address) async {
    final token = _token;
    if (token == null || address.isDefault) return;
    setState(() => _busyIds.add(address.id));
    try {
      await UserAddressService.setDefault(token: token, id: address.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menjadikan alamat utama. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(address.id));
    }
  }

  Future<void> _delete(UserAddress address) async {
    final token = _token;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus alamat?'),
        content: Text('Alamat "${address.label}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFE0453A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(address.id));
    try {
      await UserAddressService.delete(token: token, id: address.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus alamat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(address.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Pilih Alamat' : 'Alamat Saya'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Alamat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 60),
                        Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textFaint),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        Center(child: OutlinedButton(onPressed: _load, child: const Text('Coba lagi'))),
                      ],
                    )
                  : _addresses.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 60),
                            Icon(Icons.location_off_outlined, size: 44, color: AppColors.textFaint),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'Belum ada alamat tersimpan',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text(
                                'Tambahkan alamat pengiriman kamu',
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                          itemCount: _addresses.length,
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AddressCard(
                                address: address,
                                busy: _busyIds.contains(address.id),
                                selectMode: widget.selectMode,
                                onTap: widget.selectMode
                                    ? () => Navigator.of(context).pop(address)
                                    : () => _openForm(existing: address),
                                onSetDefault: () => _setDefault(address),
                                onDelete: () => _delete(address),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final bool busy;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.busy,
    required this.selectMode,
    required this.onTap,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: address.isDefault ? AppColors.purple : AppColors.border, width: address.isDefault ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 18, color: AppColors.purple),
                  const SizedBox(width: 6),
                  Text(
                    address.label,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'UTAMA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.purple),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (busy)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (!selectMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                      onSelected: (value) {
                        if (value == 'default') onSetDefault();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        if (!address.isDefault)
                          const PopupMenuItem(value: 'default', child: Text('Jadikan alamat utama')),
                        const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (address.recipientName != null && address.recipientName!.isNotEmpty)
                Text(
                  address.recipientName!,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              if (address.phone != null && address.phone!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(address.phone!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ),
              if (address.summaryLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    address.summaryLine,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
