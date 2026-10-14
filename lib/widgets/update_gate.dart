import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_theme.dart';

/// Makes every Google Play update mandatory: when Play reports a newer
/// version, its full-screen in-app update flow (Play's "immediate" update)
/// downloads, installs and restarts the app without leaving it. If the user
/// backs out of that screen, the app stays blocked behind [_UpdateRequiredView]
/// until they update.
///
/// Checked on launch and whenever the app returns to the foreground. Only
/// works for installs from Google Play — debug builds and sideloaded APKs
/// can't query Play, so they simply pass through.
class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _updateRequired = false;
  bool _checking = false;
  bool _updating = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid && !kDebugMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Play's update screen (or from the background): re-check, so
    // an update left half-way resumes and a new release is caught.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!_supported || _checking || _updating) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available = info.updateAvailability == UpdateAvailability.updateAvailable ||
          info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress;
      if (!mounted) return;
      if (!available || !info.immediateUpdateAllowed) {
        if (_updateRequired) setState(() => _updateRequired = false);
        return;
      }
      setState(() => _updateRequired = true);
      await _startUpdate();
    } catch (e) {
      // Not installed from Play, offline, Play Store outdated… — never lock
      // the user out because the check itself failed.
      debugPrint('In-app update check failed: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _startUpdate() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      // On success Play installs the update and restarts the app, so this
      // usually never returns; a cancel/failure keeps the block screen up.
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('In-app update failed: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _retry() async {
    try {
      // Play requires a fresh check before every update request.
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateNotAvailable) {
        if (mounted) setState(() => _updateRequired = false);
        return;
      }
    } catch (_) {
      // Fall through and try anyway.
    }
    await _startUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_updateRequired) return widget.child;
    return _UpdateRequiredView(updating: _updating, onUpdate: _retry);
  }
}

class _UpdateRequiredView extends StatelessWidget {
  final bool updating;
  final VoidCallback onUpdate;

  const _UpdateRequiredView({required this.updating, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update Diperlukan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Versi baru Petope sudah tersedia. Perbarui aplikasi untuk melanjutkan — '
                  'proses update berlangsung langsung di aplikasi ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: updating ? null : onUpdate,
                    icon: updating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(updating ? 'Memperbarui...' : 'Perbarui Sekarang'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
