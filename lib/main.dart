import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/active_address_controller.dart';
import 'providers/auth_controller.dart';
import 'providers/cart_controller.dart';
import 'providers/chat_controller.dart';
import 'screens/auth/auth_gate.dart';
import 'services/api_config.dart';
import 'services/shared_file_service.dart';
import 'services/tax_config.dart';
import 'theme/app_theme.dart';
import 'widgets/location_required_gate.dart';
import 'widgets/update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the last known-good API origin from disk, then kicks off a
  // background refresh — never blocks startup on the network.
  await ApiConfig.init();
  // Prices are shown with PPN included — last known rate, refreshed in the background.
  await TaxConfig.init();
  // "Bagikan ke Petope": files shared from other apps (handled once signed in, in MainShell).
  SharedFileService.start();
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
        ChangeNotifierProvider(create: (_) => CartController()),
        ChangeNotifierProvider(create: (_) => ActiveAddressController()),
      ],
      child: MaterialApp(
        title: 'Petope',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Blocks the app until a pending Google Play update is installed,
        // then until location is on and allowed (required to use the app).
        home: const UpdateGate(child: LocationRequiredGate(child: AuthGate())),
      ),
    );
  }
}
