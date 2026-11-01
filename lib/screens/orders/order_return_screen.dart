import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/physical_order.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/order_return_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

/// "Ajukan Pengembalian": reason, what went wrong and photos of the item.
/// Pops true once the request is sent.
class OrderReturnScreen extends StatefulWidget {
  final PhysicalOrder order;

  const OrderReturnScreen({super.key, required this.order});

  @override
  State<OrderReturnScreen> createState() => _OrderReturnScreenState();
}

class _OrderReturnScreenState extends State<OrderReturnScreen> {
  final _description = TextEditingController();
  ReturnOptions? _options;
  String? _loadError;
  String? _reason;
  final List<ReturnPhoto> _photos = [];
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _loadOptions() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loadError = null);
    try {
      final options = await OrderReturnService.options(token: token);
      if (mounted) setState(() => _options = options);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Gagal memuat formulir pengembalian.');
    }
  }

  bool get _photoOptional => _reason != null && _reason == _options?.noPhotoReason;

  Future<void> _addPhotos() async {
    final max = _options?.maxPhotos ?? 5;
    final room = max - _photos.length;
    if (room <= 0) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = source == ImageSource.camera
        ? [?await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600, maxHeight: 1600)]
        : await picker.pickMultiImage(imageQuality: 85, maxWidth: 1600, maxHeight: 1600, limit: room > 1 ? room : null);
    final added = <ReturnPhoto>[];
    for (final file in picked.take(room)) {
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      added.add(ReturnPhoto(bytes: await file.readAsBytes(), fileName: name));
    }
    if (mounted && added.isNotEmpty) setState(() => _photos.addAll(added));
  }

  Future<void> _submit() async {
    final token = _token;
    if (token == null) return;
    final reason = _reason;
    final description = _description.text.trim();
    if (reason == null) return setState(() => _error = 'Pilih alasan pengembalian.');
    if (description.length < 10) return setState(() => _error = 'Jelaskan masalahnya minimal 10 karakter.');
    if (!_photoOptional && _photos.isEmpty) return setState(() => _error = 'Lampirkan minimal 1 foto barang.');

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await OrderReturnService.submit(
        token: token,
        orderId: widget.order.id,
        reason: reason,
        description: description,
        photos: _photos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal mengirim pengajuan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajukan Pengembalian')),
      body: options == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(onPressed: _loadOptions, child: const Text('Coba lagi')),
                      ],
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  widget.order.orderNumber ?? 'Pesanan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toko akan meninjau pengajuanmu. Jika disetujui, dana dikembalikan oleh tim Petope. '
                  'Pengembalian bisa diajukan sampai ${options.windowDays} hari setelah pesanan selesai.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Alasan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  child: Column(
                    children: [
                      for (final r in options.reasons)
                        RadioListTile<String>(
                          value: r,
                          title: Text(r, style: const TextStyle(fontSize: 13.5)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.purple,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Jelaskan masalahnya',
                    hintText: 'Contoh: bagian kepala patah saat paket dibuka',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _photoOptional ? 'Foto (opsional)' : 'Foto barang (wajib, maks. ${options.maxPhotos})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, p) in _photos.indexed)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(p.bytes, width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_photos.length < options.maxPhotos)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _sending ? null : _addPhotos,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.purple),
                              SizedBox(height: 4),
                              Text('Tambah', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFE0453A), fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 22),
                GradientButton(
                  label: _sending ? 'Mengirim...' : 'Kirim Pengajuan',
                  icon: Icons.assignment_return_outlined,
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
    );
  }
}
