import 'package:flutter/material.dart';

import '../models/merchant_queue_status.dart';
import '../theme/app_theme.dart';

/// One-line "Tersedia" / "Sibuk · N antrian · bisa mulai cetak ±jam" note
/// shown wherever a customer picks or orders from a merchant. Renders
/// nothing when the merchant doesn't run a print queue in the app.
class MerchantQueueBadge extends StatelessWidget {
  final MerchantQueueStatus status;
  final double fontSize;

  const MerchantQueueBadge({super.key, required this.status, this.fontSize = 11.5});

  @override
  Widget build(BuildContext context) {
    if (!status.hasPrintQueue) return const SizedBox.shrink();
    final color = status.isBusy ? AppColors.orangeDeep : Colors.green;
    return Row(
      children: [
        Icon(Icons.print_outlined, size: fontSize + 1.5, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            status.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}
