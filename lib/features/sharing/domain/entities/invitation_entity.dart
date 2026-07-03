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

  /// Workspace ("Carteira") this invitation grants access to. Null = legacy
  /// account-wide invitation (pre per-Carteira sharing).
  final String? workspaceId;

  /// Denormalized workspace name so the invitee can see WHAT is being shared
  /// before having read access to the workspace doc.
  final String? workspaceName;

  /// 'editor' (full access) or 'viewer' (read-only). Null on legacy invites
  /// (which behave as editor).
  final String? role;

  const InvitationEntity({
    required this.id,
    required this.masterUserId,
    required this.masterEmail,
    required this.masterName,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
    this.collaboratorUserId,
    this.workspaceId,
    this.workspaceName,
    this.role,
  });

  bool get isWorkspaceInvite => workspaceId != null;
  bool get isViewer => role == 'viewer';
}
