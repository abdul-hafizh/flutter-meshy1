import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Central place for the backend base URL.
///
/// The actual origin used for API/asset traffic is resolved dynamically from
/// api-meshy's own `GET /system/base-url` (backed by the SystemSettings
/// table, editable from the seller dashboard's System Settings page) — a
/// backend domain change only requires updating that DB row, no rebuild of
/// this app. [_bootstrapOrigin] only seeds the very first lookup, and is the
/// fallback before that lookup completes or if it ever fails.
///
/// The lookup itself always queries [_bootstrapOrigin], never the
/// last-resolved value — chaining lookups through a moving target lets one
/// bad DB row become a permanently self-reinforcing dead end with no way to
/// recover short of editing the database directly (this actually happened
/// once on the seller dashboard's equivalent of this file).
class ApiConfig {
  ApiConfig._();

  static const _bootstrapOrigin = 'http://localhost:3000';
  static const _prefsKey = 'dynamic_api_origin';
  static const _cacheTtl = Duration(minutes: 5);

  static String? _cachedOrigin;
  static DateTime? _lastFetchAt;

  /// The Android emulator can't reach the host machine via `localhost` /
  /// `127.0.0.1` — it needs the special alias `10.0.2.2` instead. This only
  /// matters while the resolved origin still points at "this dev machine";
  /// a real production domain (from the dynamic lookup) needs no
  /// translation and is reachable identically from every platform, so it's
  /// applied to whichever origin is actually in play, not hardcoded once.
  static String _forPlatform(String origin) {
    if (kIsWeb || !Platform.isAndroid) return origin;
    final uri = Uri.tryParse(origin);
    if (uri == null || (uri.host != 'localhost' && uri.host != '127.0.0.1')) {
      return origin;
    }
    return origin.replaceFirst(uri.host, '10.0.2.2');
  }

  static String get _origin => _forPlatform(_cachedOrigin ?? _bootstrapOrigin);

  static String get baseUrl => '$_origin/api';

  /// Resolves a backend-relative path (e.g. an uploaded product photo's
  /// `/uploads/xxx.jpg` ThumbnailPath) to a fully-qualified URL that
  /// `Image.network` can actually load — a bare path has no scheme/host, so
  /// it silently fails to load without this. Already-absolute URLs pass
  /// through unchanged.
  static String assetUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$_origin${path.startsWith('/') ? '' : '/'}$path';
  }

  /// Call once at app startup. Loads the last known-good origin from disk
  /// (fast, local) so it's available immediately, then refreshes it from
  /// the backend in the background — never blocks startup on the network.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedOrigin = prefs.getString(_prefsKey);
    } catch (_) {
      // SharedPreferences unavailable — fine, just skip the persisted value.
    }
    unawaited(refresh());
  }

  /// Re-resolves the current origin from the backend. Cheap to call often —
  /// a no-op within [_cacheTtl] of the last attempt — and never throws.
  static Future<void> refresh() async {
    final now = DateTime.now();
    if (_lastFetchAt != null && now.difference(_lastFetchAt!) < _cacheTtl) return;
    _lastFetchAt = now;

    try {
      final lookupUrl = '${_forPlatform(_bootstrapOrigin)}/api/system/base-url';
      final res = await http.get(Uri.parse(lookupUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final resolved = (body['data'] as Map<String, dynamic>?)?['baseUrl'] as String?;
      if (resolved == null || !RegExp(r'^https?://').hasMatch(resolved)) return;

      _cachedOrigin = resolved;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, resolved);
      } catch (_) {
        // Persisting is best-effort — the in-memory value still works for this session.
      }
    } catch (_) {
      // Lookup unreachable — keep serving whatever origin we already have.
    }
  }
}
