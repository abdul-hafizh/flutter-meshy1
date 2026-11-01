import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Optional "Gunakan jasa edit" — the store edits the 3D model and prices
/// that work; the order is paid once the customer agrees to that price.
/// Used on the prompt screen and when sending a ready-to-print file.
class EditServiceOption extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String description;

  const EditServiceOption({super.key, required this.value, required this.onChanged, required this.description});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? AppColors.purple.withValues(alpha: 0.07) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: value ? AppColors.purple : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                activeColor: AppColors.purple,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gunakan jasa edit (opsional)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
