import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/gradient_button.dart';

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
  String _selectedCategory = 'Figurine';
  String _artStyle = 'realistic';
  bool _hasText = false;
  bool _generating = false;

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
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_hasText || _generating) return;

    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi berakhir, silakan masuk kembali.')),
      );
      return;
    }

    final prompt = _controller.text.trim();
    setState(() => _generating = true);
    try {
      await AiJobService.createTextTo3D(
        token: token,
        prompt: prompt,
        artStyle: _artStyle,
        negativePrompt: _negativeController.text,
      );
      if (!mounted) return;
      _controller.clear();
      _negativeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desain 3D sedang diproses AI ✨ Cek progresnya di menu Pesanan.')),
      );
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
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'Buat Produk 3D',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Deskripsikan produk impianmu, AI yang wujudkan',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),
          const Text(
            'Deskripsi Produk',
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
              controller: _controller,
              minLines: 5,
              maxLines: 7,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: 'Contoh: Miniatur mobil Porsche 911 GT3 warna hitam metalik dengan detail interior...',
                hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textFaint, height: 1.4),
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
            onPressed: _hasText && !_generating ? _generate : null,
          ),
        ],
      ),
    );
  }
}
