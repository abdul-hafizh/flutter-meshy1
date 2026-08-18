import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small tappable pill showing the user's current AI-credit ("token")
/// balance — tap navigates to the buy-tokens flow.
class TokenBalanceBadge extends StatelessWidget {
  final int credits;
  final VoidCallback onTap;

  const TokenBalanceBadge({super.key, required this.credits, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradientSoft,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
                child: const Icon(Icons.toll_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                '$credits',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 3),
              const Text(
                'Token',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
