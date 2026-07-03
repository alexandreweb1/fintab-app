import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/invitation_entity.dart';

abstract class SharingRemoteDataSource {
  Future<void> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
    String? workspaceId,
    String? workspaceName,
    String role = 'editor',
  });

  Stream<List<InvitationEntity>> watchPendingInvitationsForEmail(String email);

  Stream<List<InvitationEntity>> watchCollaborators(String masterUserId);

  Future<void> acceptInvitation({
    required String invitationId,
    required String inviteeUserId,
    required String masterUserId,
    String? workspaceId,
  });

  Future<void> declineInvitation(String invitationId);

  Future<void> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
    String? workspaceId,
  });

  Future<void> leaveSharedAccount(String userId);

  /// New-style member removes themselves from a shared workspace (Cloud
  /// Function — members can't write the workspace doc).
  Future<void> leaveWorkspace(String workspaceId);
}

class SharingRemoteDataSourceImpl implements SharingRemoteDataSource {
  final FirebaseFirestore _firestore;

  SharingRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('invitations');

  InvitationEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InvitationEntity(
      id: doc.id,
      masterUserId: d['masterUserId'] as String,
      masterEmail: d['masterEmail'] as String,
      masterName: d['masterName'] as String? ?? '',
      inviteeEmail: d['inviteeEmail'] as String,
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collaboratorUserId: d['collaboratorUserId'] as String?,
      workspaceId: d['workspaceId'] as String?,
      workspaceName: d['workspaceName'] as String?,
      role: d['role'] as String?,
    );
  }

  @override
  Future<void> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
    String? workspaceId,
    String? workspaceName,
    String role = 'editor',
  }) async {
    final normalizedEmail = inviteeEmail.trim().toLowerCase();

    // Guard: prevent self-invite
    if (normalizedEmail == masterEmail.trim().toLowerCase()) {
      throw Exception('Você não pode se convidar.');
    }

    // Guard: no duplicate pending invite
    final existing = await _invitations
        .where('masterUserId', isEqualTo: masterUserId)
        .where('inviteeEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Já existe um convite pendente para este email.');
    }

    final id = const Uuid().v4();
    await _invitations.doc(id).set({
      'id': id,
      'masterUserId': masterUserId,
      'masterEmail': masterEmail,
      'masterName': masterName,
      'inviteeEmail': normalizedEmail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      // Workspace-scoped sharing (per-Carteira). Legacy account-wide invites
      // omit these fields entirely.
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (workspaceId != null) 'workspaceName': workspaceName ?? '',
      if (workspaceId != null) 'role': role,
    });
  }

  @override
  Stream<List<InvitationEntity>> watchPendingInvitationsForEmail(
      String email) {
    final normalizedEmail = email.trim().toLowerCase();
    return _invitations
        .where('inviteeEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<InvitationEntity>> watchCollaborators(String masterUserId) {
    return _invitations
        .where('masterUserId', isEqualTo: masterUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> acceptInvitation({
    required String invitationId,
    required String inviteeUserId,
    required String masterUserId,
    String? workspaceId,
  }) async {
    // Workspace-scoped invitation: membership is granted by the
    // acceptWorkspaceInvite Cloud Function (Admin SDK) — the ONLY authority
    // allowed to add an invitee to a workspace with the owner-assigned role.
    if (workspaceId != null) {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('acceptWorkspaceInvite')
          .call<Map<String, dynamic>>({'invitationId': invitationId});
      return;
    }

    // Legacy account-wide invitation.
    // Use a transaction instead of a WriteBatch on purpose. On iOS/Android,
    // offline persistence makes batch.commit() resolve from the LOCAL cache,
    // so a server-side rejection (e.g. a Firestore-rules denial when the
    // installed app predates a rules change) passes silently and is only
    // rolled back later — the user sees the button reappear with no error.
    // A transaction always commits on the backend and its Future reflects the
    // real outcome, so a rejection surfaces here as a thrown exception.
    await _firestore.runTransaction((tx) async {
      // Mark invitation as accepted and record the collaborator's uid.
      tx.update(_invitations.doc(invitationId), {
        'status': 'accepted',
        'collaboratorUserId': inviteeUserId,
      });

      // Set masterUserId on the collaborator's user profile. The security rules
      // only accept this write when masterInvitationId points at an accepted
      // invitation addressed to the caller (validated atomically in the commit).
      tx.set(
        _firestore.collection('users').doc(inviteeUserId),
        {
          'masterUserId': masterUserId,
          'masterInvitationId': invitationId,
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _invitations.doc(invitationId).update({'status': 'declined'});
  }

  @override
  Future<void> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
    String? workspaceId,
  }) async {
    // 1) Revoke workspace membership (owner may write their own workspace).
    if (workspaceId != null) {
      await _firestore.collection('workspaces').doc(workspaceId).update({
        'memberUids': FieldValue.arrayRemove([collaboratorUserId]),
        'roles.$collaboratorUserId': FieldValue.delete(),
      });
    }

    // 2) Mark the invitation as removed.
    await _invitations.doc(invitationId).update({'status': 'removed'});

    // 3) Clear the legacy account-wide link, if it exists. New-style members
    // have no masterUserId on their profile — the rules deny this write, so
    // tolerate the failure instead of aborting the whole revocation.
    try {
      await _firestore.collection('users').doc(collaboratorUserId).update({
        'masterUserId': FieldValue.delete(),
        'masterInvitationId': FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    }
  }

  @override
  Future<void> leaveWorkspace(String workspaceId) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('leaveWorkspace')
        .call<Map<String, dynamic>>({'workspaceId': workspaceId});
  }

  @override
  Future<void> leaveSharedAccount(String userId) async {
    // Clear masterUserId from the user's profile — this detaches them immediately.
    // The invitation document is left as 'accepted' on Firestore (harmless;
    // the master can see they left because their profile no longer has masterUserId).
    await _firestore.collection('users').doc(userId).update({
      'masterUserId': FieldValue.delete(),
      'masterInvitationId': FieldValue.delete(),
    });
  }
}
