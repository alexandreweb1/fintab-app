import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../models/category_model.dart';
import '../../domain/entities/category_entity.dart';

abstract class CategoryRemoteDataSource {
  Stream<List<CategoryModel>> watchCategories(String userId);
  Future<CategoryModel> addCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String categoryId);
  Future<void> seedDefaults(String userId);
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final FirebaseFirestore _firestore;

  CategoryRemoteDataSourceImpl(this._firestore);

  CollectionReference get _collection =>
      _firestore.collection('categories');

  static const _kTimeout = Duration(seconds: 12);

  @override
  Stream<List<CategoryModel>> watchCategories(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<CategoryModel> addCategory(CategoryModel category) async {
    try {
      final docRef = await _collection
          .add(category.toFirestore())
          .timeout(_kTimeout, onTimeout: () => throw const ServerException(
              'Tempo limite excedido ao salvar categoria.'));
      final doc = await docRef.get().timeout(_kTimeout);
      return CategoryModel.fromFirestore(doc);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _collection
          .doc(category.id)
          .update(category.toFirestore())
          .timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _collection.doc(categoryId).delete().timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> seedDefaults(String userId) async {
    try {
      final batch = _firestore.batch();
      for (final category in _defaultCategories(userId)) {
        final docRef = _collection.doc(const Uuid().v4());
        batch.set(docRef, category.toFirestore());
      }
      await batch.commit().timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  List<CategoryModel> _defaultCategories(String userId) => [
        // Income
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Salário',
          type: CategoryType.income,
          iconCodePoint: 0xe8f8, // Icons.work
          colorValue: 0xFF1976D2, // Colors.blue.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Freelance',
          type: CategoryType.income,
          iconCodePoint: 0xe30a, // Icons.computer
          colorValue: 0xFF303F9F, // Colors.indigo.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Investimentos',
          type: CategoryType.income,
          iconCodePoint: 0xe8e5, // Icons.trending_up
          colorValue: 0xFF00796B, // Colors.teal.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Outros',
          type: CategoryType.income,
          iconCodePoint: 0xe574, // Icons.category
          colorValue: 0xFF616161, // Colors.grey.shade700
          isDefault: true,
        ),
        // Expense
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Alimentação',
          type: CategoryType.expense,
          iconCodePoint: 0xeb6e, // Icons.restaurant
          colorValue: 0xFFE64A19, // Colors.deepOrange.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Moradia',
          type: CategoryType.expense,
          iconCodePoint: 0xe88a, // Icons.home
          colorValue: 0xFF5D4037, // Colors.brown.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Transporte',
          type: CategoryType.expense,
          iconCodePoint: 0xe52f, // Icons.directions_car
          colorValue: 0xFF0288D1, // Colors.lightBlue.shade700
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Saúde',
          type: CategoryType.expense,
          iconCodePoint: 0xe548, // Icons.local_hospital
          colorValue: 0xFFC62828, // Colors.red.shade800
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Educação',
          type: CategoryType.expense,
          iconCodePoint: 0xe80c, // Icons.school
          colorValue: 0xFF6A1B9A, // Colors.purple.shade800
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Lazer',
          type: CategoryType.expense,
          iconCodePoint: 0xe021, // Icons.games
          colorValue: 0xFF558B2F, // Colors.lightGreen.shade800
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Vestuário',
          type: CategoryType.expense,
          iconCodePoint: 0xf19e, // Icons.checkroom
          colorValue: 0xFFAD1457, // Colors.pink.shade800
          isDefault: true,
        ),
        CategoryModel(
          id: '',
          userId: userId,
          name: 'Outros',
          type: CategoryType.expense,
          iconCodePoint: 0xe574, // Icons.category
          colorValue: 0xFF616161, // Colors.grey.shade700
          isDefault: true,
        ),
      ];
}
