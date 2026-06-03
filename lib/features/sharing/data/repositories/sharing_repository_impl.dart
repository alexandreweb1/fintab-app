import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/invitation_entity.dart';
import '../../domain/repositories/sharing_repository.dart';
import '../datasources/sharing_remote_datasource.dart';

class SharingRepositoryImpl implements SharingRepository {
  final SharingRemoteDataSource _dataSource;

  SharingRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, void>> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
  }) async {
    try {
      await _dataSource.sendInvitation(
        masterUserId: masterUserId,
        masterEmail: masterEmail,
        masterName: masterName,
        inviteeEmail: inviteeEmail,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<InvitationEntity>>>
      watchPendingInvitationsForEmail(String email) {
    try {
      return _dataSource
          .watchPendingInvitationsForEmail(email)
          .map((list) => Right<Failure, List<InvitationEntity>>(list));
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, List<InvitationEntity>>> watchCollaborators(
      String masterUserId) {
    try {
      return _dataSource
          .watchCollaborators(masterUserId)
          .map((list) => Right<Failure, List<InvitationEntity>>(list));
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, void>> acceptInvitation({
    required String invitationId,
    required String inviteeUserId,
    required String masterUserId,
  }) async {
    try {
      await _dataSource.acceptInvitation(
        invitationId: invitationId,
        inviteeUserId: inviteeUserId,
        masterUserId: masterUserId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> declineInvitation(
      String invitationId) async {
    try {
      await _dataSource.declineInvitation(invitationId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
  }) async {
    try {
      await _dataSource.removeCollaborator(
        invitationId: invitationId,
        collaboratorUserId: collaboratorUserId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveSharedAccount(String userId) async {
    try {
      await _dataSource.leaveSharedAccount(userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
