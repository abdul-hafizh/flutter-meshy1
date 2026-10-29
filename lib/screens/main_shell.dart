import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nearby_merchant.dart';
import '../providers/auth_controller.dart';
import '../providers/active_address_controller.dart';
import '../providers/cart_controller.dart';
import '../services/play_billing_service.dart';
import '../services/print_file_service.dart';
import '../services/shared_file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat/print_file_sheet.dart';
import '../widgets/store_picker.dart';
import 'chat/open_store_chat.dart';
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
    // "Bagikan ke Petope": a file shared before or after signing in.
    SharedFileService.pending.addListener(_onSharedFile);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSharedFile());
  }

  @override
  void dispose() {
    SharedFileService.pending.removeListener(_onSharedFile);
    super.dispose();
  }

  bool _handlingShare = false;

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// A 3D file shared from another app (e.g. a WhatsApp document): pick the
  /// store first, then fill in material/quantity/notes and send it to that
  /// store's chat — which then opens.
  Future<void> _onSharedFile() async {
    final file = SharedFileService.pending.value;
    if (file == null || _handlingShare || !mounted) return;
    _handlingShare = true;
    SharedFileService.pending.value = null;
    try {
      if (file.error == 'too_large') {
        _toast('Ukuran file maksimal 50 MB.');
        return;
      }
      if (file.path == null) {
        _toast('File yang dibagikan tidak bisa dibuka.');
        return;
      }
      if (!PrintFileService.allowedExtensions.contains(file.extension)) {
        _toast('Petope hanya menerima file STL, OBJ, 3MF, atau STEP.');
        return;
      }
      final store = await Navigator.of(context).push<NearbyMerchant>(
        MaterialPageRoute(
          builder: (_) => StorePickerScreen(
            title: 'Kirim File ke Toko',
            subtitle: 'Pilih toko yang akan mencetak "${file.name}". Setelah itu isi bahan & jumlah, lalu file dikirim ke chat toko.',
          ),
        ),
      );
      if (store == null || !mounted) return;
      final bytes = await File(file.path!).readAsBytes();
      if (!mounted) return;
      final sent = await showPrintFileSheet(context, merchantId: store.id, fileName: file.name, bytes: bytes);
      if (sent && mounted) await openStoreChat(context, store.id);
    } catch (_) {
      if (mounted) _toast('Gagal membuka file yang dibagikan.');
    } finally {
      _handlingShare = false;
      // A file shared while this one was open.
      if (SharedFileService.pending.value != null) _onSharedFile();
    }
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
