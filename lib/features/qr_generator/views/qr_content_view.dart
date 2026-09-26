import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/loading_button.dart';

import '../models/qr_type.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';
import '../viewmodels/qr_generator_view_model.dart';
import '../models/shared_file.dart';
import '../widgets/business_card_content.dart';
import '../widgets/shared_file_picker.dart';
import '../widgets/qr_live_preview.dart';
import '../widgets/social_page_form.dart';
import '../widgets/text_form.dart';
import '../widgets/website_form.dart';
import '../widgets/wifi_form.dart';

// Saisie du contenu du QR Code selon le type choisi sur l'accueil.
class QrContentView extends ConsumerWidget {
  const QrContentView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(qrGeneratorViewModelProvider);
    final content = switch (type) {
      QrType.businessCard => const BusinessCardContent(),
      QrType.text => const TextForm(),
      QrType.cv => const SharedFilePicker(kind: SharedFileKind.cv),
      QrType.socialMedia => const SocialPageForm(),
      QrType.website => const WebsiteForm(),
      QrType.wifi => const WifiForm(),
      null => const SizedBox.shrink(),
    };
    final hasPreview = ref.watch(
      livePreviewProvider.select((preview) => preview != null),
    );

    return Scaffold(
      appBar: AppBar(title: Text(type?.title ?? 'QR Code')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (hasPreview && constraints.maxWidth >= AppLayout.sideBySide) {
              return _SideBySide(content: content);
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppLayout.form),
                child: _Scrollable(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      if (hasPreview) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const QrLivePreview(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const _GenerateBar(),
    );
  }
}

// Disposition large : formulaire à gauche, aperçu fixe à droite.
class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.form + AppLayout.previewWidth + AppSpacing.giant,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Scrollable(child: content)),
            const SizedBox(
              width: AppLayout.previewWidth,
              child: _Scrollable(child: QrLivePreview()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      child: child,
    );
  }
}

// Barre du bouton « Générer », fixée en bas. Isolée pour ne reconstruire
// que le bouton quand un envoi démarre.
class _GenerateBar extends ConsumerWidget {
  const _GenerateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isBusy = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.cv.isBusy || s.cardImage.isBusy || s.saving.isSaving,
      ),
    );
    // L'envoi peut prendre plusieurs secondes (serveur en veille) : le
    // bouton explique pourquoi il est indisponible.
    final progressLabel = ref.watch(
      qrContentViewModelProvider.select(
        (s) =>
            s.cv.status == FileStatus.uploading ||
                s.cardImage.status == FileStatus.uploading
            ? 'Envoi du fichier…'
            : s.saving.isSaving
            ? 'Enregistrement…'
            : null,
      ),
    );
    final type = ref.watch(qrGeneratorViewModelProvider);
    final saveError = ref.watch(
      qrContentViewModelProvider.select(
        (s) => s.saving.type == type ? s.saving.errorMessage : null,
      ),
    );

    Future<void> generate() async {
      final result = await ref
          .read(qrContentViewModelProvider.notifier)
          .generateQr();
      if (result != null && context.mounted) {
        context.push(AppRoutes.result);
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.form),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (saveError != null) ...[
                  ErrorMessage(saveError),
                  const SizedBox(height: AppSpacing.xs),
                ],
                LoadingButton(
                  label: progressLabel ?? 'Générer le QR Code',
                  isBusy: isBusy,
                  icon: Icons.qr_code_2_rounded,
                  onPressed: generate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
