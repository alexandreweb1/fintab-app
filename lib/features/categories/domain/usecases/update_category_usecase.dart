import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class UpdateCategoryUseCase extends UseCase<void, UpdateCategoryParams> {
  final CategoryRepository repository;

  UpdateCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateCategoryParams params) {
    return repository.updateCategory(params.category);
  }
}

class UpdateCategoryParams extends Equatable {
  final CategoryEntity category;

  const UpdateCategoryParams({required this.category});

  @override
  List<Object> get props => [category];
}
