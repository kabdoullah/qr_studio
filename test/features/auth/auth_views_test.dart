import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/features/auth/views/login_view.dart';
import 'package:qr_studio/features/auth/views/register_view.dart';
import 'package:qr_studio/features/qr_generator/views/qr_generator_view.dart';

import '../../helpers/fake_services.dart';

void main() {
  late FakeAuthService auth;
  late FakeTokenStorage storage;
  late FakeGoogleAuthService google;
  late FakeFacebookAuthService facebook;

  Future<void> pumpApp(
    WidgetTester tester, {
    String? token,
    bool social = false,
  }) async {
    auth = FakeAuthService();
    storage = FakeTokenStorage(token);
    google = FakeGoogleAuthService();
    facebook = FakeFacebookAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedIn(
          auth: auth,
          storage: storage,
          google: social ? google : null,
          facebook: social ? facebook : null,
        ),
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

  testWidgets('saisir l’email ne signale pas le mot de passe vide', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir votre mot de passe.'), findsNothing);
  });

  testWidgets('sans session, l’application ouvre la connexion', (tester) async {
    await pumpApp(tester);

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Vos QR Codes,\nau même endroit.'), findsOneWidget);
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
    expect(storage.refreshToken, isNotNull);
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
    expect(storage.refreshToken, isNull);
  });

  testWidgets('sans configuration, ni Google ni Facebook', (tester) async {
    await pumpApp(tester);

    expect(find.text('Continuer avec Google'), findsNothing);
    expect(find.text('Continuer avec Facebook'), findsNothing);
    expect(find.text('ou'), findsNothing);
  });

  group('Google et Facebook', () {
    testWidgets('proposés sur la connexion et l’inscription', (tester) async {
      await pumpApp(tester, social: true);

      expect(find.text('ou'), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.text('Continuer avec Facebook'), findsOneWidget);

      await tapButton(tester, 'Créer un compte');
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.text('Continuer avec Facebook'), findsOneWidget);
      expect(find.text('Déjà un compte ?'), findsOneWidget);

      await tapButton(tester, 'Se connecter');
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('Google : le serveur vérifie l’ID token, puis accueil', (
      tester,
    ) async {
      await pumpApp(tester, social: true);

      await tapButton(tester, 'Continuer avec Google');

      expect(auth.googleTokens, ['google-id-token']);
      expect(find.byType(QrGeneratorView), findsOneWidget);
      expect(storage.refreshToken, isNotNull);
    });

    testWidgets('Google annulé : reste sur la connexion, sans message', (
      tester,
    ) async {
      await pumpApp(tester, social: true);
      google.next = null;

      await tapButton(tester, 'Continuer avec Google');

      expect(find.byType(LoginView), findsOneWidget);
      expect(auth.googleTokens, isEmpty);
      expect(find.textContaining('a échoué'), findsNothing);
    });

    testWidgets('Facebook refusé par le serveur : message affiché', (
      tester,
    ) async {
      await pumpApp(tester, social: true);
      auth.socialError = const ApiException(
        ApiErrorKind.conflict,
        serverMessage: 'Un compte existe déjà avec cette adresse.',
      );

      await tapButton(tester, 'Continuer avec Facebook');

      expect(auth.facebookTokens, ['facebook-access-token']);
      expect(find.byType(LoginView), findsOneWidget);
      expect(
        find.text('Un compte existe déjà avec cette adresse.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('pas de débordement sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, social: true);
    expect(tester.takeException(), isNull);

    await tapButton(tester, 'Créer un compte');
    expect(tester.takeException(), isNull);
  });
}
