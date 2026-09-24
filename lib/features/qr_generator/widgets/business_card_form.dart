import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_card_data.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Formulaire de la carte de visite, organisé en sections.
class BusinessCardForm extends ConsumerWidget {
  const BusinessCardForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Valeurs initiales : conservées lorsque l'utilisateur revient modifier.
    final card = ref.read(qrContentViewModelProvider).businessCard;
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.businessCard),
      ),
    );
    final viewModel = ref.read(qrContentViewModelProvider.notifier);

    void update(BusinessCardData Function(BusinessCardData) change) =>
        viewModel.updateBusinessCard(change);

    final revision = ref.watch(
      qrContentViewModelProvider.select((s) => s.businessCardRevision),
    );

    return Form(
      // Nouvelle clé : les champs sont recréés avec la carte chargée.
      key: ValueKey(revision),
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('Informations personnelles'),
            _Field(
              label: 'Prénom *',
              initialValue: card.firstName,
              autofillHints: const [AutofillHints.givenName],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => update((c) => c.copyWith(firstName: v)),
              validator: (v) => QrContentState.validateFirstName(v ?? ''),
            ),
            _Field(
              label: 'Nom *',
              initialValue: card.lastName,
              autofillHints: const [AutofillHints.familyName],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => update((c) => c.copyWith(lastName: v)),
              validator: (v) => QrContentState.validateLastName(v ?? ''),
            ),
            _Field(
              label: 'Fonction',
              initialValue: card.jobTitle,
              autofillHints: const [AutofillHints.jobTitle],
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => update((c) => c.copyWith(jobTitle: v)),
            ),
            _Field(
              label: 'Entreprise',
              initialValue: card.company,
              autofillHints: const [AutofillHints.organizationName],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => update((c) => c.copyWith(company: v)),
            ),
            const _SectionTitle('Contact'),
            _Field(
              label: 'Téléphone',
              initialValue: card.phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              onChanged: (v) => update((c) => c.copyWith(phone: v)),
            ),
            _Field(
              label: 'Email',
              initialValue: card.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (v) => update((c) => c.copyWith(email: v)),
              validator: (v) => QrContentState.validateEmail(v ?? ''),
            ),
            _Field(
              label: 'Site web',
              initialValue: card.website,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              onChanged: (v) => update((c) => c.copyWith(website: v)),
            ),
            const _SectionTitle('Adresse'),
            _Field(
              label: 'Adresse',
              initialValue: card.address,
              keyboardType: TextInputType.streetAddress,
              autofillHints: const [AutofillHints.streetAddressLine1],
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => update((c) => c.copyWith(address: v)),
            ),
            _Field(
              label: 'Ville',
              initialValue: card.city,
              autofillHints: const [AutofillHints.addressCity],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => update((c) => c.copyWith(city: v)),
            ),
            _Field(
              label: 'Pays',
              initialValue: card.country,
              autofillHints: const [AutofillHints.countryName],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => update((c) => c.copyWith(country: v)),
            ),
            const _SectionTitle('Réseaux sociaux', subtitle: 'Facultatif'),
            _Field(
              label: 'LinkedIn',
              hint: "Lien ou nom d'utilisateur",
              initialValue: card.linkedin,
              keyboardType: TextInputType.url,
              onChanged: (v) => update((c) => c.copyWith(linkedin: v)),
            ),
            _Field(
              label: 'Instagram',
              hint: "@nom d'utilisateur",
              initialValue: card.instagram,
              keyboardType: TextInputType.url,
              onChanged: (v) => update((c) => c.copyWith(instagram: v)),
            ),
            _Field(
              label: 'WhatsApp',
              hint: 'Numéro avec indicatif, ex. +225…',
              initialValue: card.whatsapp,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onChanged: (v) => update((c) => c.copyWith(whatsapp: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            text: title,
            style: theme.textTheme.titleMedium,
            children: [
              if (subtitle != null)
                TextSpan(
                  text: '  ·  $subtitle',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(labelText: label, hintText: hint),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        onChanged: onChanged,
        validator: validator,
        inputFormatters: [LengthLimitingTextInputFormatter(200)],
        // Garde une marge sous le champ actif au-dessus du clavier.
        scrollPadding: const EdgeInsets.only(bottom: 120),
      ),
    );
  }
}
