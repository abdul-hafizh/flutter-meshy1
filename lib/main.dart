import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_controller.dart';
import 'providers/chat_controller.dart';
import 'screens/auth/auth_gate.dart';
import 'services/api_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the last known-good API origin from disk, then kicks off a
  // background refresh — never blocks startup on the network.
  await ApiConfig.init();
  runApp(const SnapyApp());
}

class SnapyApp extends StatelessWidget {
  const SnapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ChatController()),
      ],
      child: MaterialApp(
        title: 'Snapy AI 3D',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
