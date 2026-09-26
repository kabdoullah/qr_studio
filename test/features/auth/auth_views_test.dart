import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/features/auth/views/login_view.dart';
import 'package:qr_studio/features/auth/views/register_view.dart';
import 'package:qr_studio/features/qr_generator/views/qr_generator_view.dart';

import '../../helpers/fake_services.dart';

void main() {
  late FakeAuthService auth;
  late FakeTokenStorage storage;

  Future<void> pumpApp(WidgetTester tester, {String? token}) async {
    auth = FakeAuthService();
    storage = FakeTokenStorage(token);
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedIn(auth: auth, storage: storage),
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('sans session, l’application ouvre la connexion', (tester) async {
    await pumpApp(tester);

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Créez et partagez vos QR Codes.'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
  });

  testWidgets('une session valide ouvre directement l’accueil', (tester) async {
    await pumpApp(tester, token: 'jeton');

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.text('Bonjour, Awa'), findsOneWidget);
  });

  testWidgets('connexion réussie : accueil', (tester) async {
    await pumpApp(tester);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.enterText(field('Mot de passe'), 'motdepasse');
    await tapButton(tester, 'Se connecter');

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(storage.token, isNotNull);
  });

  testWidgets('connexion refusée : message et reste sur la connexion', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.enterText(field('Mot de passe'), 'mauvais');
    await tapButton(tester, 'Se connecter');

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('champs vides : erreurs sans appel au serveur', (tester) async {
    await pumpApp(tester);

    await tapButton(tester, 'Se connecter');

    expect(find.text('Veuillez saisir votre email.'), findsOneWidget);
    expect(find.text('Veuillez saisir votre mot de passe.'), findsOneWidget);
    expect(auth.logins, 0);
  });

  testWidgets('inscription : validations puis accueil', (tester) async {
    await pumpApp(tester);
    await tapButton(tester, 'Créer un compte');
    expect(find.byType(RegisterView), findsOneWidget);

    await tester.enterText(field('Prénom'), 'Jean');
    await tester.enterText(field('Nom'), 'Kouassi');
    await tester.enterText(field('Email'), 'jean@example');
    await tester.enterText(field('Mot de passe'), 'court');
    await tester.enterText(field('Confirmation du mot de passe'), 'différent');
    await tapButton(tester, 'Créer mon compte');

    expect(
      find.text('Veuillez saisir une adresse email valide.'),
      findsOneWidget,
    );
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(auth.registered, isEmpty);

    await tester.enterText(field('Email'), 'jean@example.com');
    await tester.enterText(field('Mot de passe'), 'motdepasse');
    await tester.enterText(field('Confirmation du mot de passe'), 'motdepasse');
    await tapButton(tester, 'Créer mon compte');

    expect(auth.registered, ['jean@example.com']);
    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.text('Bonjour, Jean'), findsOneWidget);
  });

  testWidgets('se déconnecter revient à la connexion', (tester) async {
    await pumpApp(tester, token: 'jeton');

    await tester.tap(find.text('Mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    expect(tester.takeException(), isNull);

    await tapButton(tester, 'Créer un compte');
    expect(tester.takeException(), isNull);
  });
}
