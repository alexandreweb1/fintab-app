import '../../domain/entities/category_rule_entity.dart';
import '../../domain/repositories/category_rule_repository.dart';
import '../datasources/category_rule_remote_datasource.dart';
import '../models/category_rule_model.dart';

class CategoryRuleRepositoryImpl implements CategoryRuleRepository {
  final CategoryRuleRemoteDataSource _ds;

  CategoryRuleRepositoryImpl(this._ds);

  @override
  Stream<List<CategoryRuleEntity>> watchRules({required String userId}) =>
      _ds.watchRules(userId: userId);

  @override
  Future<void> addRule(CategoryRuleEntity rule) =>
      _ds.addRule(CategoryRuleModel.fromEntity(rule));

  @override
  Future<void> updateRule(CategoryRuleEntity rule) =>
      _ds.updateRule(CategoryRuleModel.fromEntity(rule));

  @override
  Future<void> deleteRule({required String ruleId}) =>
      _ds.deleteRule(ruleId: ruleId);
}
