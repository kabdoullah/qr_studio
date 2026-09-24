import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_qr_data.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Saisie d'un texte libre (l'aperçu en direct est affiché par la vue).
class TextForm extends ConsumerWidget {
  const TextForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text('Votre texte', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text(
            'Écrivez le contenu que vous souhaitez partager.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
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
