import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_address.dart';
import '../services/user_address_service.dart';

/// The shipping address the customer is shopping for right now — shown on
/// the home screen ("Dikirim ke …"), used to find nearby stores and
/// preselected at checkout. Defaults to the customer's main (default)
/// address; a different pick is remembered on the device.
class ActiveAddressController extends ChangeNotifier {
  static const _prefsKey = 'active_address_id';

  List<UserAddress> addresses = const [];
  UserAddress? address;
  bool loading = false;
  bool loaded = false;

  /// Reloads the saved addresses (after adding/editing one, or on start).
  Future<void> load(String? token) async {
    if (token == null) return;
    loading = true;
    notifyListeners();
    try {
      final list = await UserAddressService.listMine(token: token);
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefsKey);
      addresses = list;
      address = _pick(list, savedId);
      loaded = true;
    } catch (_) {
      // Keep what we had — the home screen offers a retry.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static UserAddress? _pick(List<UserAddress> list, String? savedId) {
    if (list.isEmpty) return null;
    for (final a in list) {
      if (a.id == savedId) return a;
    }
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  Future<void> select(UserAddress next) async {
    address = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.id);
  }

  /// On logout: forget everything (another account may log in next).
  Future<void> clear() async {
    addresses = const [];
    address = null;
    loaded = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
