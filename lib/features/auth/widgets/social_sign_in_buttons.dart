import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../services/facebook_auth_service.dart';
import '../services/google_auth_service.dart';
import '../viewmodels/auth_view_model.dart';
import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button.dart';

// « ou » suivi des connexions Google et Facebook configurées. Rien n'est
// affiché si aucune ne l'est. Aucun mot de passe n'est demandé : le compte
// est créé ou retrouvé par le serveur.
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final google = ref.watch(googleAuthServiceProvider);
    final facebook = ref.watch(facebookAuthServiceProvider);
    if (!google.isAvailable && !facebook.isAvailable) {
      return const SizedBox.shrink();
    }
    final isBusy = ref.watch(
      authViewModelProvider.select((s) => s.isSubmitting),
    );
    final viewModel = ref.read(authViewModelProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.xl),
        if (google.isAvailable)
          google.usesGoogleButton
              ? _GoogleWebButton(google)
              : OutlinedButton.icon(
                  onPressed: isBusy ? null : viewModel.loginWithGoogle,
                  icon: const _GoogleGlyph(),
                  label: const Text('Continuer avec Google'),
                ),
        if (google.isAvailable && facebook.isAvailable)
          const SizedBox(height: AppSpacing.sm),
        if (facebook.isAvailable)
          OutlinedButton.icon(
            onPressed: isBusy ? null : viewModel.loginWithFacebook,
            icon: const Icon(Icons.facebook_rounded, color: AppColors.facebook),
            label: const Text('Continuer avec Facebook'),
          ),
      ],
    );
  }
}

// « G » de Google, sobre : le bouton reste neutre, sans publicité.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: Center(
          child: Text(
            'G',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ou',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// Le bouton Google web ne peut être dessiné qu'une fois le SDK initialisé.
class _GoogleWebButton extends StatefulWidget {
  const _GoogleWebButton(this.google);

  final GoogleAuthService google;

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  late final Future<void> _ready = widget.google.ready;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) => switch (snapshot.connectionState) {
        ConnectionState.done when !snapshot.hasError => Center(
          child: googleWebButton(),
        ),
        ConnectionState.done => const SizedBox.shrink(),
        _ => const SizedBox(height: 44),
      },
    );
  }
}
