import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../app/theme/app_theme.dart';
import '../models/qr_style.dart';

// Affiche un QR Code à partir de son contenu, sans connaître son type.
class QrPreview extends StatelessWidget {
  const QrPreview({
    super.key,
    required this.data,
    this.style = const QrStyle(),
  });

  final String data;
  final QrStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = math.min(style.size, constraints.maxWidth);
        return Center(
          child: Semantics(
            image: true,
            label: 'Aperçu du QR Code',
            child: Container(
              width: dimension,
              height: dimension,
              padding: EdgeInsets.all(dimension * 0.06),
              decoration: BoxDecoration(
                color: style.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: PrettyQrView.data(
                data: data,
                errorCorrectLevel: style.errorCorrectLevel,
                decoration: style.toDecoration(),
                errorBuilder: (context, error, stackTrace) =>
                    _QrPreviewError(color: style.foregroundColor),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QrPreviewError extends StatelessWidget {
  const _QrPreviewError({required this.color});

  // Couleur du QR : lisible sur le fond du QR, quel que soit le thème.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Impossible de générer le QR Code.\n'
        'Veuillez vérifier les informations saisies.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}
