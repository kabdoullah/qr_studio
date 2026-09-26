import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/icon_badge.dart';
import '../models/qr_type.dart';
import '../models/social_network.dart';
import '../models/social_page_data.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Formulaire de la page de réseaux sociaux : titre, description et liens.
class SocialPageForm extends ConsumerStatefulWidget {
  const SocialPageForm({super.key});

  @override
  ConsumerState<SocialPageForm> createState() => _SocialPageFormState();
}

class _SocialPageFormState extends ConsumerState<SocialPageForm> {
  final _formKey = GlobalKey<FormState>();

  // Amène la première erreur à l'écran après une génération refusée.
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

  Future<void> _addLink() async {
    final network = await showModalBottomSheet<SocialNetwork>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _NetworkSheet(),
    );
    if (network == null) return;
    ref.read(qrContentViewModelProvider.notifier).addSocialLink(network);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Valeurs initiales : conservées lorsque l'utilisateur revient modifier.
    final page = ref.read(qrContentViewModelProvider).socialPage;
    final links = ref.watch(
      qrContentViewModelProvider.select((s) => s.socialPage.links),
    );
    final showAllErrors = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.showErrorsFor.contains(QrType.socialMedia),
      ),
    );
    final viewModel = ref.read(qrContentViewModelProvider.notifier);
    ref.listen(
      qrContentViewModelProvider.select((s) => s.failedGenerations),
      (_, _) => _revealFirstError(),
    );

    return Form(
      key: _formKey,
      autovalidateMode: showAllErrors
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Votre page',
            description: 'Partagez tous vos réseaux avec un seul QR Code.',
          ),
          TextFormField(
            initialValue: page.title,
            decoration: const InputDecoration(
              labelText: 'Titre *',
              hintText: 'Mes réseaux sociaux',
            ),
            maxLength: SocialPageData.maxTitleLength,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) =>
                viewModel.updateSocialPage((p) => p.copyWith(title: v)),
            validator: (v) => QrContentState.validateSocialTitle(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: page.bio,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Retrouvez-moi…',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 5,
            maxLength: SocialPageData.maxBioLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) =>
                viewModel.updateSocialPage((p) => p.copyWith(bio: v)),
            validator: (v) => QrContentState.validateSocialBio(v ?? ''),
            scrollPadding: const EdgeInsets.only(bottom: 120),
          ),
          SectionHeader(
            'Mes réseaux',
            subtitle: '${links.length} / ${SocialPageData.maxLinks}',
            divider: true,
          ),
          for (final (index, link) in links.indexed)
            _LinkField(
              key: ValueKey(link.id),
              link: link,
              isLast: index == links.length - 1,
            ),
          // Erreur « aucun réseau », intégrée au formulaire pour que le
          // retour à la première erreur la prenne en compte.
          FormField<void>(
            validator: (_) => QrContentState.validateSocialLinks(
              ref.read(qrContentViewModelProvider).socialPage.links,
            ),
            builder: (field) => field.hasError
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      field.errorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          OutlinedButton.icon(
            onPressed: links.length < SocialPageData.maxLinks ? _addLink : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un réseau'),
          ),
          const SizedBox(height: 16),
          Text(
            'Votre page sera publique pour toute personne ayant le QR Code. '
            'Vous pourrez la modifier ou la supprimer depuis « Mes QR Codes ».',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Saisie d'un réseau : nom d'utilisateur, numéro ou lien.
class _LinkField extends ConsumerWidget {
  const _LinkField({super.key, required this.link, required this.isLast});

  final SocialLink link;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = link.network;
    final viewModel = ref.read(qrContentViewModelProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: link.value,
        decoration: InputDecoration(
          labelText: network.label,
          hintText: network.hint,
          prefixIcon: Icon(network.icon),
          suffixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: TextButton(
              onPressed: () => viewModel.removeSocialLink(link.id),
              child: Text(
                'Retirer',
                semanticsLabel: 'Retirer ${network.label}',
              ),
            ),
          ),
        ),
        keyboardType: switch (network) {
          SocialNetwork.whatsapp => TextInputType.phone,
          SocialNetwork.website => TextInputType.url,
          _ => TextInputType.text,
        },
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        inputFormatters: [
          LengthLimitingTextInputFormatter(SocialNetwork.maxUrlLength),
        ],
        onChanged: (v) => viewModel.updateSocialLink(link.id, v),
        validator: (v) => QrContentState.validateSocialLink(network, v ?? ''),
        scrollPadding: const EdgeInsets.only(bottom: 120),
      ),
    );
  }
}

// Liste des réseaux proposés à l'ajout.
class _NetworkSheet extends StatelessWidget {
  const _NetworkSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              child: Text(
                'Ajouter un réseau',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          for (final network in SocialNetwork.values)
            ListTile(
              leading: IconBadge(network.icon, size: 40),
              title: Text(network.label),
              minTileHeight: 64,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              onTap: () => Navigator.of(context).pop(network),
            ),
        ],
      ),
    );
  }
}
