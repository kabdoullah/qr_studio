import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../core/widgets/icon_badge.dart';
import '../models/qr_type.dart';

// Carte cliquable représentant un type de QR Code sur l'écran d'accueil.
// Au survol (web) ou à l'appui, elle s'élève et se resserre légèrement.
class QrTypeCard extends StatefulWidget {
  const QrTypeCard({super.key, required this.type, required this.onTap});

  final QrType type;
  final VoidCallback onTap;

  @override
  State<QrTypeCard> createState() => _QrTypeCardState();
}

class _QrTypeCardState extends State<QrTypeCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final type = widget.type;
    final highlighted = _hovered || _pressed;

    // Fusionne titre, description et action de l'InkWell en un seul bouton
    // pour les lecteurs d'écran.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppDurations.normal,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: highlighted
                    ? colors.primary.withValues(alpha: 0.4)
                    : colors.outlineVariant,
              ),
              boxShadow: highlighted
                  ? AppShadows.raised(theme.brightness)
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (value) => setState(() => _hovered = value),
                onHighlightChanged: (value) => setState(() => _pressed = value),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(type.icon, accent: type.accent),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              type.title,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          AnimatedSlide(
                            offset: highlighted
                                ? const Offset(0.15, 0)
                                : Offset.zero,
                            duration: AppDurations.fast,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: highlighted
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        type.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
