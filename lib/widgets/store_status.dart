import 'package:flutter/material.dart';

import '../models/operating_status.dart';
import '../theme/app_theme.dart';

const _closedColor = Color(0xFFE0453A);

/// Small "Tutup" pill next to a store name (nothing when open or when the
/// merchant has no schedule). With [showOpen] an open store gets "Buka".
class StoreStatusBadge extends StatelessWidget {
  final OperatingStatus? status;
  final bool showOpen;

  const StoreStatusBadge({super.key, required this.status, this.showOpen = false});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || !s.configured) return const SizedBox.shrink();
    if (s.isOpen && !showOpen) return const SizedBox.shrink();
    final color = s.isOpen ? AppColors.success : _closedColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.isOpen ? 'Buka' : 'Tutup',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// "● Tutup · buka besok 08:00 WIB" — tap to see the weekly schedule.
class StoreStatusLine extends StatelessWidget {
  final OperatingStatus? status;

  const StoreStatusLine({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || !s.configured || s.label == null) return const SizedBox.shrink();
    final color = s.isOpen ? AppColors.success : _closedColor;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: s.weekly.isEmpty ? null : () => showOperatingHoursSheet(context, s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                s.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            if (s.weekly.isNotEmpty) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Orange note shown while ordering from a closed store: the order still
/// goes through, the merchant processes it once it opens.
class ClosedStoreNotice extends StatelessWidget {
  final OperatingStatus? status;

  const ClosedStoreNotice({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || !s.isClosed) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: AppColors.orangeDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.closedOrderNotice,
              style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showOperatingHoursSheet(BuildContext context, OperatingStatus status) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jam Operasional',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            StoreStatusLine(status: OperatingStatus(
              configured: status.configured,
              isOpen: status.isOpen,
              label: status.label,
            )),
            if (status.closedNote != null && status.closedNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(status.closedNote!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            for (final day in status.weekly)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        day.dayName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      day.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w500,
                        color: day.text == 'Tutup' ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
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
