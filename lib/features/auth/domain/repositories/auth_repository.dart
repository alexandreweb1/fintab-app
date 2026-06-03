import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Returns null if the user cancelled the Google sign-in flow.
  Future<Either<Failure, UserEntity?>> signInWithGoogle();

  /// Returns null if the user cancelled the Apple sign-in flow.
  Future<Either<Failure, UserEntity?>> signInWithApple();

  Future<Either<Failure, void>> signOut();

  Stream<UserEntity?> get authStateChanges;

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Future<Either<Failure, void>> updateProfile({String? displayName});

  Future<Either<Failure, void>> updatePassword(
      String currentPassword, String newPassword);

  Future<Either<Failure, void>> linkEmailPassword(String password);

  Future<Either<Failure, void>> deleteAccount({String? password});
}
