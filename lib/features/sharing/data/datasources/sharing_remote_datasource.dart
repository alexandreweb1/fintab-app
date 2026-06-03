import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/invitation_entity.dart';

abstract class SharingRemoteDataSource {
  Future<void> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
  });

  Stream<List<InvitationEntity>> watchPendingInvitationsForEmail(String email);

  Stream<List<InvitationEntity>> watchCollaborators(String masterUserId);

  Future<void> acceptInvitation({
    required String invitationId,
    required String inviteeUserId,
    required String masterUserId,
  });

  Future<void> declineInvitation(String invitationId);

  Future<void> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
  });

  Future<void> leaveSharedAccount(String userId);
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
    );
  }

  @override
  Future<void> sendInvitation({
    required String masterUserId,
    required String masterEmail,
    required String masterName,
    required String inviteeEmail,
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
  }) async {
    final batch = _firestore.batch();

    // Mark invitation as accepted and record the collaborator's uid
    batch.update(_invitations.doc(invitationId), {
      'status': 'accepted',
      'collaboratorUserId': inviteeUserId,
    });

    // Set masterUserId on the collaborator's user profile
    batch.set(
      _firestore.collection('users').doc(inviteeUserId),
      {'masterUserId': masterUserId},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _invitations.doc(invitationId).update({'status': 'declined'});
  }

  @override
  Future<void> removeCollaborator({
    required String invitationId,
    required String collaboratorUserId,
  }) async {
    final batch = _firestore.batch();

    // Mark invitation as removed
    batch.update(_invitations.doc(invitationId), {'status': 'removed'});

    // Clear masterUserId from collaborator's profile
    batch.update(
      _firestore.collection('users').doc(collaboratorUserId),
      {'masterUserId': FieldValue.delete()},
    );

    await batch.commit();
  }

  @override
  Future<void> leaveSharedAccount(String userId) async {
    // Clear masterUserId from the user's profile — this detaches them immediately.
    // The invitation document is left as 'accepted' on Firestore (harmless;
    // the master can see they left because their profile no longer has masterUserId).
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'masterUserId': FieldValue.delete()});
  }
}
