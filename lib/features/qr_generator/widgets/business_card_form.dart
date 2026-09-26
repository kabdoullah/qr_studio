import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../models/business_card_data.dart';
import '../models/qr_type.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Formulaire de la carte de visite, organisé en sections.
class BusinessCardForm extends ConsumerStatefulWidget {
  const BusinessCardForm({super.key});

  @override
  ConsumerState<BusinessCardForm> createState() => _BusinessCardFormState();
}

class _BusinessCardFormState extends ConsumerState<BusinessCardForm> {
  GlobalKey<FormState> _formKey = GlobalKey();
  int _revision = 0;

  // Amène le premier champ en erreur à l'écran (et l'annonce aux lecteurs
  // d'écran) : sans cela, une génération refusée passe inaperçue quand
  // l'utilisateur a défilé vers le bas du formulaire.
  void _revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invalid = _formKey.currentState?.validateGranularly();
      if (invalid == null || invalid.isEmpty || !mounted) return;
      Scrollable.ensureVisible(
        invalid.first.context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
    // Nouvelle clé : les champs sont recréés avec la carte chargée.
    if (revision != _revision) {
      _revision = revision;
      _formKey = GlobalKey();
    }
    ref.listen(
      qrContentViewModelProvider.select((s) => s.failedGenerations),
      (_, _) => _revealFirstError(),
    );

    return Form(
      key: _formKey,
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Informations personnelles'),
            _FieldRow(
              first: _Field(
                label: 'Prénom *',
                initialValue: card.firstName,
                autofillHints: const [AutofillHints.givenName],
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => update((c) => c.copyWith(firstName: v)),
                validator: (v) => QrContentState.validateFirstName(v ?? ''),
              ),
              second: _Field(
                label: 'Nom *',
                initialValue: card.lastName,
                autofillHints: const [AutofillHints.familyName],
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => update((c) => c.copyWith(lastName: v)),
                validator: (v) => QrContentState.validateLastName(v ?? ''),
              ),
            ),
            _FieldRow(
              first: _Field(
                label: 'Fonction',
                initialValue: card.jobTitle,
                autofillHints: const [AutofillHints.jobTitle],
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => update((c) => c.copyWith(jobTitle: v)),
              ),
              second: _Field(
                label: 'Entreprise',
                initialValue: card.company,
                autofillHints: const [AutofillHints.organizationName],
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => update((c) => c.copyWith(company: v)),
              ),
            ),
            const SectionHeader('Contact', divider: true),
            _FieldRow(
              first: _Field(
                label: 'Téléphone',
                initialValue: card.phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (v) => update((c) => c.copyWith(phone: v)),
              ),
              second: _Field(
                label: 'Email',
                initialValue: card.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onChanged: (v) => update((c) => c.copyWith(email: v)),
                validator: (v) => QrContentState.validateEmail(v ?? ''),
              ),
            ),
            _Field(
              label: 'Site web',
              initialValue: card.website,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              onChanged: (v) => update((c) => c.copyWith(website: v)),
            ),
            const SectionHeader('Adresse', divider: true),
            _Field(
              label: 'Adresse',
              initialValue: card.address,
              keyboardType: TextInputType.streetAddress,
              autofillHints: const [AutofillHints.streetAddressLine1],
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => update((c) => c.copyWith(address: v)),
            ),
            _FieldRow(
              first: _Field(
                label: 'Ville',
                initialValue: card.city,
                autofillHints: const [AutofillHints.addressCity],
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => update((c) => c.copyWith(city: v)),
              ),
              second: _Field(
                label: 'Pays',
                initialValue: card.country,
                autofillHints: const [AutofillHints.countryName],
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => update((c) => c.copyWith(country: v)),
              ),
            ),
            const SectionHeader(
              'Réseaux sociaux',
              subtitle: 'Facultatif',
              divider: true,
            ),
            _FieldRow(
              first: _Field(
                label: 'LinkedIn',
                hint: 'Lien ou identifiant',
                initialValue: card.linkedin,
                keyboardType: TextInputType.url,
                onChanged: (v) => update((c) => c.copyWith(linkedin: v)),
              ),
              second: _Field(
                label: 'Instagram',
                hint: '@identifiant',
                initialValue: card.instagram,
                keyboardType: TextInputType.url,
                onChanged: (v) => update((c) => c.copyWith(instagram: v)),
              ),
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

// Deux champs côte à côte, ou l'un sous l'autre quand la largeur disponible
// (rapportée à la taille du texte) ne suffit pas.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.first, required this.second});

  // Largeur minimale, à taille de texte normale, pour deux colonnes lisibles.
  static const double _minTwoColumnWidth = 320;

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _minTwoColumnWidth * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
