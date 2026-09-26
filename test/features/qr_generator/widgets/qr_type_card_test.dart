import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/theme/app_theme.dart';
import 'package:qr_studio/features/qr_generator/models/qr_type.dart';
import 'package:qr_studio/features/qr_generator/widgets/qr_type_card.dart';

void main() {
  testWidgets('les lecteurs d’écran annoncent la carte comme un bouton '
      'activable', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: QrTypeCard(type: QrType.cv, onTap: () => taps++),
        ),
      ),
    );

    final label = '${QrType.cv.title}\n${QrType.cv.description}';
    final node = find.bySemanticsLabel(label);
    expect(
      tester.getSemantics(node),
      matchesSemantics(
        label: label,
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel(label));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('la zone tactile respecte la taille minimale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: QrTypeCard(type: QrType.text, onTap: () {}),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
