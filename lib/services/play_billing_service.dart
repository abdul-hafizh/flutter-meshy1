import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../providers/auth_controller.dart';
import 'ai_credit_service.dart';
import 'auth_service.dart' show ApiException;

/// What happened to a Google Play token purchase, for the UI to show.
sealed class PlayBillingEvent {
  const PlayBillingEvent();
}

class PlayBillingCredited extends PlayBillingEvent {
  final int quantity;
  const PlayBillingCredited(this.quantity);
}

class PlayBillingPending extends PlayBillingEvent {
  const PlayBillingPending();
}

class PlayBillingCanceled extends PlayBillingEvent {
  const PlayBillingCanceled();
}

class PlayBillingFailed extends PlayBillingEvent {
  final String message;
  const PlayBillingFailed(this.message);
}

/// AI-token purchases through Google Play Billing (Android only — Play
/// policy requires it for digital goods; DOKU stays for physical orders).
///
/// Flow: the app buys a `token_<n>` product, sends the purchase token to the
/// backend (`POST /ai-credits/google-play/verify`), which checks it with
/// Google and credits the tokens; only then is the purchase consumed. A
/// purchase the backend hasn't confirmed yet (offline, app killed mid-way)
/// stays unconsumed and is picked up again by [start] on the next launch.
class PlayBillingService {
  PlayBillingService._();
  static final PlayBillingService instance = PlayBillingService._();

  /// Must match the product ids in Play Console → One-time products.
  static const Set<String> productIds = {'token_30', 'token_50'};

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<PlayBillingEvent> _events = StreamController<PlayBillingEvent>.broadcast();
  final Set<String> _verifying = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  AuthController? _auth;

  Stream<PlayBillingEvent> get events => _events.stream;

  /// Starts listening for purchase updates and re-delivers any purchase left
  /// unfinished earlier. Safe to call repeatedly.
  Future<void> start(AuthController auth) async {
    _auth = auth;
    if (!isSupported || _sub != null) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      debugPrint('Play Billing stream error: $e');
    });
    try {
      if (await _iap.isAvailable()) {
        await _iap.restorePurchases(applicationUserName: auth.user?.id);
      }
    } catch (e) {
      debugPrint('Play Billing restore failed: $e');
    }
  }

  /// The token packages as Google Play lists them (with the Play price),
  /// smallest first. Empty when Play is unavailable on this device.
  Future<List<ProductDetails>> loadProducts() async {
    if (!isSupported || !await _iap.isAvailable()) return const [];
    final response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Play Billing: products not found ${response.notFoundIDs}');
    }
    final products = [...response.productDetails]..sort((a, b) => quantityOf(a.id).compareTo(quantityOf(b.id)));
    return products;
  }

  static int quantityOf(String productId) => int.tryParse(productId.replaceFirst('token_', '')) ?? 0;

  /// Opens Google Play's purchase sheet. The outcome arrives on [events].
  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product, applicationUserName: _auth?.user?.id);
    // autoConsume off: the purchase is only consumed after the backend has
    // credited it, so a failed verification can be retried.
    await _iap.buyConsumable(purchaseParam: param, autoConsume: false);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!p.productID.startsWith('token_')) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(const PlayBillingPending());
        case PurchaseStatus.canceled:
          _events.add(const PlayBillingCanceled());
        case PurchaseStatus.error:
          _events.add(PlayBillingFailed(p.error?.message ?? 'Pembelian gagal.'));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
      }
    }
  }

  Future<void> _verify(PurchaseDetails p) async {
    final purchaseToken = p.verificationData.serverVerificationData;
    final token = _auth?.token;
    // Logged out: leave it unconsumed, it comes back after the next login.
    if (token == null || !_verifying.add(purchaseToken)) return;
    try {
      final result = await AiCreditService.verifyGooglePlay(
        token: token,
        productId: p.productID,
        purchaseToken: purchaseToken,
      );
      if (result.pending) {
        _events.add(const PlayBillingPending());
        return;
      }
      if (!result.credited) return;
      await _consume(p);
      await _auth?.refreshUser();
      _events.add(PlayBillingCredited(result.quantity));
    } on ApiException catch (e) {
      _events.add(PlayBillingFailed(e.message));
    } catch (_) {
      _events.add(const PlayBillingFailed('Gagal memverifikasi pembelian. Token akan ditambahkan otomatis saat aplikasi dibuka lagi.'));
    } finally {
      _verifying.remove(purchaseToken);
    }
  }

  /// Consuming also acknowledges the purchase (unacknowledged purchases are
  /// refunded by Google after 3 days) and lets the package be bought again.
  Future<void> _consume(PurchaseDetails p) async {
    try {
      final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await android.consumePurchase(p);
    } catch (e) {
      // The backend consumes server-side too.
      debugPrint('Play Billing consume failed: $e');
    }
  }
}
