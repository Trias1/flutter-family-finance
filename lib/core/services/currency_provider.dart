import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/currency_service.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, AsyncValue<CurrencyModel>>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<AsyncValue<CurrencyModel>> {
  CurrencyNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final currency = await CurrencyService.getSelected();
    CurrencyFormatter.setCurrency(currency);
    state = AsyncValue.data(currency);
  }

  Future<void> setCurrency(CurrencyModel currency) async {
    await CurrencyService.setSelected(currency);
    CurrencyFormatter.setCurrency(currency);
    state = AsyncValue.data(currency);
  }
}
