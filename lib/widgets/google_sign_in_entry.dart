import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import 'google_auth_button.dart';
import 'google_web_button.dart';

/// Cross-platform Google sign-in entry point.
///
/// Android/iOS/desktop get our own styled [GoogleAuthButton], which drives
/// the flow imperatively via [onPressed]. Web can't trigger the Google
/// sign-in popup from a custom button — Google requires its own rendered
/// button there — so on web this renders that instead; the resulting
/// account arrives through [GoogleAuthService.authenticationEvents],
/// which the screen embedding this widget must listen to separately.
class GoogleSignInEntry extends StatefulWidget {
  final String label;
  final GoogleWebButtonText webText;
  final VoidCallback onPressed;

  const GoogleSignInEntry({
    super.key,
    required this.label,
    required this.webText,
    required this.onPressed,
  });

  @override
  State<GoogleSignInEntry> createState() => _GoogleSignInEntryState();
}

class _GoogleSignInEntryState extends State<GoogleSignInEntry> {
  Future<void>? _ready;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _ready = GoogleAuthService.ensureInitialized();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return GoogleAuthButton(label: widget.label, onPressed: widget.onPressed);
    }
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 52,
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return SizedBox(height: 52, child: Center(child: renderGoogleWebButton(text: widget.webText)));
      },
    );
  }
}
