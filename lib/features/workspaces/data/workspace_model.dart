import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/workspace_entity.dart';

class WorkspaceModel extends WorkspaceEntity {
  const WorkspaceModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.type,
    required super.memberUids,
    required super.roles,
    super.isDefault,
    super.archived,
    super.order,
    required super.createdAt,
  });

  factory WorkspaceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawRoles = (d['roles'] as Map<String, dynamic>?) ?? {};
    return WorkspaceModel(
      id: doc.id,
      ownerId: (d['ownerId'] as String?) ?? '',
      name: (d['name'] as String?) ?? '',
      type: WorkspaceType.fromId(d['type'] as String?),
      memberUids:
          ((d['memberUids'] as List?) ?? const []).whereType<String>().toList(),
      roles: rawRoles.map(
          (uid, role) => MapEntry(uid, WorkspaceRole.fromId(role as String?))),
      isDefault: (d['isDefault'] as bool?) ?? false,
      archived: (d['archived'] as bool?) ?? false,
      order: (d['order'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'name': name,
        'type': type.id,
        'memberUids': memberUids,
        'roles': roles.map((uid, role) => MapEntry(uid, role.id)),
        'isDefault': isDefault,
        'archived': archived,
        'order': order,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
