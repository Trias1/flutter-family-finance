import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/category_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final categoryStreamProvider = StreamProvider.family<List<CategoryModel>, String>((ref, familyId) {
  // No scope yet (profile still loading): skip a query the rules would deny.
  if (familyId.isEmpty) return Stream.value(const <CategoryModel>[]);
  return ref.watch(firestoreDataSourceProvider).streamCategories(familyId).map(
    (snapshot) => snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList(),
  );
});

final effectiveIncomeCategoriesProvider = Provider.family<List<String>, String>((ref, familyId) {
  final categories = ref.watch(categoryStreamProvider(familyId)).valueOrNull ?? [];
  final custom = categories.where((c) => c.type == 'income').map((c) => c.name).toSet();
  final merged = {...AppConstants.incomeCategories.toSet(), ...custom}.toList();
  return merged;
});

final effectiveExpenseCategoriesProvider = Provider.family<List<String>, String>((ref, familyId) {
  final categories = ref.watch(categoryStreamProvider(familyId)).valueOrNull ?? [];
  final custom = categories.where((c) => c.type == 'expense').map((c) => c.name).toSet();
  final merged = {...AppConstants.expenseCategories.toSet(), ...custom}.toList();
  return merged;
});

class CategoryNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreDataSource _dataSource;

  CategoryNotifier(this._dataSource) : super(const AsyncValue.data(null));

  Future<String?> addCategory(String familyId, String type, String name, List<String> existingNames) async {
    if (existingNames.any((n) => n.toLowerCase() == name.toLowerCase())) {
      state = AsyncValue.data(null);
      return 'Kategori "$name" sudah ada';
    }
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _dataSource.createCategory(
      CategoryModel(id: '', familyId: familyId, type: type, name: name),
    ));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<void> updateCategory(CategoryModel category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _dataSource.updateCategory(category));
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _dataSource.deleteCategory(id));
  }
}

final categoryNotifierProvider = StateNotifierProvider<CategoryNotifier, AsyncValue<void>>((ref) {
  return CategoryNotifier(ref.watch(firestoreDataSourceProvider));
});
