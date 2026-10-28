import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// The admin's PPN (Master Pajak, `GET /system/tax-and-fees`). The customer
/// only ever sees prices with PPN included — the backend still prices orders
/// as harga + PPN, so the app grosses every price up for display and never
/// shows PPN as its own line. Also carries the biaya jasa aplikasi — a flat
/// Rupiah the customer pays once per payment (no PPN on it, none on tokens).
class TaxConfig {
  TaxConfig._();

  static const _prefsKey = 'tax_percent';
  static const _appFeeKey = 'customer_app_fee';
  static const _cacheTtl = Duration(minutes: 5);

  static double _percent = 11;
  static int _appFee = 0;
  static DateTime? _lastFetchAt;

  /// Current PPN in percent (e.g. 11).
  static double get percent => _percent;

  /// Biaya jasa aplikasi (Rp) the next payment adds — once, however many stores it pays.
  static int get appFee => _appFee;

  /// [price] with the current PPN included — what a catalog price is shown as.
  static int withPpn(int price) => (price * (1 + _percent / 100)).round();

  /// Loads the last known PPN from disk, then refreshes it in the background.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_prefsKey);
      if (saved != null && saved >= 0) _percent = saved;
      final fee = prefs.getInt(_appFeeKey);
      if (fee != null && fee >= 0) _appFee = fee;
    } catch (_) {
      // SharedPreferences unavailable — keep the default.
    }
    unawaited(refresh());
  }

  /// Re-reads PPN and the app fee from the backend; a no-op within [_cacheTtl]
  /// unless [force] (e.g. opening checkout), never throws.
  static Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastFetchAt != null && now.difference(_lastFetchAt!) < _cacheTtl) return;
    _lastFetchAt = now;
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/system/tax-and-fees')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      final value = data?['taxPercent'];
      final pct = value is num ? value.toDouble() : double.tryParse('$value');
      if (pct == null || pct < 0) return;
      _percent = pct;
      final feeValue = data?['customerAppFeeAmount'];
      final fee = feeValue is num ? feeValue.round() : int.tryParse('$feeValue');
      if (fee != null && fee >= 0) _appFee = fee;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefsKey, pct);
        await prefs.setInt(_appFeeKey, _appFee);
      } catch (_) {
        // Best-effort — the in-memory value still works for this session.
      }
    } catch (_) {
      // Unreachable — keep the value we have.
    }
  }
}

/// A server-priced breakdown (subtotal − membership discount + PPN) shown with
/// PPN folded into the lines: the PPN rate comes from the amounts themselves
/// (PPN ÷ harga dasar), so an order keeps the rate it was priced at and token
/// purchases (no PPN) stay as they are. The rows still add up exactly:
/// [subtotal] − [discount] = harga dasar + PPN.
class PpnInclusive {
  final double rate;
  final int subtotal;
  final int discount;

  const PpnInclusive._(this.rate, this.subtotal, this.discount);

  factory PpnInclusive.of({required int subtotal, int discount = 0, int tax = 0}) {
    final base = subtotal - discount;
    if (tax <= 0 || base <= 0) return PpnInclusive._(0, subtotal, discount);
    final rate = tax / base;
    final grossSubtotal = (subtotal * (1 + rate)).round();
    final grossDiscount = discount > 0 ? grossSubtotal - (base + tax) : 0;
    return PpnInclusive._(rate, grossSubtotal, grossDiscount);
  }

  /// An item price (unit or line total) with this breakdown's PPN included.
  int price(int amount) => (amount * (1 + rate)).round();
}
