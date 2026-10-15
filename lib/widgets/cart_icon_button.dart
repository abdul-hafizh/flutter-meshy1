import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import '../screens/cart/cart_screen.dart';
import '../theme/app_theme.dart';

/// Round cart button with the number of lines in the cart — opens CartScreen
/// and refreshes the count when coming back.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartController>().count;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
        if (!context.mounted) return;
        context.read<CartController>().refresh(context.read<AuthController>().token);
      },
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 21),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0453A),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
