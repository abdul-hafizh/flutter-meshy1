import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/gradient_button.dart';
import '../widgets/token_balance_badge.dart';
import 'buy_tokens_screen.dart';

enum _CreateMode { text, image }

const _kMaxReferenceImages = 4;

/// Must match the backend's GENERATION_COST in ai.controller.js.
const _kGenerationCost = 40;

class CreateScreen extends StatefulWidget {
  /// Called after a job is successfully queued, so the shell can jump the
  /// user to the Pesanan tab to watch progress.
  final VoidCallback? onCreated;

  const CreateScreen({super.key, this.onCreated});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _negativeController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  String _selectedCategory = 'Figurine';
  String _artStyle = 'realistic';
  _CreateMode _mode = _CreateMode.text;
  bool _hasText = false;
  bool _generating = false;

  final List<XFile> _pickedImages = [];
  final List<Uint8List> _pickedImageBytesList = [];

  static const _categories = ['Figurine', 'Accessories', 'Decoration', 'Gadget case'];
  static const _artStyles = {'realistic': 'Realistic', 'sculpture': 'Sculpture'};

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _negativeController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double? _parseDim(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  bool get _canGenerate =>
      _mode == _CreateMode.text ? _hasText : _pickedImages.isNotEmpty;

  Future<void> _pickImages() async {
    final remaining = _kMaxReferenceImages - _pickedImages.length;
    if (remaining <= 0) return;
    final files = await ImagePicker().pickMultiImage(imageQuality: 90, limit: remaining);
    if (files.isEmpty) return;
    final bytesList = await Future.wait(files.map((f) => f.readAsBytes()));
    if (!mounted) return;
    setState(() {
      _pickedImages.addAll(files);
      _pickedImageBytesList.addAll(bytesList);
    });
  }

  void _removeImageAt(int index) {
    setState(() {
      _pickedImages.removeAt(index);
      _pickedImageBytesList.removeAt(index);
    });
  }

  Future<void> _generate() async {
    if (!_canGenerate || _generating) return;

    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi berakhir, silakan masuk kembali.')),
      );
      return;
    }

    final credits = auth.user?.credits ?? 0;
    if (credits < _kGenerationCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Token tidak cukup. Butuh $_kGenerationCost token, kamu punya $credits.'),
          action: SnackBarAction(
            label: 'Beli Token',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BuyTokensScreen()),
            ),
          ),
        ),
      );
      return;
    }

    final targetLength = _parseDim(_lengthController.text);
    final targetWidth = _parseDim(_widthController.text);
    final targetHeight = _parseDim(_heightController.text);

    setState(() => _generating = true);
    try {
      if (_mode == _CreateMode.text) {
        await AiJobService.createTextTo3D(
          token: token,
          prompt: _controller.text.trim(),
          artStyle: _artStyle,
          negativePrompt: _negativeController.text,
          length: targetLength,
          width: targetWidth,
          height: targetHeight,
        );
      } else {
        await AiJobService.createImageTo3D(
          token: token,
          images: [
            for (var i = 0; i < _pickedImages.length; i++)
              ImageUpload(
                bytes: _pickedImageBytesList[i],
                filename: _pickedImages[i].name,
                mimeType: _pickedImages[i].mimeType,
              ),
          ],
          prompt: _controller.text.trim().isEmpty ? null : _controller.text.trim(),
          artStyle: _artStyle,
          negativePrompt: _negativeController.text,
          length: targetLength,
          width: targetWidth,
          height: targetHeight,
        );
      }
      if (!mounted) return;
      _controller.clear();
      _negativeController.clear();
      _lengthController.clear();
      _widthController.clear();
      _heightController.clear();
      setState(() {
        _pickedImages.clear();
        _pickedImageBytesList.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desain 3D sedang diproses AI ✨ Cek progresnya di menu Pesanan.')),
      );
      unawaited(auth.refreshUser());
      widget.onCreated?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan tak terduga. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImageMode = _mode == _CreateMode.image;
    final credits = context.watch<AuthController>().user?.credits ?? 0;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Buat Produk 3D',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TokenBalanceBadge(
                credits: credits,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BuyTokensScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Deskripsikan produk impianmu, AI yang wujudkan',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ModeTab(
                  label: 'Teks ke 3D',
                  selected: _mode == _CreateMode.text,
                  onTap: () => setState(() => _mode = _CreateMode.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeTab(
                  label: 'Gambar ke 3D',
                  selected: isImageMode,
                  onTap: () => setState(() => _mode = _CreateMode.image),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (isImageMode) ...[
            Text(
              'Foto Referensi (${_pickedImages.length}/$_kMaxReferenceImages)',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pakai beberapa foto dari sudut berbeda untuk hasil 3D yang lebih lengkap',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _ImagesPickerField(
              imageBytesList: _pickedImageBytesList,
              canAddMore: _pickedImages.length < _kMaxReferenceImages,
              onPick: _pickImages,
              onRemove: _removeImageAt,
            ),
            const SizedBox(height: 22),
          ],
          Text(
            isImageMode ? 'Deskripsi Tambahan (opsional)' : 'Deskripsi Produk',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 7,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: isImageMode
                    ? 'Contoh: half body dengan wajah jelas...'
                    : 'Contoh: Miniatur mobil Porsche 911 GT3 warna hitam metalik dengan detail interior...',
                hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textFaint, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Hal yang Dihindari (opsional)',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _negativeController,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: 'Contoh: buram, cacat, proporsi aneh...',
                hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textFaint, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Dimensi Hasil Cetak (cm, opsional)',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bantu merchant memperkirakan bahan & harga cetak',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DimensionField(label: 'Panjang', controller: _lengthController),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionField(label: 'Lebar', controller: _widthController),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionField(label: 'Tinggi', controller: _heightController),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Kategori',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _categories)
                SelectableCategoryChip(
                  label: c,
                  selected: _selectedCategory == c,
                  onTap: () => setState(() => _selectedCategory = c),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Gaya Model',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in _artStyles.entries)
                SelectableCategoryChip(
                  label: entry.value,
                  selected: _artStyle == entry.key,
                  onTap: () => setState(() => _artStyle = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: _generating ? 'Membuat desain...' : 'Buat dengan AI ✨',
            onPressed: _canGenerate && !_generating ? _generate : null,
          ),
        ],
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _DimensionField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
              hintText: '0',
              suffixText: 'cm',
              suffixStyle: TextStyle(fontSize: 12, color: AppColors.textFaint),
              hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textFaint),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandGradient : null,
            color: selected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.transparent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagesPickerField extends StatelessWidget {
  final List<Uint8List> imageBytesList;
  final bool canAddMore;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  const _ImagesPickerField({
    required this.imageBytesList,
    required this.canAddMore,
    required this.onPick,
    required this.onRemove,
  });

  static const _tileSize = 86.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < imageBytesList.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: _tileSize,
              height: _tileSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(imageBytesList[i], fit: BoxFit.cover),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove(i),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (canAddMore)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPick,
              child: Container(
                width: _tileSize,
                height: _tileSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppColors.textFaint),
              ),
            ),
          ),
      ],
    );
  }
}
