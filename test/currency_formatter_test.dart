import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';

void main() {
  group('CurrencyFormatter', () {
    setUp(() {
      CurrencyFormatter.setCurrency(CurrencyModel.supported.first);
    });

    test('format adds symbol and formats number', () {
      final result = CurrencyFormatter.format(1500000);
      expect(result, contains('Rp'));
      expect(result, contains('1.500.000'));
    });

    test('formatWithoutSymbol returns just the number', () {
      final result = CurrencyFormatter.formatWithoutSymbol(2500000);
      expect(result, '2.500.000');
    });

    test('format handles zero', () {
      final result = CurrencyFormatter.format(0);
      expect(result, 'Rp 0');
    });

    test('format handles decimal with IDR (no decimals)', () {
      final result = CurrencyFormatter.format(1000.50);
      expect(result, 'Rp 1.001');
    });

    test('format handles large numbers', () {
      final result = CurrencyFormatter.format(1000000000);
      expect(result, 'Rp 1.000.000.000');
    });

    test('parse extracts number from formatted string', () {
      final result = CurrencyFormatter.parse('Rp 500.000');
      expect(result, 500000);
    });

    test('parse handles empty string', () {
      final result = CurrencyFormatter.parse('');
      expect(result, 0);
    });

    test('parse handles non-numeric string', () {
      final result = CurrencyFormatter.parse('abc');
      expect(result, 0);
    });

    test('setCurrency changes the current currency', () {
      final usd = CurrencyModel.supported.firstWhere((c) => c.code == 'USD');
      CurrencyFormatter.setCurrency(usd);
      final result = CurrencyFormatter.format(100);
      expect(result, startsWith(r'$'));
    });

    test('format with USD uses decimal digits', () {
      final usd = CurrencyModel.supported.firstWhere((c) => c.code == 'USD');
      CurrencyFormatter.setCurrency(usd);
      final result = CurrencyFormatter.format(99.99);
      expect(result, r'$ 99.99');
    });

    test('format EUR uses decimal digits', () {
      final eur = CurrencyModel.supported.firstWhere((c) => c.code == 'EUR');
      CurrencyFormatter.setCurrency(eur);
      final result = CurrencyFormatter.format(42.50);
      expect(result, '€ 42.50');
    });

    test('currentCurrency returns the set currency', () {
      final jpy = CurrencyModel.supported.firstWhere((c) => c.code == 'JPY');
      CurrencyFormatter.setCurrency(jpy);
      expect(CurrencyFormatter.currentCurrency.code, 'JPY');
    });
  });
}
