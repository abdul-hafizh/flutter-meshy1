import 'package:flutter/material.dart';

import '../../models/nearby_merchant.dart';
import '../../screens/chat/open_store_chat.dart';
import '../../theme/app_theme.dart';
import '../store_picker.dart';

/// The three ways to order on the home screen: Produk Jadi (the market),
/// Produk via Prompt (the AI prompt screen) and Produk Siap Print (pick a
/// store, then chat with it to send the file).
class StartOptions extends StatelessWidget {
  final VoidCallback onReadyMade;
  final VoidCallback onPrompt;

  const StartOptions({super.key, required this.onReadyMade, required this.onPrompt});

  Future<void> _readyToPrint(BuildContext context) async {
    final store = await Navigator.of(context).push<NearbyMerchant>(
      MaterialPageRoute(
        builder: (_) => const StorePickerScreen(
          title: 'Pilih Toko Cetak',
          subtitle: 'Pilih toko yang akan mencetak file 3D kamu. Setelah memilih, kamu langsung masuk ke chat toko untuk mengirim file.',
        ),
      ),
    );
    if (store == null || !context.mounted) return;
    await openStoreChat(context, store.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mau pesan apa hari ini?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          title: 'Produk Jadi',
          description: 'Pilih hasil cetak 3D yang sudah jadi dari toko-toko di marketplace — tinggal checkout dan dikirim.',
          icon: Icons.storefront_rounded,
          colors: const [Color(0xFFFFA62B), AppColors.orangeDeep],
          onTap: onReadyMade,
        ),
        const SizedBox(height: 12),
        _OptionCard(
          title: 'Produk via Prompt',
          description: 'Ketik ide atau unggah foto — AI mewujudkannya jadi model 3D, lalu dicetak oleh toko pilihanmu.',
          icon: Icons.auto_awesome_rounded,
          colors: const [AppColors.purple, AppColors.purpleDeep],
          onTap: onPrompt,
        ),
        const SizedBox(height: 12),
        _OptionCard(
          title: 'Produk Siap Print',
          description: 'Sudah punya file 3D (STL, 3MF, OBJ)? Pilih toko terdekat dan kirim filenya lewat chat untuk dicetak.',
          icon: Icons.view_in_ar_rounded,
          colors: const [Color(0xFF14B8A6), Color(0xFF2563EB)],
          onTap: () => _readyToPrint(context),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _OptionCard({required this.title, required this.description, required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.shadowFor(colors.last), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Stack(
            children: [
              // Soft decorative circle in the corner.
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_forward_rounded, color: colors.last, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
