import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place for the backend base URL.
///
/// The Android emulator can't reach the host machine via `localhost`, it
/// needs the special alias `10.0.2.2` instead — every other target
/// (desktop, web, iOS simulator) talks to the local dev server directly.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }
}
