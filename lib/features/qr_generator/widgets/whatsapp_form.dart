import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../models/qr_type.dart';
import '../models/whatsapp_qr_data.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Discussion WhatsApp : titre (pour « Mes QR Codes »), numéro et message
// prérempli facultatif. Le QR Code ouvre directement la conversation.
class WhatsAppForm extends ConsumerWidget {
  const WhatsAppForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Valeurs initiales : conservées lorsque l'utilisateur revient modifier.
    final data = ref.read(qrContentViewModelProvider).whatsapp;
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.socialMedia),
      ),
    );
    final viewModel = ref.read(qrContentViewModelProvider.notifier);

    return Form(
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Discussion WhatsApp',
            description:
                'Le QR Code ouvre directement une conversation avec votre '
                'numéro.',
          ),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: data.title,
            decoration: const InputDecoration(
              labelText: 'Titre *',
              hintText: 'WhatsApp professionnel',
            ),
            maxLength: WhatsAppQrData.maxTitleLength,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) =>
                viewModel.updateWhatsApp((d) => d.copyWith(title: v)),
            validator: (v) => QrContentState.validateWhatsAppTitle(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          const SizedBox(height: 8),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: data.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro WhatsApp *',
              hintText: '+225 07 12 34 56 78',
              helperText: 'Avec l’indicatif du pays.',
              prefixIcon: Icon(Icons.chat_outlined),
            ),
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            onChanged: (v) =>
                viewModel.updateWhatsApp((d) => d.copyWith(phone: v)),
            validator: (v) => QrContentState.validateWhatsAppPhone(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          const SizedBox(height: 16),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            initialValue: data.message,
            decoration: const InputDecoration(
              labelText: 'Message prérempli (optionnel)',
              hintText: 'Bonjour, je viens de scanner votre QR Code.',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 5,
            maxLength: WhatsAppQrData.maxMessageLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) =>
                viewModel.updateWhatsApp((d) => d.copyWith(message: v)),
            validator: (v) => QrContentState.validateWhatsAppMessage(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          const SizedBox(height: 8),
          Text(
            'Le numéro est inscrit dans le QR Code : toute personne qui le '
            'scanne pourra vous écrire.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
