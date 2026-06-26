import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/wishlist_item_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final wishlistProvider = FutureProvider.family<List<WishlistItemModel>, String>((ref, familyId) async {
  final ds = ref.watch(firestoreDataSourceProvider);
  return ds.getWishlistItems(familyId);
});

class WishlistNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreDataSource _ds;

  WishlistNotifier(this._ds) : super(const AsyncValue.data(null));

  Future<void> addItem(WishlistItemModel item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _ds.setWishlistItem(item));
  }

  Future<void> updateItem(WishlistItemModel item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _ds.updateWishlistItem(item));
  }

  Future<void> deleteItem(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _ds.deleteWishlistItem(id));
  }
}

final wishlistNotifierProvider = StateNotifierProvider<WishlistNotifier, AsyncValue<void>>((ref) {
  return WishlistNotifier(ref.watch(firestoreDataSourceProvider));
});
