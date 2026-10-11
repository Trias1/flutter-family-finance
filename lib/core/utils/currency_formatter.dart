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

  /// Reads typed amounts. For decimal currencies a trailing ".50" or ",50"
  /// is the fraction ("10.50" is 10.5, not 1050).
  static double parse(String value) {
    final v = value.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (_currency.decimalDigits > 0) {
      final m = RegExp(r'[.,](\d{1,2})$').firstMatch(v);
      if (m != null) {
        final whole = v.substring(0, m.start).replaceAll(RegExp(r'[.,]'), '');
        return double.tryParse(
              '${whole.isEmpty ? '0' : whole}.${m.group(1)}',
            ) ??
            0;
      }
    }
    return double.tryParse(v.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
  }

  // Rupiah/Yen: 1.250.000. Decimal currencies: 1,250,000.50.
  static String _formatNumber(double amount) {
    final digits = _currency.decimalDigits;
    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(digits);
    final parts = fixed.split('.');
    final sep = digits > 0 ? ',' : '.';
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(sep);
      buffer.write(intPart[i]);
    }
    final grouped = digits > 0 ? '$buffer.${parts[1]}' : buffer.toString();
    return negative ? '-$grouped' : grouped;
  }
}
