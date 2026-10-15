import 'package:flutter/foundation.dart';

import '../services/cart_service.dart';

/// Keeps the cart badge count (number of lines) in sync across screens —
/// the home header shows it, product/cart screens update it.
class CartController extends ChangeNotifier {
  int count = 0;

  Future<void> refresh(String? token) async {
    if (token == null) return;
    try {
      final next = await CartService.count(token: token);
      if (next != count) {
        count = next;
        notifyListeners();
      }
    } catch (_) {
      // Badge only — keep the last known count.
    }
  }

  void setCount(int next) {
    if (next == count) return;
    count = next;
    notifyListeners();
  }

  void clear() => setCount(0);
}
