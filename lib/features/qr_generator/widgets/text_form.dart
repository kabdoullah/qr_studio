import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../models/text_qr_data.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Saisie d'un texte libre (l'aperçu en direct est affiché par la vue).
class TextForm extends ConsumerWidget {
  const TextForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Valeur initiale : conservée lorsque l'utilisateur revient modifier.
    final initialText = ref.read(qrContentViewModelProvider).text.text;
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.text),
      ),
    );

    return Form(
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Votre texte',
            description: 'Écrivez le contenu que vous souhaitez partager.',
          ),
          TextFormField(
            initialValue: initialText,
            minLines: 5,
            maxLines: 10,
            maxLength: TextQrData.maxLength,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Votre texte…',
              alignLabelWithHint: true,
            ),
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => Text(
                  '$currentLength / $maxLength',
                  semanticsLabel: '$currentLength caractères sur $maxLength',
                ),
            onChanged: ref.read(qrContentViewModelProvider.notifier).updateText,
            validator: (v) => QrContentState.validateText(v ?? ''),
          ),
        ],
      ),
    );
  }
}
