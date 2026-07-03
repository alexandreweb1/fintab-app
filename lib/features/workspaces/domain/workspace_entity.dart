import 'package:equatable/equatable.dart';

/// The kind of ledger space a workspace ("Carteira") represents.
enum WorkspaceType {
  personal, // Pessoa Física
  business; // Pessoa Jurídica / empresa

  String get id => name;

  static WorkspaceType fromId(String? id) =>
      id == 'business' ? WorkspaceType.business : WorkspaceType.personal;
}

/// Role a member holds inside a workspace.
enum WorkspaceRole {
  editor, // full read/write
  viewer; // read-only

  String get id => name;

  static WorkspaceRole fromId(String? id) =>
      id == 'viewer' ? WorkspaceRole.viewer : WorkspaceRole.editor;
}

/// A "Carteira" — a self-contained ledger space (PF or PJ) owned by one user
/// and optionally shared with members (each with an editor/viewer role).
///
/// All ledger documents of a workspace carry `userId == ownerId` plus this
/// workspace's id in their `workspaceId` field.
class WorkspaceEntity extends Equatable {
  final String id;

  /// Uid of the owner. Ledger docs of this workspace are homed to this uid.
  final String ownerId;

  final String name;
  final WorkspaceType type;

  /// All member uids, ALWAYS including [ownerId] (uniform membership queries).
  final List<String> memberUids;

  /// Role per member uid. The owner is always an editor.
  final Map<String, WorkspaceRole> roles;

  final bool isDefault;
  final bool archived;
  final int order;
  final DateTime createdAt;

  const WorkspaceEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.memberUids,
    required this.roles,
    this.isDefault = false,
    this.archived = false,
    this.order = 0,
    required this.createdAt,
  });

  bool get isBusiness => type == WorkspaceType.business;

  WorkspaceRole roleOf(String uid) => roles[uid] ?? WorkspaceRole.viewer;

  bool isEditor(String uid) => roleOf(uid) == WorkspaceRole.editor;

  @override
  List<Object?> get props =>
      [id, ownerId, name, type, memberUids, roles, isDefault, archived, order];
}
