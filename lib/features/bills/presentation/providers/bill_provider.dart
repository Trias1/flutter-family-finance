import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/data/repositories/bill_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final billStreamProvider = StreamProvider.family<List<BillModel>, String>((ref, familyId) {
  // No scope yet (profile still loading): skip a query the rules would deny.
  if (familyId.isEmpty) return Stream.value(const <BillModel>[]);
  return ref.watch(billRepositoryProvider).streamBills(familyId).map(
    (snapshot) {
      final list = snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    },
  );
});

final upcomingBillsProvider = Provider.family<List<BillModel>, String>((ref, familyId) {
  final bills = ref.watch(billStreamProvider(familyId));
  return bills.when(
    data: (list) {
      final upcoming = list
          .where((b) => b.status != BillStatus.paid)
          .toList();
      upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return upcoming.take(3).toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

class BillNotifier extends StateNotifier<AsyncValue<void>> {
  final BillRepository _repository;

  BillNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> createBill(BillModel bill) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createBill(bill));
    state = result;
    if (result.hasError) return result.error.toString();
    _scheduleNotification(bill);
    return null;
  }

  Future<String?> updateBill(BillModel bill) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateBill(bill));
    state = result;
    if (result.hasError) return result.error.toString();
    if (bill.status == BillStatus.paid && bill.paidDate != null) {
      NotificationService().cancel(bill.id.hashCode);
    }
    return null;
  }

  Future<String?> deleteBill(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.deleteBill(id));
    state = result;
    if (result.hasError) return result.error.toString();
    NotificationService().cancel(id.hashCode);
    return null;
  }

  void _scheduleNotification(BillModel bill) {
    if (bill.status == BillStatus.paid) return;
    final notif = NotificationService();
    final daysUntilDue = bill.dueDate.difference(DateTime.now()).inDays;
    if (daysUntilDue >= 0) {
      notif.show(
        id: bill.id.hashCode,
        title: 'Tagihan: ${bill.name}',
        body: 'Jatuh tempo ${daysUntilDue == 0 ? "hari ini" : "dalam $daysUntilDue hari"} — Rp ${bill.amount.toStringAsFixed(0)}',
      );
    }
  }
}

final billNotifierProvider = StateNotifierProvider<BillNotifier, AsyncValue<void>>((ref) {
  return BillNotifier(ref.watch(billRepositoryProvider));
});
