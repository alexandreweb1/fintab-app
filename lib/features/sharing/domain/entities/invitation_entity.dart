class InvitationEntity {
  final String id;
  final String masterUserId;
  final String masterEmail;
  final String masterName;
  final String inviteeEmail;
  final String status; // 'pending' | 'accepted' | 'declined' | 'removed'
  final DateTime createdAt;
  // Populated when the invitee accepts — needed so the master can remove them.
  final String? collaboratorUserId;

  const InvitationEntity({
    required this.id,
    required this.masterUserId,
    required this.masterEmail,
    required this.masterName,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
    this.collaboratorUserId,
  });
}
