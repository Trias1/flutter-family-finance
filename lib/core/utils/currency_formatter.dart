import 'package:family_finance_manager/data/models/currency_model.dart';

class CurrencyFormatter {
  static CurrencyModel _currency = CurrencyModel.supported.first;

  static CurrencyModel get currentCurrency => _currency;

  static void setCurrency(CurrencyModel currency) {
    _currency = currency;
  }

  static String format(double amount) {
    return '${_currency.symbol} ${_formatNumber(amount)}';
  }

  static String formatWithoutSymbol(double amount) {
    return _formatNumber(amount);
  }

  static double parse(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0;
  }

  static String _formatNumber(double amount) {
    if (_currency.decimalDigits > 0) {
      return amount.toStringAsFixed(_currency.decimalDigits);
    }
    String str = amount.toStringAsFixed(0);
    String reversed = str.split('').reversed.join('');
    final buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(reversed[i]);
    }
    return buffer.toString().split('').reversed.join('');
  }
}
