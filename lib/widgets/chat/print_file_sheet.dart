import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/print_file_service.dart';
import '../../theme/app_theme.dart';
import '../gradient_button.dart';

/// "Kirim File Cetak": the customer picks a ready-to-print file (STL, OBJ,
/// 3MF, STEP), a material and quantity, and sends it to the store in this
/// chat. The file goes to Petope's server (not the chat provider); the
/// store creates the order for it in its dashboard.
Future<void> showPrintFileSheet(BuildContext context, {required String merchantId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PrintFileSheet(merchantId: merchantId),
  );
}

class _PrintFileSheet extends StatefulWidget {
  final String merchantId;

  const _PrintFileSheet({required this.merchantId});

  @override
  State<_PrintFileSheet> createState() => _PrintFileSheetState();
}

class _PrintFileSheetState extends State<_PrintFileSheet> {
  final TextEditingController _notes = TextEditingController();
  List<String> _materials = [];
  String? _material;
  int _quantity = 1;
  String? _fileName;
  Uint8List? _bytes;
  bool _picking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final materials = await PrintFileService.materials(token: token);
      if (mounted) setState(() => _materials = materials);
    } catch (_) {
      // Material stays optional — the store can confirm it in the chat.
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      // FileType.any: Android doesn't know MIME types for .stl/.3mf, so a
      // custom filter would grey those files out — the extension is checked here.
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final ext = (file.extension ?? '').toLowerCase();
      if (!PrintFileService.allowedExtensions.contains(ext)) {
        _toast('Pilih file STL, OBJ, 3MF, atau STEP.');
        return;
      }
      final size = await file.length() ?? 0;
      if (size > PrintFileService.maxBytes) {
        _toast('Ukuran file maksimal 50 MB.');
        return;
      }
      final bytes = await file.xFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _bytes = bytes;
      });
    } catch (_) {
      _toast('Gagal membuka file.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    final token = context.read<AuthController>().token;
    final bytes = _bytes;
    final name = _fileName;
    if (token == null || bytes == null || name == null) return;
    setState(() => _sending = true);
    try {
      final message = await PrintFileService.send(
        token: token,
        merchantId: widget.merchantId,
        bytes: bytes,
        fileName: name,
        materialName: _material,
        quantity: _quantity,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(message);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kirim File Siap Print',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'File STL, OBJ, 3MF, atau STEP (maks. 50 MB). Toko akan menghitung berat & membuatkan pesanannya, '
              'lalu pesanan muncul di menu Pesanan untuk kamu bayar.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _picking || _sending ? null : _pickFile,
              icon: _picking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_fileName == null ? Icons.upload_file_rounded : Icons.check_circle_rounded),
              label: Text(
                _fileName == null ? 'Pilih File' : '$_fileName (${PrintFileService.sizeLabel(_bytes!.length)})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.purple,
                side: const BorderSide(color: AppColors.purple),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Bahan', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _materials)
                  ChoiceChip(
                    label: Text(m),
                    selected: _material == m,
                    onSelected: (v) => setState(() => _material = v ? m : null),
                    selectedColor: AppColors.purple.withValues(alpha: 0.15),
                  ),
                if (_materials.isEmpty)
                  const Text('Bahan bisa didiskusikan dengan toko.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Jumlah', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: AppColors.purple,
                ),
                Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: _quantity < 999 ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: AppColors.purple,
                ),
              ],
            ),
            TextField(
              controller: _notes,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Catatan (warna, infill, ukuran, dll) — opsional',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: _sending ? 'Mengirim...' : 'Kirim ke Toko',
              icon: Icons.send_rounded,
              onPressed: _bytes != null && !_sending ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders `PRINT_FILE` attachments (a file sent via [showPrintFileSheet]).
/// The file itself stays on Petope's server; the card shows what was sent.
class PrintFileAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  const PrintFileAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['PRINT_FILE'];
    return items != null && items.isNotEmpty;
  }

  @override
  Widget? build(BuildContext context, Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['PRINT_FILE']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final a in items) _PrintFileCard(attachment: a)],
    );
  }
}

class _PrintFileCard extends StatelessWidget {
  final Attachment attachment;

  const _PrintFileCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final data = attachment.extraData;
    final name = data['fileName']?.toString() ?? 'File cetak';
    final size = data['fileSize'] is num ? PrintFileService.sizeLabel((data['fileSize'] as num).toInt()) : null;
    final material = data['materialName']?.toString();
    final qty = data['quantity']?.toString() ?? '1';
    final notes = data['notes']?.toString();
    return Container(
      width: 260,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.view_in_ar_rounded, color: AppColors.purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FILE SIAP PRINT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.purple, letterSpacing: 0.4),
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  [?size, material != null ? 'Bahan $material' : 'Bahan belum dipilih', '$qty pcs'].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                if (notes != null && notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '“$notes”',
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
