import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class GetCategoriesUseCase {
  final CategoryRepository repository;

  GetCategoriesUseCase(this.repository);

  Stream<Either<Failure, List<CategoryEntity>>> call(
      GetCategoriesParams params) {
    return repository.watchCategories(params.userId);
  }
}

class GetCategoriesParams extends Equatable {
  final String userId;

  const GetCategoriesParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
