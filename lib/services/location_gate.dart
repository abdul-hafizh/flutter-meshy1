import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';

/// Customers must have location turned on (GPS on + permission granted)
/// before any transaction — ordering, checkout, payment, buying tokens.
///
/// Call [ensureEnabled] right before the action; it asks for the permission
/// when needed and otherwise explains what to turn on, returning false so
/// the caller stops.
class LocationGate {
  LocationGate._();

  static Future<bool> ensureEnabled(BuildContext context) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!context.mounted) return false;
        await _explain(
          context,
          title: 'Aktifkan Lokasi',
          message: 'Layanan lokasi (GPS) di perangkat kamu masih mati. '
              'Nyalakan lokasi dulu untuk melanjutkan transaksi.',
          actionLabel: 'Buka Pengaturan Lokasi',
          onAction: Geolocator.openLocationSettings,
        );
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        return true;
      }

      if (!context.mounted) return false;
      final forever = permission == LocationPermission.deniedForever;
      final tapped = await _explain(
        context,
        title: 'Izin Lokasi Diperlukan',
        message: forever
            ? 'Izin lokasi untuk aplikasi ini ditolak. Buka pengaturan aplikasi, '
                'pilih Izin › Lokasi, lalu izinkan agar bisa bertransaksi.'
            : 'Transaksi hanya bisa dilakukan jika izin lokasi diberikan. '
                'Ketuk "Izinkan" saat diminta.',
        actionLabel: forever ? 'Buka Pengaturan Aplikasi' : 'Coba Lagi',
        onAction: forever ? Geolocator.openAppSettings : null,
      );
      // "Coba Lagi" → ask the system once more.
      if (!forever && tapped) permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat memeriksa lokasi. Pastikan lokasi perangkat aktif.')),
      );
      return false;
    }
  }

  /// True when the main button was tapped.
  static Future<bool> _explain(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    Future<bool> Function()? onAction,
  }) async {
    final tapped = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_rounded, color: AppColors.purple, size: 32),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (tapped == true && onAction != null) await onAction();
    return tapped == true;
  }
}
