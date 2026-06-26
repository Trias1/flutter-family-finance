import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';

class CurrencyService {
  static const _key = 'selected_currency_code';

  static Future<CurrencyModel> getSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null) return CurrencyModel.supported.first;
    return CurrencyModel.fromCode(code);
  }

  static Future<void> setSelected(CurrencyModel currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, currency.code);
  }
}
