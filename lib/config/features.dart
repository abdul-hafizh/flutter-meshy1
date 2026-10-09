import 'package:flutter/foundation.dart';

import '../services/play_billing_service.dart';

/// Token purchases are shown only where the payment method is allowed for
/// in-app digital goods: Android sells them through Google Play Billing
/// (PlayBillingService), the web keeps Midtrans. iOS stays hidden until
/// Apple In-App Purchase is wired up (Apple forbids third-party payment too).
bool get kTokenPurchaseEnabled => kIsWeb || PlayBillingService.isSupported;
