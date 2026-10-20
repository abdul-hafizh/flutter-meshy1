import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';
import 'gradient_button.dart';

enum _LocationState { checking, ready, serviceOff, needsPermission, deniedForever }

/// The app can only be used with location turned on: GPS on and the
/// location permission granted. Until then a full-screen page explains why
/// and offers the fix (it also serves as the disclosure shown before the
/// system permission prompt). Re-checked whenever the app comes back to the
/// foreground, and — on Android — the moment GPS is switched off while the
/// app is open.
class LocationRequiredGate extends StatefulWidget {
  final Widget child;

  const LocationRequiredGate({super.key, required this.child});

  @override
  State<LocationRequiredGate> createState() => _LocationRequiredGateState();
}

class _LocationRequiredGateState extends State<LocationRequiredGate> with WidgetsBindingObserver {
  _LocationState _state = _LocationState.checking;
  StreamSubscription<ServiceStatus>? _serviceSub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _serviceSub = Geolocator.getServiceStatusStream().listen((_) => _check());
    }
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings (or from the background).
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    _LocationState next;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        next = _LocationState.serviceOff;
      } else {
        final permission = await Geolocator.checkPermission();
        next = switch (permission) {
          LocationPermission.always || LocationPermission.whileInUse => _LocationState.ready,
          LocationPermission.deniedForever => _LocationState.deniedForever,
          _ => _LocationState.needsPermission,
        };
      }
    } catch (_) {
      // Platform without location support (e.g. some desktop/web setups):
      // don't lock the user out because of it.
      next = _LocationState.ready;
    }
    if (mounted && next != _state) setState(() => _state = next);
  }

  Future<void> _fix() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (_state) {
        case _LocationState.serviceOff:
          await Geolocator.openLocationSettings();
        case _LocationState.needsPermission:
          await Geolocator.requestPermission();
        case _LocationState.deniedForever:
          await Geolocator.openAppSettings();
        default:
          break;
      }
    } catch (_) {
      // Fall through to a re-check.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _LocationState.ready) return widget.child;
    if (_state == _LocationState.checking) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }

    final (title, message, action) = switch (_state) {
      _LocationState.serviceOff => (
          'Aktifkan Lokasi',
          'Layanan lokasi (GPS) di perangkat kamu masih mati. Petope membutuhkan lokasi untuk menampilkan toko terdekat, '
              'menghitung ongkos kirim, dan mengamankan transaksi.',
          'Buka Pengaturan Lokasi',
        ),
      _LocationState.deniedForever => (
          'Izin Lokasi Diperlukan',
          'Izin lokasi untuk Petope ditolak. Buka pengaturan aplikasi, pilih Izin › Lokasi, lalu izinkan agar aplikasi bisa digunakan.',
          'Buka Pengaturan Aplikasi',
        ),
      _ => (
          'Izinkan Akses Lokasi',
          'Petope membutuhkan lokasi kamu selama aplikasi digunakan untuk menampilkan toko terdekat, menghitung ongkos kirim, '
              'dan mengamankan transaksi. Lokasi tidak dibagikan ke pihak lain.',
          'Izinkan Lokasi',
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.location_on_rounded, size: 48, color: AppColors.purple),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              GradientButton(label: _busy ? 'Memeriksa...' : action, icon: Icons.my_location_rounded, onPressed: _busy ? null : _fix),
              const SizedBox(height: 10),
              TextButton(onPressed: _busy ? null : _check, child: const Text('Saya sudah mengaktifkan, cek lagi')),
            ],
          ),
        ),
      ),
    );
  }
}
