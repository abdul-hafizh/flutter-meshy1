import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/gradient_button.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedCategory = 'Figurine';
  bool _hasText = false;
  bool _generating = false;

  static const _categories = ['Figurine', 'Accessories', 'Decoration', 'Gadget case'];

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
    super.dispose();
  }

  void _generate() {
    if (!_hasText || _generating) return;
    setState(() => _generating = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desain 3D sedang diproses AI ✨')),
      );
    });
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
