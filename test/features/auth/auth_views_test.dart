import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/app.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';
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

  // Depuis l'accueil (utilisateur anonyme) : menu du compte, puis
  // « Se connecter ».
  Future<void> openLogin(WidgetTester tester) async {
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
  }

  // Inscription : depuis la connexion.
  Future<void> openRegister(WidgetTester tester) async {
    await openLogin(tester);
    await tapButton(tester, 'Créer un compte');
  }

  AuthState authState(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(authViewModelProvider);

  testWidgets('saisir l’email ne signale pas le mot de passe vide', (
    tester,
  ) async {
    await pumpApp(tester);
    await openLogin(tester);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir votre mot de passe.'), findsNothing);
  });

  testWidgets('premier lancement : accueil sans connexion ni email', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(LoginView), findsNothing);
    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.text('Créez votre QR Code\nen quelques secondes.'), findsOne);
    expect(auth.anonymousInstallations, ['installation-1']);
    expect(storage.refreshToken, isNotNull);

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Utilisateur QR Studio'), findsOneWidget);
    expect(find.text('Compte anonyme'), findsOneWidget);
    // Création de compte et connexion, dans les Paramètres seulement.
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsNothing);

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterView), findsOneWidget);
  });

  testWidgets('à l’ouverture, l’accueil s’affiche tout de suite, pendant '
      'que la session s’ouvre', (tester) async {
    auth = FakeAuthService()..gate = Completer<void>();
    storage = FakeTokenStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedIn(auth: auth, storage: storage),
        child: const QrStudioApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(authState(tester).status, AuthStatus.unknown);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(authState(tester).status, AuthStatus.anonymous);
  });

  testWidgets('session d’un compte expirée : accueil sans compte, sans '
      'écran de connexion', (tester) async {
    await pumpApp(tester, token: 'jeton');

    ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(sessionTokenProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);
    expect(authState(tester).status, AuthStatus.anonymous);
  });

  testWidgets('serveur injoignable au premier lancement : accueil '
      'utilisable, « Réessayer » là où le serveur est nécessaire', (
    tester,
  ) async {
    auth = FakeAuthService();
    auth.anonymousError = const ApiException(ApiErrorKind.offline);
    storage = FakeTokenStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: signedIn(auth: auth, storage: storage),
        child: const QrStudioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsNothing);
    // Aucun message sur l'accueil.
    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(find.text(AuthViewModel.restoreFailedMessage), findsNothing);

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes QR Codes'));
    await tester.pumpAndSettle();
    expect(find.text(AuthViewModel.restoreFailedMessage), findsOneWidget);

    auth.anonymousError = null;
    await tapButton(tester, 'Réessayer');

    expect(find.text(AuthViewModel.restoreFailedMessage), findsNothing);
    expect(authState(tester).status, AuthStatus.anonymous);
  });

  testWidgets('une session valide ouvre directement l’accueil', (tester) async {
    await pumpApp(tester, token: 'jeton');

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(authState(tester).user?.firstName, 'Awa');
  });

  testWidgets('connexion réussie : accueil', (tester) async {
    await pumpApp(tester);
    await openLogin(tester);
    expect(find.text('Continuer sans compte'), findsNothing);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.enterText(field('Mot de passe'), 'motdepasse');
    await tapButton(tester, 'Se connecter');

    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(authState(tester).user?.firstName, 'Awa');
    expect(authState(tester).status, AuthStatus.authenticated);
  });

  testWidgets('connexion refusée : message et reste sur la connexion', (
    tester,
  ) async {
    await pumpApp(tester);
    await openLogin(tester);

    await tester.enterText(field('Email'), 'awa@example.com');
    await tester.enterText(field('Mot de passe'), 'mauvais');
    await tapButton(tester, 'Se connecter');

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    // La session anonyme est gardée.
    expect(authState(tester).status, AuthStatus.anonymous);
  });

  testWidgets('champs vides : erreurs sans appel au serveur', (tester) async {
    await pumpApp(tester);
    await openLogin(tester);

    await tapButton(tester, 'Se connecter');

    expect(find.text('Veuillez saisir votre email.'), findsOneWidget);
    expect(find.text('Veuillez saisir votre mot de passe.'), findsOneWidget);
    expect(auth.logins, 0);
  });

  testWidgets('inscription : l’utilisateur anonyme devient un compte', (
    tester,
  ) async {
    await pumpApp(tester);
    final anonymousId = authState(tester).user?.id;
    await openRegister(tester);
    expect(find.byType(RegisterView), findsOneWidget);
    expect(find.textContaining('déjà créés sont conservés'), findsOneWidget);

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
    expect(authState(tester).user?.firstName, 'Jean');
    // Même compte : ses QR Codes restent les siens.
    expect(authState(tester).user?.id, anonymousId);
    expect(authState(tester).status, AuthStatus.authenticated);

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Compte synchronisé'), findsOneWidget);
    expect(find.text('jean@example.com'), findsOneWidget);
  });

  testWidgets('se déconnecter : retour à l’accueil sans compte', (
    tester,
  ) async {
    await pumpApp(tester, token: 'jeton');

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsNothing);
    expect(find.byType(QrGeneratorView), findsOneWidget);
    expect(authState(tester).user?.firstName, isNull);
    expect(auth.loggedOut, ['refresh-1']);
    expect(authState(tester).status, AuthStatus.anonymous);
    // Jetons de la session anonyme, pas ceux du compte quitté.
    expect(storage.refreshToken, 'refresh-2');
  });

  testWidgets('sans configuration, ni Google ni Facebook', (tester) async {
    await pumpApp(tester);
    await openLogin(tester);

    expect(find.text('Continuer avec Google'), findsNothing);
    expect(find.text('Continuer avec Facebook'), findsNothing);
    expect(find.text('ou'), findsNothing);
  });

  group('Google et Facebook', () {
    testWidgets('proposés sur la connexion et l’inscription', (tester) async {
      await pumpApp(tester, social: true);
      await openLogin(tester);

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

    testWidgets('Google : le serveur vérifie l’ID token, l’utilisateur '
        'anonyme devient ce compte', (tester) async {
      await pumpApp(tester, social: true);
      final anonymousId = authState(tester).user?.id;
      await openRegister(tester);

      await tapButton(tester, 'Continuer avec Google');

      expect(auth.googleTokens, ['google-id-token']);
      expect(find.byType(QrGeneratorView), findsOneWidget);
      expect(authState(tester).user?.id, anonymousId);
      expect(authState(tester).status, AuthStatus.authenticated);
    });

    testWidgets('Google annulé : reste sur la connexion, sans message', (
      tester,
    ) async {
      await pumpApp(tester, social: true);
      await openLogin(tester);
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
      await openLogin(tester);
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
    await openLogin(tester);
    expect(tester.takeException(), isNull);

    await tapButton(tester, 'Créer un compte');
    expect(tester.takeException(), isNull);
  });
}
