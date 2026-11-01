import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nearby_merchant.dart';
import '../../providers/auth_controller.dart';
import '../../screens/chat/open_store_chat.dart';
import '../../services/api_config.dart';
import '../../services/home_card_service.dart';
import '../../theme/app_theme.dart';
import '../store_picker.dart';

/// Preset icon keys an admin can pick in Master Kategori Produk (same list
/// as api-meshy utils/homeCards.js HOME_ICONS).
const _kHomeIcons = <String, IconData>{
  'storefront': Icons.storefront_rounded,
  'auto_awesome': Icons.auto_awesome_rounded,
  'view_in_ar': Icons.view_in_ar_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'print': Icons.print_rounded,
  'category': Icons.category_rounded,
  'brush': Icons.brush_rounded,
  'palette': Icons.palette_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'rocket_launch': Icons.rocket_launch_rounded,
  'star': Icons.star_rounded,
  'favorite': Icons.favorite_rounded,
  'toys': Icons.toys_rounded,
  'cake': Icons.cake_rounded,
  'chair': Icons.chair_rounded,
  'extension': Icons.extension_rounded,
  'build': Icons.build_rounded,
  'diamond': Icons.diamond_rounded,
  'pets': Icons.pets_rounded,
  'local_offer': Icons.local_offer_rounded,
  'photo_camera': Icons.photo_camera_rounded,
  'upload_file': Icons.upload_file_rounded,
};

/// Built in — shown until the admin's cards load, or if they can't.
const _kDefaultCards = [
  HomeCard(
    action: 'MARKET',
    title: 'Produk Jadi',
    description: 'Pilih hasil cetak 3D yang sudah jadi dari toko-toko di marketplace — tinggal checkout dan dikirim.',
    icon: 'storefront',
    colorStart: '#FFA62B',
    colorEnd: '#FF4E00',
  ),
  HomeCard(
    action: 'PROMPT',
    title: 'Produk via Prompt',
    description: 'Ketik ide atau unggah foto — AI mewujudkannya jadi model 3D, lalu dicetak oleh toko pilihanmu.',
    icon: 'auto_awesome',
    colorStart: '#9B2FCE',
    colorEnd: '#6423A6',
  ),
  HomeCard(
    action: 'PRINT_FILE',
    title: 'Produk Siap Print',
    description: 'Sudah punya file 3D (STL, 3MF, OBJ)? Pilih toko terdekat dan kirim filenya lewat chat untuk dicetak.',
    icon: 'view_in_ar',
    colorStart: '#14B8A6',
    colorEnd: '#2563EB',
  ),
];

Color? _hex(String? value) {
  final v = value?.replaceFirst('#', '');
  if (v == null || v.length != 6) return null;
  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

/// The ways to order on the home screen, from Master Kategori Produk: Produk
/// Jadi (the market), Produk via Prompt (the AI prompt screen) and Produk
/// Siap Print (pick a store, then chat with it to send the file) — the admin
/// sets each card's title, description, icon, colours and order.
class StartOptions extends StatefulWidget {
  final VoidCallback onReadyMade;
  final VoidCallback onPrompt;

  const StartOptions({super.key, required this.onReadyMade, required this.onPrompt});

  @override
  State<StartOptions> createState() => StartOptionsState();
}

class StartOptionsState extends State<StartOptions> {
  List<HomeCard> _cards = _kDefaultCards;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Refetches the admin's cards (the home screen calls this when it reloads).
  Future<void> reload() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final cards = (await HomeCardService.list(token: token)).where((c) => _onTapFor(c) != null).toList();
      if (mounted && cards.isNotEmpty) setState(() => _cards = cards);
    } catch (_) {
      // Keep what's showing (the built-in cards the first time).
    }
  }

  VoidCallback? _onTapFor(HomeCard card) => switch (card.action) {
        'MARKET' => widget.onReadyMade,
        'PROMPT' => widget.onPrompt,
        'PRINT_FILE' => () => _readyToPrint(context),
        _ => null,
      };

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
        for (final card in _cards) ...[
          const SizedBox(height: 12),
          _OptionCard(card: card, onTap: _onTapFor(card)!),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final HomeCard card;
  final VoidCallback onTap;

  const _OptionCard({required this.card, required this.onTap});

  String get title => card.title;
  String get description => card.description;
  IconData get icon => _kHomeIcons[card.icon] ?? Icons.category_rounded;

  List<Color> get colors {
    final start = _hex(card.colorStart) ?? AppColors.purple;
    return [start, _hex(card.colorEnd) ?? start];
  }

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
                      child: card.iconImage != null
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.network(
                                ApiConfig.assetUrl(card.iconImage!),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(icon, color: Colors.white, size: 28),
                              ),
                            )
                          : Icon(icon, color: Colors.white, size: 28),
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
