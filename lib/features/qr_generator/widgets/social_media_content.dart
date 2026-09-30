import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_dimens.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';
import 'social_page_form.dart';
import 'whatsapp_form.dart';

// Réseaux sociaux : page publique de liens, ou discussion WhatsApp ouverte
// directement au scan.
class SocialMediaContent extends ConsumerWidget {
  const SocialMediaContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      qrContentViewModelProvider.select((s) => s.socialMediaMode),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<SocialMediaMode>(
          segments: const [
            ButtonSegment(
              value: SocialMediaMode.page,
              label: Text('Ma page de liens'),
            ),
            ButtonSegment(
              value: SocialMediaMode.whatsapp,
              label: Text('WhatsApp direct'),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => ref
              .read(qrContentViewModelProvider.notifier)
              .setSocialMediaMode(selection.single),
        ),
        switch (mode) {
          SocialMediaMode.page => const SocialPageForm(),
          SocialMediaMode.whatsapp => const WhatsAppForm(),
        },
      ],
    );
  }
}
