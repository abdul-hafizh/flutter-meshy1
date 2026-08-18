import 'package:flutter/widgets.dart';

/// Non-web platforms never call this — [GoogleSignInEntry] only reaches
/// here when `kIsWeb` is true, at which point the real implementation in
/// google_web_button_web.dart is compiled in instead.
Widget renderGoogleWebButton({required GoogleWebButtonText text}) {
  throw UnsupportedError('The Google web button is only available on web.');
}

enum GoogleWebButtonText { signIn, signUp }
