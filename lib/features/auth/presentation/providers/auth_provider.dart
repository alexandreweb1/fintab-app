import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/usecases/usecase.dart';

// --- Infrastructure Providers ---

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

/// Shared Firestore instance used across all features.
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

// --- Use Case Providers ---

final signInUseCaseProvider = Provider(
  (ref) => SignInUseCase(ref.watch(authRepositoryProvider)),
);

final signUpUseCaseProvider = Provider(
  (ref) => SignUpUseCase(ref.watch(authRepositoryProvider)),
);

final signOutUseCaseProvider = Provider(
  (ref) => SignOutUseCase(ref.watch(authRepositoryProvider)),
);

// --- State Providers ---

final authStateProvider = StreamProvider<UserEntity?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// Reactive provider: true when the current Firebase user has an email+password
// credential linked (vs Google-only). Re-evaluates whenever auth state changes.
final hasPasswordProviderProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider); // rebuild when auth changes
  final user = ref.watch(firebaseAuthProvider).currentUser;
  return user?.providerData.any((p) => p.providerId == 'password') ?? false;
});

// --- Auth Notifier ---

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserEntity? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserEntity? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SignInUseCase _signIn;
  final SignUpUseCase _signUp;
  final SignOutUseCase _signOut;
  final AuthRepository _authRepository;

  AuthNotifier(this._signIn, this._signUp, this._signOut, this._authRepository)
      : super(const AuthState());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result =
        await _signIn(SignInParams(email: email, password: password));
    result.fold(
      (failure) => state = AuthState(errorMessage: failure.message),
      (user) {
        state = AuthState(user: user);
        AnalyticsService.instance.logLogin('email');
      },
    );
  }

  Future<void> signUp(String email, String password, String? name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _signUp(
      SignUpParams(email: email, password: password, displayName: name),
    );
    result.fold(
      (failure) => state = AuthState(errorMessage: failure.message),
      (user) {
        state = AuthState(user: user);
        AnalyticsService.instance.logSignUp('email');
      },
    );
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (failure) => state = AuthState(errorMessage: failure.message),
      (user) {
        // null means user cancelled — just reset loading, no error
        if (user == null) {
          state = const AuthState();
        } else {
          state = AuthState(user: user);
          AnalyticsService.instance.logLogin('google');
        }
      },
    );
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authRepository.signInWithApple();
    result.fold(
      (failure) => state = AuthState(errorMessage: failure.message),
      (user) {
        if (user == null) {
          state = const AuthState();
        } else {
          state = AuthState(user: user);
          AnalyticsService.instance.logLogin('apple');
        }
      },
    );
  }

  Future<void> signOut() async {
    // Unregister this device's push token while still authenticated.
    await PushNotificationService.instance.removeToken();
    await _signOut(const NoParams());
    state = const AuthState();
  }

  Future<bool> deleteAccount({String? password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await PushNotificationService.instance.removeToken();
    final result = await _authRepository.deleteAccount(password: password);
    return result.fold(
      (failure) {
        state = AuthState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const AuthState();
        return true;
      },
    );
  }

  Future<bool> updateProfile({String? displayName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result =
        await _authRepository.updateProfile(displayName: displayName);
    return result.fold(
      (failure) {
        state = AuthState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const AuthState();
        return true;
      },
    );
  }

  Future<bool> updatePassword(
      String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result =
        await _authRepository.updatePassword(currentPassword, newPassword);
    return result.fold(
      (failure) {
        state = AuthState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const AuthState();
        return true;
      },
    );
  }

  Future<bool> linkEmailPassword(String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _authRepository.linkEmailPassword(password);
    return result.fold(
      (failure) {
        state = AuthState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const AuthState();
        return true;
      },
    );
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.watch(signInUseCaseProvider),
    ref.watch(signUpUseCaseProvider),
    ref.watch(signOutUseCaseProvider),
    ref.watch(authRepositoryProvider),
  ),
);
