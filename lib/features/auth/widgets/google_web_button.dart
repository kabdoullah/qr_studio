import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google;

// Bouton « Continuer avec Google » dessiné par Google Identity Services :
// sur le web, c'est le seul moyen d'obtenir un ID token. Le jeton arrive
// par `GoogleAuthService.idTokens`.
Widget googleWebButton() => google.renderButton(
  configuration: google.GSIButtonConfiguration(
    text: google.GSIButtonText.continueWith,
    shape: google.GSIButtonShape.pill,
    size: google.GSIButtonSize.large,
    locale: 'fr',
  ),
);
