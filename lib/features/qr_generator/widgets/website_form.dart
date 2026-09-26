import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../models/qr_type.dart';
import '../models/website_qr_data.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Site web : titre (pour « Mes QR Codes ») et adresse du site. Le QR Code
// mène à l'adresse publique QR Studio, qui ouvre ce site.
class WebsiteForm extends ConsumerWidget {
  const WebsiteForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Valeurs initiales : conservées lorsque l'utilisateur revient modifier.
    final site = ref.read(qrContentViewModelProvider).website;
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.website),
      ),
    );
    final viewModel = ref.read(qrContentViewModelProvider.notifier);

    return Form(
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Votre site',
            description:
                'Partagez votre site avec un QR Code. Vous pourrez changer '
                "l'adresse plus tard sans le réimprimer.",
          ),
          TextFormField(
            initialValue: site.title,
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Mon portfolio',
            ),
            maxLength: WebsiteQrData.maxTitleLength,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) =>
                viewModel.updateWebsite((s) => s.copyWith(title: v)),
            validator: (v) => QrContentState.validateWebsiteTitle(v ?? ''),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: site.url,
            decoration: const InputDecoration(
              labelText: 'URL du site *',
              hintText: 'https://example.com',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: WebsiteQrData.maxUrlLength,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            textInputAction: TextInputAction.done,
            onChanged: (v) =>
                viewModel.updateWebsite((s) => s.copyWith(url: v)),
            validator: (v) => QrContentState.validateWebsiteUrl(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
        ],
      ),
    );
  }
}
