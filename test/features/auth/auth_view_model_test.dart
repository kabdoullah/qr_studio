import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_studio/app/router/app_router.dart';
import 'package:qr_studio/core/network/api_client.dart';
import 'package:qr_studio/core/network/session_token.dart';
import 'package:qr_studio/core/storage/token_storage.dart';
import 'package:qr_studio/features/auth/services/auth_service.dart';
import 'package:qr_studio/features/auth/viewmodels/auth_view_model.dart';

import '../../helpers/fake_services.dart';

void main() {
  late FakeAuthService auth;
  late FakeTokenStorage storage;
  late ProviderContainer container;

  Future<void> start({String? token}) async {
    storage = FakeTokenStorage(token);
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authServiceProvider.overrideWithValue(auth),
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
    });

    test('jeton reconnu par le serveur : session ouverte', () async {
      await start(token: 'jeton');

      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.firstName, 'Awa');
      expect(container.read(sessionTokenProvider), 'jeton');
    });

    test('jeton refusé (401) : supprimé', () async {
      auth.meError = const ApiException(ApiErrorKind.unauthorized);

      await start(token: 'expiré');

      expect(state().status, AuthStatus.unauthenticated);
      expect(storage.token, isNull);
      expect(container.read(sessionTokenProvider), isNull);
    });

    test('serveur injoignable : pas de session, jeton gardé', () async {
      auth.meError = const ApiException(ApiErrorKind.offline);

      await start(token: 'jeton');

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().errorMessage, AuthViewModel.restoreFailedMessage);
      expect(storage.token, 'jeton');
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
      expect(storage.token, 'token-1');
      expect(container.read(sessionTokenProvider), 'token-1');
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
      expect(storage.token, isNull);
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
      storage = FakeTokenStorage();
      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          authServiceProvider.overrideWithValue(null),
        ],
      );
      container.listen(authViewModelProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await viewModel().login(email: 'a@b.co', password: 'motdepasse');

      expect(state().errorMessage, AuthViewModel.unavailableMessage);
    });
  });

  test('inscription : crée le compte puis connecte', () async {
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
    expect(storage.token, isNotNull);
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

  test('déconnexion : jeton supprimé et session vidée', () async {
    await start(token: 'jeton');

    await viewModel().logout();

    expect(state().status, AuthStatus.unauthenticated);
    expect(state().user, isNull);
    expect(storage.token, isNull);
    expect(container.read(sessionTokenProvider), isNull);
  });

  test('401 pendant la session : déconnexion avec message', () async {
    await start(token: 'jeton');

    // Ce que fait `ApiClient` quand le serveur refuse le jeton.
    container.read(sessionTokenProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);

    expect(state().status, AuthStatus.unauthenticated);
    expect(state().errorMessage, AuthViewModel.sessionExpiredMessage);
    expect(storage.token, isNull);
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
