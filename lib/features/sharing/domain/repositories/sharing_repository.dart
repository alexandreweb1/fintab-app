import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invitation_entity.dart';

abstract class SharingRepository {
  Future<Either<Failure, void>> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
  });

  Stream<Either<Failure, List<InvitationEntity>>> watchPendingInvitationsForEmail(
      String email);

  Stream<Either<Failure, List<InvitationEntity>>> watchCollaborators(
      String masterUserId);

  Future<Either<Failure, void>> acceptInvitation({
    required String invitationId,
    required String inviteeUserId,
    required String masterUserId,
  });

  Future<Either<Failure, void>> declineInvitation(String invitationId);

  Future<Either<Failure, void>> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
  });

  Future<Either<Failure, void>> leaveSharedAccount(String userId);
}
