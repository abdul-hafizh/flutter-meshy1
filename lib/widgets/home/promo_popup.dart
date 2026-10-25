import 'package:flutter/material.dart';

import '../../services/promotion_service.dart';
import '../../theme/app_theme.dart';

/// Shows the running promos as a full-screen-ish portrait ad over the home
/// screen; several promos can be swiped. The customer closes it with ✕.
Future<void> showPromoPopup(BuildContext context, List<Promotion> promos) {
  if (promos.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _PromoDialog(promos: promos),
  );
}

class _PromoDialog extends StatefulWidget {
  final List<Promotion> promos;

  const _PromoDialog({required this.promos});

  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promos = widget.promos;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Tutup',
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: promos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _PromoImage(promo: promos[i]),
                ),
              ),
            ),
          ),
          if (promos.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < promos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PromoImage extends StatelessWidget {
  final Promotion promo;

  const _PromoImage({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: promo.title,
      image: true,
      child: Image.network(
        promo.imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const ColoredBox(
                color: AppColors.surface,
                child: Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                promo.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
