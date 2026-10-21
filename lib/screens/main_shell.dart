import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/active_address_controller.dart';
import '../providers/cart_controller.dart';
import '../services/play_billing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _marketKey = GlobalKey<MarketScreenState>();
  final _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    // Listens for Google Play token purchases app-wide and finishes any left
    // unconfirmed by the backend last time (see PlayBillingService).
    PlayBillingService.instance.start(context.read<AuthController>());
    // Cart badge on the home header.
    context.read<CartController>().refresh(context.read<AuthController>().token);
    // Delivery address shown on the home screen (default = main address).
    context.read<ActiveAddressController>().load(context.read<AuthController>().token);
  }

  void _goTo(int i) {
    final changed = i != _index;
    setState(() => _index = i);
    // Fresh data each time a list tab is opened.
    if (i == 0 && changed) _homeKey.currentState?.reload();
    if (i == 2) _marketKey.currentState?.reload();
    if (i == 3) _ordersKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(key: _homeKey, onCreateTap: () => _goTo(1), onSeeAllTap: () => _goTo(2)),
      CreateScreen(onCreated: () => _goTo(3)),
      MarketScreen(key: _marketKey),
      OrdersScreen(key: _ordersKey),
      const ProfileScreen(),
    ];

    // System back: close an open order detail first, then return to the
    // home tab; only back on the home tab leaves the app.
    final canExit = _index == 0;
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index == 3 && (_ordersKey.currentState?.handleBack() ?? false)) return;
        _goTo(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _goTo),
      ),
    );
  }
}
