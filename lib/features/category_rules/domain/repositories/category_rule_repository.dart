import '../entities/category_rule_entity.dart';

abstract class CategoryRuleRepository {
  Stream<List<CategoryRuleEntity>> watchRules({required String userId});
  Future<void> addRule(CategoryRuleEntity rule);
  Future<void> updateRule(CategoryRuleEntity rule);
  Future<void> deleteRule({required String ruleId});
}
