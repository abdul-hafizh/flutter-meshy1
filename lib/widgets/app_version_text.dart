import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';

/// Small muted "Versi 1.0.7" line, read from the installed app (pubspec
/// `version:` — the part before `+`). [showBuild] adds the build number
/// ("Versi 1.0.7 (7)"), handy on the profile page when reporting a problem.
class AppVersionText extends StatelessWidget {
  final bool showBuild;

  const AppVersionText({super.key, this.showBuild = false});

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox(height: 16);
        final build = showBuild && info.buildNumber.isNotEmpty ? ' (${info.buildNumber})' : '';
        return Text(
          'Versi ${info.version}$build',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textFaint, fontWeight: FontWeight.w500),
        );
      },
    );
  }
}
