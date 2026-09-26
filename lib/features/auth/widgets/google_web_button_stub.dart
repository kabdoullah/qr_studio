import 'package:flutter/widgets.dart';

// Hors web, le bouton Google est un bouton Flutter (voir
// `SocialSignInButtons`) : ce widget n'est jamais affiché.
Widget googleWebButton() => const SizedBox.shrink();
