import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../core/widgets/error_message.dart';
import '../models/shared_file.dart';
import '../viewmodels/qr_content_state.dart';
import '../viewmodels/qr_content_view_model.dart';

// Textes propres à chaque type de fichier.
typedef _Copy = ({
  String title,
  String description,
  String pickLabel,
  String selectedLabel,
  String onlineLabel,
  String footer,
  IconData icon,
});

_Copy _copyFor(SharedFileKind kind) => switch (kind) {
  SharedFileKind.cv => (
    title: 'Partagez votre CV',
    description:
        'Sélectionnez votre CV au format PDF\npour créer votre QR Code.',
    pickLabel: 'Choisir un PDF',
    selectedLabel: 'PDF sélectionné',
    onlineLabel: 'CV en ligne',
    footer:
        'Le QR Code contiendra un lien vers votre CV en ligne, '
        'et non le fichier lui-même.',
    icon: Icons.picture_as_pdf_outlined,
  ),
  SharedFileKind.businessCardImage => (
    title: "Ajoutez l'image de votre carte",
    description:
        'Choisissez une photo ou un scan de votre carte de visite.\n'
        'Le QR Code ouvrira cette image.',
    pickLabel: 'Choisir une image',
    selectedLabel: 'Image sélectionnée',
    onlineLabel: 'Image en ligne',
    footer:
        'Le QR Code contiendra un lien vers votre image en ligne, '
        'et non l’image elle-même.',
    icon: Icons.image_outlined,
  ),
};

// Sélection d'un fichier partagé par lien (CV, image de carte de visite)
// et affichage du fichier retenu.
class SharedFilePicker extends ConsumerWidget {
  const SharedFilePicker({super.key, required this.kind});

  final SharedFileKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileState = ref.watch(
      qrContentViewModelProvider.select((s) => s.fileState(kind)),
    );
    final file = fileState.file;
    final copy = _copyFor(kind);
    void pick() {
      final viewModel = ref.read(qrContentViewModelProvider.notifier);
      switch (kind) {
        case SharedFileKind.cv:
          viewModel.pickCv();
        case SharedFileKind.businessCardImage:
          viewModel.pickCardImage();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: file == null
              ? _EmptyCard(
                  kind: kind,
                  copy: copy,
                  state: fileState,
                  onPick: pick,
                )
              : _SelectedCard(
                  kind: kind,
                  copy: copy,
                  state: fileState,
                  file: file,
                  onPick: pick,
                ),
        ),
        if (fileState.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          ErrorMessage(message),
        ],
        const SizedBox(height: 16),
        Text(
          copy.footer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.kind,
    required this.copy,
    required this.state,
    required this.onPick,
  });

  final SharedFileKind kind;
  final _Copy copy;
  final FileState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            _FileIcon(size: 64, icon: copy.icon),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                copy.title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.isBusy ? null : onPick,
              icon: state.status == FileStatus.selecting
                  ? const _ButtonSpinner()
                  : const Icon(Icons.attach_file_rounded),
              label: Text(copy.pickLabel),
            ),
            const SizedBox(height: 8),
            Text(
              '${kind.formatLabel} · '
              '${formatFileSize(SharedFileKind.maxSizeBytes)} maximum',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.kind,
    required this.copy,
    required this.state,
    required this.file,
    required this.onPick,
  });

  final SharedFileKind kind;
  final _Copy copy;
  final FileState state;
  final SharedFile file;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (statusLabel, statusIcon) = switch (state.status) {
      FileStatus.uploading => ('Envoi en cours…', Icons.cloud_upload_outlined),
      FileStatus.uploaded => (copy.onlineLabel, Icons.cloud_done_outlined),
      _ => (copy.selectedLabel, Icons.check_circle_rounded),
    };

    return Card(
      key: const ValueKey('selected'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                switch (kind) {
                  SharedFileKind.businessCardImage => _ImageThumbnail(
                    file: file,
                    fallback: copy.icon,
                  ),
                  SharedFileKind.cv => _FileIcon(size: 40, icon: copy.icon),
                },
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        file.size > 0
                            ? formatFileSize(file.size)
                            : 'Fichier déjà en ligne',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  if (state.status == FileStatus.uploading)
                    const _ButtonSpinner()
                  else
                    Icon(statusIcon, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : onPick,
              icon: state.status == FileStatus.selecting
                  ? const _ButtonSpinner()
                  : const Icon(Icons.swap_horiz_rounded),
              label: const Text('Remplacer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
      ),
      child: Icon(icon, size: size * 0.55, color: colors.primary),
    );
  }
}

// Miniature de l'image choisie, décodée en basse résolution pour ne pas
// charger la photo entière en mémoire.
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.file, required this.fallback});

  static const double _size = 64;

  final SharedFile file;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = _FileIcon(size: _size, icon: fallback);
    // Sur le web, l'image est en mémoire ; sur mobile, elle est lue sur le
    // disque.
    final bytes = file.bytes;
    final path = file.localPath;
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes)
        : path != null
        ? FileImage(File(path))
        : null;
    if (image == null) return placeholder;

    final pixels = (_size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius - 4),
      child: Image(
        image: ResizeImage(image, width: pixels),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
