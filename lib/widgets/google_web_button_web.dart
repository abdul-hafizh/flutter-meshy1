import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'google_web_button_stub.dart' show GoogleWebButtonText;

export 'google_web_button_stub.dart' show GoogleWebButtonText;

/// Renders Google's own Identity Services button. Web doesn't allow
/// triggering the sign-in popup from a custom button, so this widget
/// replaces [GoogleAuthButton] entirely on that platform.
Widget renderGoogleWebButton({required GoogleWebButtonText text}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      shape: web.GSIButtonShape.pill,
      text: switch (text) {
        GoogleWebButtonText.signIn => web.GSIButtonText.signinWith,
        GoogleWebButtonText.signUp => web.GSIButtonText.signupWith,
      },
      minimumWidth: 320,
    ),
  );
}
