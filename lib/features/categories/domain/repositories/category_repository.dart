import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/category_entity.dart';

abstract class CategoryRepository {
  Stream<Either<Failure, List<CategoryEntity>>> watchCategories(String userId);
  Future<Either<Failure, CategoryEntity>> addCategory(CategoryEntity category);
  Future<Either<Failure, void>> updateCategory(CategoryEntity category);
  Future<Either<Failure, void>> deleteCategory(String categoryId);
  Future<Either<Failure, void>> seedDefaults(String userId);
}
