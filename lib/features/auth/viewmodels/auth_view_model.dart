import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_token.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/validators.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

// `unknown` : session en cours de vérification au démarrage.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// Session de l'utilisateur : restauration au démarrage, connexion,
// inscription et déconnexion.
class AuthViewModel extends Notifier<AuthState> {
  static const String unavailableMessage =
      "La connexion n'est pas encore disponible.\n"
      'Réessayez dans quelques instants.';
  static const String sessionExpiredMessage =
      'Votre session a expiré. Veuillez vous reconnecter.';
  static const String restoreFailedMessage =
      'Impossible de vérifier votre session. '
      'Vérifiez votre connexion et reconnectez-vous.';
  static const String unexpectedMessage =
      'Une erreur est survenue. Veuillez réessayer.';

  static const int minPasswordLength = 8;

  // Règles de validation, partagées par les formulaires et le ViewModel.
  static String? validateEmail(String value) =>
      Validators.required(value, 'Veuillez saisir votre email.') ??
      Validators.email(value);

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Veuillez saisir votre mot de passe.';
    if (value.length < minPasswordLength) {
      return 'Le mot de passe doit contenir au moins '
          '$minPasswordLength caractères.';
    }
    return null;
  }

  static String? validateConfirmation(String password, String confirmation) =>
      password == confirmation
      ? null
      : 'Les mots de passe ne correspondent pas.';

  @override
  AuthState build() {
    // Le client HTTP efface le jeton quand le serveur refuse la session.
    ref.listen(sessionTokenProvider, (previous, next) {
      if (previous != null && next == null && state.isAuthenticated) {
        _signOut(errorMessage: sessionExpiredMessage);
      }
    });
    Future.microtask(_restoreSession);
    return const AuthState();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  // Au démarrage : le jeton enregistré n'est gardé que si le serveur le
  // reconnaît (`GET /auth/me`).
  Future<void> _restoreSession() async {
    final service = ref.read(authServiceProvider);
    String? token;
    try {
      token = await _storage.read();
    } catch (error, stackTrace) {
      _log('Lecture du jeton impossible', error, stackTrace);
    }
    if (token == null || service == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    ref.read(sessionTokenProvider.notifier).set(token);
    try {
      final user = await service.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (error) {
      final rejected =
          error.kind == ApiErrorKind.unauthorized ||
          error.kind == ApiErrorKind.forbidden;
      // Sans réponse du serveur, le jeton est gardé pour le prochain
      // lancement, mais la session n'est pas considérée comme valide.
      if (rejected) await _deleteToken();
      ref.read(sessionTokenProvider.notifier).clear();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: rejected ? null : restoreFailedMessage,
      );
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _submit((service) async {
      final token = await service.login(email: email, password: password);
      await _openSession(service, token);
    });
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _submit((service) async {
      await service.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      final token = await service.login(email: email, password: password);
      await _openSession(service, token);
    });
  }

  Future<void> logout() => _signOut();

  void clearError() {
    if (state.errorMessage == null) return;
    state = AuthState(status: state.status, user: state.user);
  }

  Future<void> _openSession(AuthService service, String token) async {
    ref.read(sessionTokenProvider.notifier).set(token);
    final user = await service.me();
    await _storage.write(token);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  // Exécute une action de connexion ; renvoie `true` si elle a réussi.
  Future<bool> _submit(Future<void> Function(AuthService) action) async {
    if (state.isSubmitting) return false;
    final service = ref.read(authServiceProvider);
    if (service == null) {
      state = AuthState(status: state.status, errorMessage: unavailableMessage);
      return false;
    }
    state = AuthState(status: state.status, isSubmitting: true);
    try {
      await action(service);
      return true;
    } catch (error, stackTrace) {
      ref.read(sessionTokenProvider.notifier).clear();
      if (error is! ApiException) {
        _log('Échec de la connexion', error, stackTrace);
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error is ApiException ? error.message : unexpectedMessage,
      );
      return false;
    }
  }

  // Déconnexion : jeton supprimé, session vidée ; le routeur revient alors
  // à `/login`.
  Future<void> _signOut({String? errorMessage}) async {
    ref.read(sessionTokenProvider.notifier).clear();
    state = AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: errorMessage,
    );
    await _deleteToken();
  }

  Future<void> _deleteToken() async {
    try {
      await _storage.delete();
    } catch (error, stackTrace) {
      _log('Suppression du jeton impossible', error, stackTrace);
    }
  }

  // Détails techniques réservés aux logs de développement (jamais le
  // mot de passe ni le jeton).
  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'AuthViewModel',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);
