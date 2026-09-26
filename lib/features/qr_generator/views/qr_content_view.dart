import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/widgets/error_message.dart';

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

  static const double _maxContentWidth = 560;

  // Au-delà de cette largeur (tablette), l'aperçu s'affiche à côté du
  // formulaire au lieu d'en dessous.
  static const double _sideBySideBreakpoint = 840;
  static const double _previewWidth = 360;

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
            if (hasPreview && constraints.maxWidth >= _sideBySideBreakpoint) {
              return _SideBySide(content: content);
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: _Scrollable(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      if (hasPreview) ...[
                        const SizedBox(height: 24),
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
      bottomNavigationBar: const _GenerateButton(),
    );
  }
}

// Disposition tablette : formulaire à gauche, aperçu fixe à droite.
class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth:
              QrContentView._maxContentWidth + QrContentView._previewWidth + 64,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Scrollable(child: content)),
            const SizedBox(
              width: QrContentView._previewWidth,
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: child,
    );
  }
}

// Isolé pour ne reconstruire que le bouton quand un envoi démarre.
class _GenerateButton extends ConsumerWidget {
  const _GenerateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saveError != null) ...[
            ErrorMessage(saveError),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: isBusy ? null : generate,
            icon: progressLabel != null
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2_rounded),
            label: Text(progressLabel ?? 'Générer le QR Code'),
          ),
        ],
      ),
    );
  }
}
