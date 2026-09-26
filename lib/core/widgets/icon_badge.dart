import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

// Icône sur un fond teinté arrondi (types de QR Code, fichiers, états).
// Sans `accent`, utilise la couleur principale du thème.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.accent, this.size = 44});

  final IconData icon;
  final AccentColor? accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final foreground =
        accent?.foreground(brightness) ?? theme.colorScheme.primary;
    final background =
        accent?.container(brightness) ?? theme.colorScheme.primaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          size >= 56 ? AppRadius.lg : AppRadius.md,
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}
