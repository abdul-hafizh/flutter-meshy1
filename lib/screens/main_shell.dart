import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
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
  final _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    // Listens for Google Play token purchases app-wide and finishes any left
    // unconfirmed by the backend last time (see PlayBillingService).
    PlayBillingService.instance.start(context.read<AuthController>());
  }

  void _goTo(int i) {
    setState(() => _index = i);
    if (i == 3) _ordersKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onCreateTap: () => _goTo(1), onSeeAllTap: () => _goTo(2)),
      CreateScreen(onCreated: () => _goTo(3)),
      const MarketScreen(),
      OrdersScreen(key: _ordersKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
