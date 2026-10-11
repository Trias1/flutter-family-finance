import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/currency_service.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// The currency belongs to the data, not the phone: a family shares one
/// (stored on the family, changed by its owner), personal data uses the
/// user's own. The web reads the same field, so both show the same symbol.
final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, AsyncValue<CurrencyModel>>((ref) {
      final notifier = CurrencyNotifier(ref);
      ref.listen(
        financeScopeIdProvider,
        (_, _) => notifier.reload(),
        fireImmediately: true,
      );
      return notifier;
    });

class CurrencyNotifier extends StateNotifier<AsyncValue<CurrencyModel>> {
  final Ref _ref;

  CurrencyNotifier(this._ref) : super(const AsyncValue.loading());

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  ({String collection, String id})? _target() {
    final user = _ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return null;
    final fid = user.familyId;
    return fid != null && fid.isNotEmpty
        ? (collection: 'families', id: fid)
        : (collection: 'users', id: user.id);
  }

  Future<void> reload() async {
    // Last choice on this phone first, so nothing flashes in Rupiah.
    var currency = await CurrencyService.getSelected();
    final target = _target();
    if (target != null) {
      try {
        final snap = await _db
            .collection(target.collection)
            .doc(target.id)
            .get();
        final code = snap.data()?['currency'];
        if (code is String && code.isNotEmpty) {
          currency = CurrencyModel.fromCode(code);
          await CurrencyService.setSelected(currency);
        }
      } catch (_) {
        // Offline or not readable yet: keep the local choice.
      }
    }
    CurrencyFormatter.setCurrency(currency);
    if (mounted) state = AsyncValue.data(currency);
  }

  /// Returns an error message, or null on success.
  Future<String?> setCurrency(
    CurrencyModel currency, {
    required bool isId,
  }) async {
    final target = _target();
    if (target != null) {
      try {
        if (target.collection == 'families') {
          final family = await _db.collection('families').doc(target.id).get();
          final user = _ref.read(authNotifierProvider).valueOrNull;
          if (family.data()?['createdBy'] != user?.id) {
            return isId
                ? 'Mata uang keluarga hanya bisa diganti oleh pemilik keluarga.'
                : 'Only the family owner can change the family currency.';
          }
        }
        await _db.collection(target.collection).doc(target.id).update({
          'currency': currency.code,
        });
      } catch (_) {
        return isId
            ? 'Mata uang gagal disimpan. Coba lagi.'
            : "Couldn't save the currency. Try again.";
      }
    }
    await CurrencyService.setSelected(currency);
    CurrencyFormatter.setCurrency(currency);
    state = AsyncValue.data(currency);
    return null;
  }
}
