import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 56,
  });

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        gradient: _enabled ? AppColors.brandGradient : null,
        color: _enabled ? null : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _enabled
            ? [
                BoxShadow(
                  color: AppColors.shadowFor(AppColors.orange),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _enabled ? Colors.white : AppColors.textFaint,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 18,
                    color: _enabled ? Colors.white : AppColors.textFaint,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
