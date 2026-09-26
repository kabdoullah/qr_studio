import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/router/app_router.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
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
  late ProviderContainer container;

  Future<void> start({String? token, bool googleButton = false}) async {
    storage = FakeTokenStorage(token);
    google = FakeGoogleAuthService(usesGoogleButton: googleButton);
    facebook = FakeFacebookAuthService();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
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
    test('sans jeton : connexion requise', () async {
      await start();

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().errorMessage, isNull);
      expect(auth.refreshed, isEmpty);
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

    test('jeton expiré ou révoqué (401) : supprimé', () async {
      auth.refreshError = const ApiException(ApiErrorKind.unauthorized);

      await start(token: 'expiré');

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().errorMessage, isNull);
      expect(storage.tokens, isNull);
      expect(container.read(sessionTokenProvider), isNull);
    });

    test('compte désactivé (403) : jeton supprimé', () async {
      auth.refreshError = const ApiException(ApiErrorKind.forbidden);

      await start(token: 'refresh');

      expect(state().status, AuthStatus.unauthenticated);
      expect(storage.tokens, isNull);
    });

    test('serveur injoignable : pas de session, jeton gardé', () async {
      auth.refreshError = const ApiException(ApiErrorKind.offline);

      await start(token: 'refresh');

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().errorMessage, AuthViewModel.restoreFailedMessage);
      expect(storage.refreshToken, 'refresh');
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
      expect(storage.refreshToken, 'refresh-1');
      expect(container.read(sessionTokenProvider)?.accessToken, 'access-1');
    });

    test('échec : message du serveur, rien enregistré', () async {
      await start();

      final ok = await viewModel().login(
        email: 'awa@example.com',
        password: 'mauvais',
      );

      expect(ok, isFalse);
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().errorMessage, 'Email ou mot de passe incorrect.');
      expect(storage.tokens, isNull);
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

  test('inscription : le compte créé est connecté', () async {
    await start();

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
    expect(auth.logins, 0);
    expect(storage.refreshToken, 'refresh-1');
  });

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

    expect(state().status, AuthStatus.unauthenticated);
    expect(
      state().errorMessage,
      'Un compte existe déjà avec cette adresse email.',
    );
  });

  test('déconnexion : session serveur terminée, jetons supprimés, SDK '
      'déconnectés', () async {
    await start(token: 'refresh');

    await viewModel().logout();

    expect(state().status, AuthStatus.unauthenticated);
    expect(state().errorMessage, isNull);
    expect(state().user, isNull);
    expect(auth.loggedOut, ['refresh-1']);
    expect(storage.tokens, isNull);
    expect(container.read(sessionTokenProvider), isNull);
    expect(google.signOuts, 1);
    expect(facebook.signOuts, 1);
  });

  test('session refusée pendant l’usage : déconnexion avec message', () async {
    await start(token: 'refresh');

    // Ce que fait `ApiClient` quand le renouvellement est refusé.
    container.read(sessionTokenProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);

    expect(state().status, AuthStatus.unauthenticated);
    expect(state().errorMessage, AuthViewModel.sessionExpiredMessage);
    expect(storage.tokens, isNull);
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
      expect(storage.refreshToken, 'refresh-1');
    });

    test('annulation : aucun message, aucun appel', () async {
      await start();
      google.next = null;

      expect(await viewModel().loginWithGoogle(), isFalse);

      expect(auth.googleTokens, isEmpty);
      expect(state().status, AuthStatus.unauthenticated);
      expect(state().isSubmitting, isFalse);
      expect(state().errorMessage, isNull);
    });

    test('échec du SDK : message clair', () async {
      await start();
      google.error = const SocialSignInException('google', 'réseau');

      expect(await viewModel().loginWithGoogle(), isFalse);

      expect(state().errorMessage, AuthViewModel.socialFailedMessage('Google'));
      expect(storage.tokens, isNull);
    });

    test('compte existant non lié : message du serveur', () async {
      await start();
      auth.socialError = const ApiException(
        ApiErrorKind.conflict,
        serverMessage: 'Un compte existe déjà avec cette adresse.',
      );

      await viewModel().loginWithGoogle();

      expect(state().errorMessage, 'Un compte existe déjà avec cette adresse.');
      expect(state().status, AuthStatus.unauthenticated);
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
    test('session en cours de vérification : écran de chargement', () {
      expect(authRedirect(AuthStatus.unknown, '/'), AppRoutes.splash);
      expect(authRedirect(AuthStatus.unknown, AppRoutes.splash), isNull);
    });

    test('non connecté : / → /login, sans boucle', () {
      expect(authRedirect(AuthStatus.unauthenticated, '/'), AppRoutes.login);
      expect(
        authRedirect(AuthStatus.unauthenticated, '/history'),
        AppRoutes.login,
      );
      expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.login), isNull);
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.register),
        isNull,
      );
    });

    test('connecté : /login → /', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.login), '/');
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.register), '/');
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.splash), '/');
      expect(authRedirect(AuthStatus.authenticated, '/history'), isNull);
    });
  });
}
