import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepositoryImpl(this.remoteDataSource);

  @override
  Stream<Either<Failure, List<CategoryEntity>>> watchCategories(String userId) {
    return remoteDataSource.watchCategories(userId).transform(
      StreamTransformer.fromHandlers(
        handleData: (models, sink) =>
            sink.add(Right(List<CategoryEntity>.from(models))),
        handleError: (error, _, sink) =>
            sink.add(Left(ServerFailure(error.toString()))),
      ),
    );
  }

  @override
  Future<Either<Failure, CategoryEntity>> addCategory(
      CategoryEntity category) async {
    try {
      final model = CategoryModel.fromEntity(category);
      final result = await remoteDataSource.addCategory(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateCategory(
      CategoryEntity category) async {
    try {
      final model = CategoryModel.fromEntity(category);
      await remoteDataSource.updateCategory(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String categoryId) async {
    try {
      await remoteDataSource.deleteCategory(categoryId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> seedDefaults(String userId) async {
    try {
      await remoteDataSource.seedDefaults(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
