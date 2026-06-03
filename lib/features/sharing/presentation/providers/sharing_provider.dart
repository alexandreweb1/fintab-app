import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/sharing_remote_datasource.dart';
import '../../data/repositories/sharing_repository_impl.dart';
import '../../domain/entities/invitation_entity.dart';
import '../../domain/repositories/sharing_repository.dart';

// ─── Infrastructure ───────────────────────────────────────────────────────────

final sharingDataSourceProvider = Provider<SharingRemoteDataSource>(
  (ref) => SharingRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => SharingRepositoryImpl(ref.watch(sharingDataSourceProvider)),
);

// ─── Pending invitations received by the current user ────────────────────────

final pendingInvitationsProvider =
    StreamProvider<List<InvitationEntity>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(sharingRepositoryProvider)
      .watchPendingInvitationsForEmail(user.email)
      .map((either) => either.getOrElse(() => []));
});

// ─── Collaborators accepted by the current user (master view) ────────────────

final myCollaboratorsProvider =
    StreamProvider<List<InvitationEntity>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(sharingRepositoryProvider)
      .watchCollaborators(user.id)
      .map((either) => either.getOrElse(() => []));
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SharingNotifier extends StateNotifier<AsyncValue<void>> {
  final SharingRepository _repo;
  final String _userId;
  final String _userEmail;
  final String _userName;

  SharingNotifier(this._repo, this._userId, this._userEmail, this._userName)
      : super(const AsyncValue.data(null));

  Future<String?> sendInvitation(String inviteeEmail) async {
    state = const AsyncValue.loading();
    final result = await _repo.sendInvitation(
      masterUserId: _userId,
      masterEmail: _userEmail,
      masterName: _userName,
      inviteeEmail: inviteeEmail,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> acceptInvitation(InvitationEntity invitation) async {
    state = const AsyncValue.loading();
    final result = await _repo.acceptInvitation(
      invitationId: invitation.id,
      inviteeUserId: _userId,
      masterUserId: invitation.masterUserId,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> declineInvitation(String invitationId) async {
    state = const AsyncValue.loading();
    final result = await _repo.declineInvitation(invitationId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repo.removeCollaborator(
      invitationId: invitationId,
      collaboratorUserId: collaboratorUserId,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> leaveSharedAccount() async {
    state = const AsyncValue.loading();
    final result = await _repo.leaveSharedAccount(_userId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final sharingNotifierProvider =
    StateNotifierProvider<SharingNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(authStateProvider).value;
  return SharingNotifier(
    ref.watch(sharingRepositoryProvider),
    user?.id ?? '',
    user?.email ?? '',
    user?.displayName ?? '',
  );
});
