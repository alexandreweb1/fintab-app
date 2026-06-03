import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class AddCategoryUseCase extends UseCase<CategoryEntity, AddCategoryParams> {
  final CategoryRepository repository;

  AddCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, CategoryEntity>> call(AddCategoryParams params) {
    return repository.addCategory(params.category);
  }
}

class AddCategoryParams extends Equatable {
  final CategoryEntity category;

  const AddCategoryParams({required this.category});

  @override
  List<Object> get props => [category];
}
