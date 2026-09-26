import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

import '../../../app/theme/app_dimens.dart';
import '../models/shared_file.dart';
import '../services/business_card_directory_service.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';
import 'business_card_form.dart';
import 'publish_card_section.dart';
import 'shared_file_picker.dart';

// Carte de visite : saisie des coordonnées (vCard) ou image de la carte
// partagée par lien.
class BusinessCardContent extends ConsumerWidget {
  const BusinessCardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      qrContentViewModelProvider.select((s) => s.businessCardMode),
    );
    // Cartes partagées : disponibles seulement avec un serveur configuré.
    final hasDirectory = ref.watch(businessCardDirectoryProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<BusinessCardMode>(
          segments: const [
            ButtonSegment(
              value: BusinessCardMode.details,
              label: Text('Mes coordonnées'),
            ),
            ButtonSegment(
              value: BusinessCardMode.image,
              label: Text('Image de ma carte'),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => ref
              .read(qrContentViewModelProvider.notifier)
              .setBusinessCardMode(selection.single),
        ),
        switch (mode) {
          BusinessCardMode.details => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasDirectory) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.savedCards),
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Choisir une carte enregistrée'),
                ),
              ],
              const BusinessCardForm(),
              if (hasDirectory) const PublishCardSection(),
            ],
          ),
          BusinessCardMode.image => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: SharedFilePicker(kind: SharedFileKind.businessCardImage),
          ),
        },
      ],
    );
  }
}
