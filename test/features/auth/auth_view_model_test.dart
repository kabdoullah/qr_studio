import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/router/app_router.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/core/storage/installation_storage.dart';
import 'package:qr_studio/core/storage/token_storage.dart';
import 'package:qr_studio/features/auth/services/auth_service.dart';
import 'package:qr_studio/features/auth/services/facebook_auth_service.dart';
import 'package:qr_studio/features/auth/services/google_auth_service.dart';
import 'package:qr_studio/features/auth/services/social_sign_in_exception.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';

import '../../helpers/fake_services.dart';

void main() {
  late FakeAuthService auth;
  late FakeTokenStorage storage;
  late FakeGoogleAuthService google;
  late FakeFacebookAuthService facebook;
  late FakeInstallationStorage installation;
  late ProviderContainer container;

  Future<void> start({
    String? token,
    bool googleButton = false,
    String? installationId,
  }) async {
    storage = FakeTokenStorage(token);
    installation = FakeInstallationStorage(installationId);
    google = FakeGoogleAuthService(usesGoogleButton: googleButton);
    facebook = FakeFacebookAuthService();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        installationStorageProvider.overrideWithValue(installation),
        authServiceProvider.overrideWithValue(auth),
        googleAuthServiceProvider.overrideWithValue(google),
        facebookAuthServiceProvider.overrideWithValue(facebook),
      ],
    );
    container.listen(authViewModelProvider, (_, _) {});
    // Laisse la restauration de session se terminer.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  AuthState state() => container.read(authViewModelProvider);
  AuthViewModel viewModel() => container.read(authViewModelProvider.notifier);

  setUp(() => auth = FakeAuthService());
  tearDown(() => container.dispose());

  group('restauration de session', () {
    test('premier lancement : session anonyme, sans connexion', () async {
      await start();

      expect(state().status, AuthStatus.anonymous);
      expect(state().user?.isAnonymous, isTrue);
      expect(state().user?.email, isNull);
      expect(state().errorMessage, isNull);
      expect(auth.refreshed, isEmpty);
      // Identifiant d'installation créé puis présenté au serveur ; la
      // session est ensuite portée par les jetons.
      expect(installation.created, 1);
      expect(auth.anonymousInstallations, ['installation-1']);
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-1');
      expect(storage.refreshToken, 'refresh-1');
    });

    test('identifiant d’installation existant : réutilisé', () async {
      await start(installationId: 'installation-existante');

      expect(installation.created, 0);
      expect(auth.anonymousInstallations, ['installation-existante']);
      expect(state().user?.id, 'anonyme-installation-existante');
    });

    test('session anonyme enregistrée : restaurée sans nouvel appel '
        'anonyme', () async {
      auth = FakeAuthService(user: anonymousUser);

      await start(token: 'refresh-anonyme');

      expect(auth.refreshed, ['refresh-anonyme']);
      expect(auth.anonymousInstallations, isEmpty);
      expect(state().status, AuthStatus.anonymous);
      expect(state().user?.id, anonymousUser.id);
    });

    test('serveur injoignable sans session : message (pas de connexion '
        'demandée), puis « Réessayer »', () async {
      auth.anonymousError = const ApiException(ApiErrorKind.offline);

      await start();

      expect(state().status, AuthStatus.unavailable);
      expect(state().notice, AuthViewModel.restoreFailedMessage);
      expect(storage.tokens, isNull);

      auth.anonymousError = null;
      expect(await viewModel().ensureSession(), isTrue);

      expect(state().status, AuthStatus.anonymous);
      expect(state().notice, isNull);
      // Même installation : même utilisateur anonyme.
      expect(auth.anonymousInstallations, ['installation-1', 'installation-1']);
    });

    test('stockage sécurisé illisible : message, pas de session', () async {
      await start();
      container.dispose();
      auth = FakeAuthService();
      final broken = FakeInstallationStorage()..error = StateError('keystore');
      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          installationStorageProvider.overrideWithValue(broken),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      container.listen(authViewModelProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state().status, AuthStatus.unavailable);
      expect(state().notice, AuthViewModel.unexpectedMessage);
      expect(auth.anonymousInstallations, isEmpty);
    });

    test('jeton de renouvellement valide : session ouverte sans '
        'reconnexion', () async {
      await start(token: 'refresh-enregistré');

      expect(auth.refreshed, ['refresh-enregistré']);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.firstName, 'Awa');
      // Nouvelle paire en mémoire et enregistrée (rotation).
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-1');
      expect(storage.refreshToken, 'refresh-1');
    });

    test('jeton expiré ou révoqué (401) : remplacé par une session '
        'anonyme', () async {
      auth.refreshError = const ApiException(ApiErrorKind.unauthorized);

      await start(token: 'expiré');

      expect(state().status, AuthStatus.anonymous);
      expect(state().errorMessage, isNull);
      expect(auth.anonymousInstallations, ['installation-1']);
      expect(storage.refreshToken, 'refresh-1');
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-1');
    });

    test('compte désactivé (403) : session anonyme', () async {
      auth.refreshError = const ApiException(ApiErrorKind.forbidden);

      await start(token: 'refresh');

      expect(state().status, AuthStatus.anonymous);
      expect(storage.refreshToken, 'refresh-1');
    });

    test('serveur injoignable : pas de session, jeton gardé', () async {
      auth.refreshError = const ApiException(ApiErrorKind.offline);

      await start(token: 'refresh');

      expect(state().status, AuthStatus.unavailable);
      expect(state().notice, AuthViewModel.restoreFailedMessage);
      expect(storage.refreshToken, 'refresh');
      // La session enregistrée n'est pas remplacée par une anonyme.
      expect(auth.anonymousInstallations, isEmpty);
    });
  });

  group('connexion', () {
    test('succès : jeton enregistré et utilisateur chargé', () async {
      await start();

      final ok = await viewModel().login(
        email: 'awa@example.com',
        password: 'motdepasse',
      );

      expect(ok, isTrue);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.email, 'awa@example.com');
      // Jetons du compte, après ceux de la session anonyme.
      expect(storage.refreshToken, 'refresh-2');
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-2');
    });

    test('échec : message du serveur, session anonyme gardée', () async {
      await start();

      final ok = await viewModel().login(
        email: 'awa@example.com',
        password: 'mauvais',
      );

      expect(ok, isFalse);
      expect(state().status, AuthStatus.anonymous);
      expect(state().user?.isAnonymous, isTrue);
      expect(state().errorMessage, 'Email ou mot de passe incorrect.');
      expect(storage.refreshToken, 'refresh-1');
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-1');
    });

    test('indique l’envoi en cours et ignore un second appel', () async {
      await start();
      auth.gate = Completer<void>();

      final pending = viewModel().login(
        email: 'a@b.co',
        password: 'motdepasse',
      );
      expect(state().isSubmitting, isTrue);
      expect(
        await viewModel().login(email: 'a@b.co', password: 'motdepasse'),
        isFalse,
      );

      auth.gate!.complete();
      expect(await pending, isTrue);
      expect(auth.logins, 1);
    });

    test('sans serveur : message honnête', () async {
      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          authServiceProvider.overrideWithValue(null),
        ],
      );
      container.listen(authViewModelProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await viewModel().login(email: 'a@b.co', password: 'motdepasse');

      expect(state().errorMessage, AuthViewModel.unavailableMessage);
    });
  });

  test(
    'inscription : l’utilisateur anonyme devient un compte (même id)',
    () async {
      await start();
      final anonymousId = state().user?.id;

      final ok = await viewModel().register(
        firstName: 'Jean',
        lastName: 'Kouassi',
        email: 'jean@example.com',
        password: 'motdepasse',
      );

      expect(ok, isTrue);
      expect(auth.registered, ['jean@example.com']);
      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.firstName, 'Jean');
      expect(state().user?.id, anonymousId);
      expect(state().user?.isAnonymous, isFalse);
      expect(auth.logins, 0);
      expect(storage.refreshToken, 'refresh-2');
    },
  );

  test('inscription refusée : message du serveur', () async {
    await start();
    auth.registerError = const ApiException(
      ApiErrorKind.conflict,
      serverMessage: 'Un compte existe déjà avec cette adresse email.',
    );

    await viewModel().register(
      firstName: 'Awa',
      lastName: 'Traoré',
      email: 'awa@example.com',
      password: 'motdepasse',
    );

    expect(state().status, AuthStatus.anonymous);
    expect(
      state().errorMessage,
      'Un compte existe déjà avec cette adresse email.',
    );
  });

  test('déconnexion : session serveur terminée, SDK déconnectés, puis '
      'session anonyme de l’installation', () async {
    await start(token: 'refresh');

    await viewModel().logout();

    expect(state().status, AuthStatus.anonymous);
    expect(state().errorMessage, isNull);
    expect(state().user?.isAnonymous, isTrue);
    expect(auth.loggedOut, ['refresh-1']);
    // Jetons de la session anonyme : aucun retour automatique au compte.
    expect(storage.refreshToken, 'refresh-2');
    expect(container.read(sessionTokenProvider)?.accessToken, 'access-2');
    expect(google.signOuts, 1);
    expect(facebook.signOuts, 1);
  });

  group('suppression du compte', () {
    test('supprimé côté serveur, puis session anonyme de l’installation, '
        'sans appel de déconnexion', () async {
      await start(token: 'refresh');

      final message = await viewModel().deleteAccount();

      expect(message, AuthViewModel.accountDeletedMessage);
      expect(auth.deletedAccounts, 1);
      expect(auth.loggedOut, isEmpty);
      expect(state().status, AuthStatus.anonymous);
      expect(state().isSubmitting, isFalse);
      expect(storage.refreshToken, 'refresh-2');
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-2');
      expect(google.signOuts, 1);
      expect(facebook.signOuts, 1);
    });

    test('échec : le compte reste ouvert, avec le message', () async {
      await start(token: 'refresh');
      auth.deleteError = const ApiException(ApiErrorKind.offline);

      final message = await viewModel().deleteAccount();

      expect(message, const ApiException(ApiErrorKind.offline).message);
      expect(state().status, AuthStatus.authenticated);
      expect(state().isSubmitting, isFalse);
      expect(storage.refreshToken, 'refresh-1');
      expect(google.signOuts, 0);
    });

    test('utilisateur anonyme : rien n’est supprimé', () async {
      await start();

      await viewModel().deleteAccount();

      expect(auth.deletedAccounts, 0);
      expect(state().status, AuthStatus.anonymous);
    });
  });

  test('session anonyme refusée pendant l’usage : rouverte sans message, '
      'même utilisateur', () async {
    await start();
    final anonymousId = state().user?.id;

    container.read(sessionTokenProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(state().status, AuthStatus.anonymous);
    expect(state().errorMessage, isNull);
    expect(state().user?.id, anonymousId);
    expect(auth.anonymousInstallations, ['installation-1', 'installation-1']);
    expect(storage.refreshToken, 'refresh-2');
  });

  test('session d’un compte refusée pendant l’usage : l’application '
      'continue sans compte', () async {
    await start(token: 'refresh');

    // Ce que fait `ApiClient` quand le renouvellement est refusé.
    container.read(sessionTokenProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(state().status, AuthStatus.anonymous);
    expect(state().notice, isNull);
    expect(auth.anonymousInstallations, ['installation-1']);
    // Jetons de la session anonyme, plus ceux du compte.
    expect(storage.refreshToken, 'refresh-2');
  });

  test('ensureSession attend l’ouverture de session du lancement', () async {
    auth.gate = Completer<void>();
    storage = FakeTokenStorage();
    installation = FakeInstallationStorage();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        installationStorageProvider.overrideWithValue(installation),
        authServiceProvider.overrideWithValue(auth),
        googleAuthServiceProvider.overrideWithValue(FakeGoogleAuthService()),
        facebookAuthServiceProvider.overrideWithValue(
          FakeFacebookAuthService(),
        ),
      ],
    );
    container.listen(authViewModelProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(state().status, AuthStatus.unknown);

    final ready = viewModel().ensureSession();
    auth.gate!.complete();

    expect(await ready, isTrue);
    expect(state().status, AuthStatus.anonymous);
    // Une seule ouverture de session.
    expect(auth.anonymousInstallations, ['installation-1']);
  });

  test('connexion pendant l’ouverture de session du lancement : le compte '
      'n’est pas remplacé ensuite par la session anonyme', () async {
    auth.gate = Completer<void>();
    await start();
    expect(state().status, AuthStatus.unknown);

    final login = viewModel().login(
      email: 'awa@example.com',
      password: 'motdepasse',
    );
    expect(state().isSubmitting, isTrue);
    auth.gate!.complete();

    expect(await login, isTrue);
    expect(state().status, AuthStatus.authenticated);
    expect(state().user?.email, 'awa@example.com');
  });

  test('jetons renouvelés par le client HTTP : enregistrés', () async {
    await start(token: 'refresh');

    container
        .read(sessionTokenProvider.notifier)
        .set(const AuthTokens(accessToken: 'a2', refreshToken: 'r2'));
    await Future<void>.delayed(Duration.zero);

    expect(storage.refreshToken, 'r2');
    expect(state().status, AuthStatus.authenticated);
  });

  group('Google', () {
    test('succès : l’ID token est envoyé au serveur', () async {
      await start();

      expect(await viewModel().loginWithGoogle(), isTrue);

      expect(auth.googleTokens, ['google-id-token']);
      expect(state().status, AuthStatus.authenticated);
      expect(storage.refreshToken, 'refresh-2');
    });

    test('utilisateur anonyme : converti, même id', () async {
      await start();
      final anonymousId = state().user?.id;

      expect(await viewModel().loginWithGoogle(), isTrue);

      expect(state().user?.id, anonymousId);
      expect(state().user?.isAnonymous, isFalse);
      expect(state().user?.email, 'awa@example.com');
    });

    test('annulation : aucun message, aucun appel', () async {
      await start();
      google.next = null;

      expect(await viewModel().loginWithGoogle(), isFalse);

      expect(auth.googleTokens, isEmpty);
      expect(state().status, AuthStatus.anonymous);
      expect(state().user?.isAnonymous, isTrue);
      expect(state().isSubmitting, isFalse);
      expect(state().errorMessage, isNull);
    });

    test('échec du SDK : message clair', () async {
      await start();
      google.error = const SocialSignInException('google', 'réseau');

      expect(await viewModel().loginWithGoogle(), isFalse);

      expect(state().errorMessage, AuthViewModel.socialFailedMessage('Google'));
      // La session anonyme est gardée.
      expect(storage.refreshToken, 'refresh-1');
      expect(state().status, AuthStatus.anonymous);
    });

    test('compte existant non lié : message du serveur', () async {
      await start();
      auth.socialError = const ApiException(
        ApiErrorKind.conflict,
        serverMessage: 'Un compte existe déjà avec cette adresse.',
      );

      await viewModel().loginWithGoogle();

      expect(state().errorMessage, 'Un compte existe déjà avec cette adresse.');
      expect(state().status, AuthStatus.anonymous);
    });

    test('web : l’ID token du bouton Google ouvre la session', () async {
      await start(googleButton: true);

      google.webTokens.add('jeton-web');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(auth.googleTokens, ['jeton-web']);
      expect(state().status, AuthStatus.authenticated);
    });

    test('web : erreur du bouton Google affichée', () async {
      await start(googleButton: true);

      google.webTokens.addError(const SocialSignInException('google'));
      await Future<void>.delayed(Duration.zero);

      expect(state().errorMessage, AuthViewModel.socialFailedMessage('Google'));
    });
  });

  group('Facebook', () {
    test('succès : le jeton est envoyé au serveur', () async {
      await start();

      expect(await viewModel().loginWithFacebook(), isTrue);

      expect(auth.facebookTokens, ['facebook-access-token']);
      expect(state().status, AuthStatus.authenticated);
    });

    test('annulation : aucun message', () async {
      await start();
      facebook.next = null;

      expect(await viewModel().loginWithFacebook(), isFalse);

      expect(auth.facebookTokens, isEmpty);
      expect(state().errorMessage, isNull);
    });

    test('échec : message clair', () async {
      await start();
      facebook.error = const SocialSignInException('facebook', 'failed');

      expect(await viewModel().loginWithFacebook(), isFalse);

      expect(
        state().errorMessage,
        AuthViewModel.socialFailedMessage('Facebook'),
      );
    });
  });

  group('validation', () {
    test('email', () {
      expect(AuthViewModel.validateEmail(''), 'Veuillez saisir votre email.');
      expect(AuthViewModel.validateEmail('awa@'), isNotNull);
      expect(AuthViewModel.validateEmail('awa@example.com'), isNull);
    });

    test('mot de passe : 8 caractères minimum', () {
      expect(AuthViewModel.validatePassword('1234567'), isNotNull);
      expect(AuthViewModel.validatePassword('12345678'), isNull);
    });

    test('confirmation identique', () {
      expect(
        AuthViewModel.validateConfirmation('abcdefgh', 'abcdefgi'),
        isNotNull,
      );
      expect(
        AuthViewModel.validateConfirmation('abcdefgh', 'abcdefgh'),
        isNull,
      );
    });
  });

  group('redirections', () {
    test('à l’ouverture, toujours l’accueil, quel que soit l’état de la '
        'session', () {
      for (final status in AuthStatus.values) {
        expect(authRedirect(status, AppRoutes.home), isNull);
      }
    });

    test('utilisateur anonyme : accès à l’application et aux écrans de '
        'compte', () {
      expect(authRedirect(AuthStatus.anonymous, '/'), isNull);
      expect(authRedirect(AuthStatus.anonymous, AppRoutes.history), isNull);
      expect(authRedirect(AuthStatus.anonymous, AppRoutes.content), isNull);
      expect(authRedirect(AuthStatus.anonymous, AppRoutes.result), isNull);
      expect(authRedirect(AuthStatus.anonymous, AppRoutes.login), isNull);
      expect(authRedirect(AuthStatus.anonymous, AppRoutes.register), isNull);
    });

    test('jamais de redirection vers la connexion', () {
      for (final status in AuthStatus.values) {
        for (final location in ['/', AppRoutes.history, AppRoutes.content]) {
          expect(authRedirect(status, location), isNull);
        }
      }
    });

    test('connecté : /login → /', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.login), '/');
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.register), '/');
      expect(authRedirect(AuthStatus.authenticated, '/history'), isNull);
    });
  });
}
