import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file shared to Petope from another app ("Bagikan ke Petope"), already
/// copied into the app's cache by MainActivity. [error] is set instead of
/// [path] when it couldn't be taken ("too_large", "read_failed").
class SharedFile {
  final String? path;
  final String name;
  final int? size;
  final String? error;

  const SharedFile({this.path, required this.name, this.size, this.error});

  factory SharedFile.fromMap(Map<String, dynamic> map) => SharedFile(
        path: map['path']?.toString(),
        name: map['name']?.toString() ?? 'file',
        size: map['size'] is num ? (map['size'] as num).toInt() : null,
        error: map['error']?.toString(),
      );

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Receives files shared to Petope (Android only). [pending] holds the latest
/// one until the app — once signed in (MainShell) — takes it.
class SharedFileService {
  static const _channel = MethodChannel('com.petope.app/share');
  static final ValueNotifier<SharedFile?> pending = ValueNotifier(null);
  static bool _started = false;

  static void start() {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;
    // A share while the app is already open (or one still being copied at launch).
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedFileAvailable') await _take();
    });
    // A share that launched the app.
    _take();
  }

  static Future<void> _take() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('takeSharedFile');
      if (map != null) pending.value = SharedFile.fromMap(map);
    } on PlatformException catch (_) {
      // Nothing shared / channel not ready — ignore.
    } on MissingPluginException catch (_) {}
  }
}
