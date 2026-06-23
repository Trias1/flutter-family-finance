import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/transfer_model.dart';
import 'package:family_finance_manager/data/models/wallet_model.dart';
import 'package:family_finance_manager/data/repositories/wallet_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final walletStreamProvider = StreamProvider.family<List<WalletModel>, String>((ref, familyId) {
  return ref.watch(walletRepositoryProvider).streamWallets(familyId).map((snapshot) {
    return snapshot.docs.map((doc) => WalletModel.fromFirestore(doc)).toList();
  });
});

final transferListProvider = FutureProvider.family<List<TransferModel>, String>((ref, familyId) {
  return ref.watch(walletRepositoryProvider).getTransfers(familyId);
});

class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  final WalletRepository _repository;

  WalletNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> createWallet(WalletModel wallet) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createWallet(wallet));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> updateWallet(WalletModel wallet) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateWallet(wallet));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> deleteWallet(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.deleteWallet(id));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> transfer(String fromWalletId, String toWalletId, double amount, double? fee, String? note, String familyId) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final from = await _repository.getWallet(fromWalletId);
      final to = await _repository.getWallet(toWalletId);
      if (from == null) throw Exception('Dompet asal tidak ditemukan');
      if (to == null) throw Exception('Dompet tujuan tidak ditemukan');
      if (from.balance < amount + (fee ?? 0)) throw Exception('Saldo dompet asal tidak mencukupi');

      await _repository.updateWallet(WalletModel(
        id: from.id,
        familyId: from.familyId,
        name: from.name,
        type: from.type,
        balance: from.balance - amount - (fee ?? 0),
        icon: from.icon,
        colorHex: from.colorHex,
        createdAt: from.createdAt,
      ));
      await _repository.updateWallet(WalletModel(
        id: to.id,
        familyId: to.familyId,
        name: to.name,
        type: to.type,
        balance: to.balance + amount,
        icon: to.icon,
        colorHex: to.colorHex,
        createdAt: to.createdAt,
      ));
      await _repository.createTransfer(TransferModel(
        id: '',
        familyId: familyId,
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        amount: amount,
        fee: fee,
        note: note,
        date: DateTime.now(),
      ));
    });
    state = AsyncValue.data(null);
    return result.error?.toString();
  }
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, AsyncValue<void>>((ref) {
  return WalletNotifier(ref.watch(walletRepositoryProvider));
});
