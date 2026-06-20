import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_rule_model.dart';

abstract class CategoryRuleRemoteDataSource {
  Stream<List<CategoryRuleModel>> watchRules({required String userId});
  Future<void> addRule(CategoryRuleModel model);
  Future<void> updateRule(CategoryRuleModel model);
  Future<void> deleteRule({required String ruleId});
}

class CategoryRuleRemoteDataSourceImpl implements CategoryRuleRemoteDataSource {
  final FirebaseFirestore _db;

  CategoryRuleRemoteDataSourceImpl(this._db);

  CollectionReference get _col => _db.collection('category_rules');

  @override
  Stream<List<CategoryRuleModel>> watchRules({required String userId}) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CategoryRuleModel.fromFirestore).toList());
  }

  @override
  Future<void> addRule(CategoryRuleModel model) async {
    final data = model.toFirestore();
    if (model.id.isEmpty) {
      await _col.add(data);
    } else {
      await _col.doc(model.id).set(data);
    }
  }

  @override
  Future<void> updateRule(CategoryRuleModel model) async {
    await _col.doc(model.id).update(model.toFirestore());
  }

  @override
  Future<void> deleteRule({required String ruleId}) async {
    await _col.doc(ruleId).delete();
  }
}
