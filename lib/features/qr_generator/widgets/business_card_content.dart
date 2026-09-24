import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_file.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';
import 'business_card_form.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SegmentedButton<BusinessCardMode>(
          segments: const [
            ButtonSegment(
              value: BusinessCardMode.details,
              icon: Icon(Icons.edit_note_rounded),
              label: Text('Mes coordonnées'),
            ),
            ButtonSegment(
              value: BusinessCardMode.image,
              icon: Icon(Icons.image_outlined),
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
          BusinessCardMode.details => const BusinessCardForm(),
          BusinessCardMode.image => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SharedFilePicker(kind: SharedFileKind.businessCardImage),
          ),
        },
      ],
    );
  }
}
