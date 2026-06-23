import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/user_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirestoreDataSource _dataSource;
  final FirebaseAuth _auth;

  ProfileNotifier(this._dataSource, this._auth) : super(const AsyncValue.data(null));

  Future<void> updateProfile(UserModel user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _dataSource.updateUser(user);
      return user;
    });
  }

  Future<void> changePassword(String newPassword) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _auth.currentUser?.updatePassword(newPassword);
      return null;
    });
  }
}

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserModel?>>((ref) {
  return ProfileNotifier(
    ref.watch(firestoreDataSourceProvider),
    FirebaseAuth.instance,
  );
});
