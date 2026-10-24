import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/currency_model.dart';

void main() {
  tearDown(() => CurrencyFormatter.setCurrency(CurrencyModel.fromCode('IDR')));

  test('rupiah keeps dot grouping and handles negatives', () {
    CurrencyFormatter.setCurrency(CurrencyModel.fromCode('IDR'));
    expect(CurrencyFormatter.format(-25000), 'Rp -25.000');
    expect(CurrencyFormatter.parse('Rp 1.250.000'), 1250000);
  });

  test('decimal currencies group thousands and keep cents', () {
    CurrencyFormatter.setCurrency(CurrencyModel.fromCode('USD'));
    expect(CurrencyFormatter.format(1250000.5), '\$ 1,250,000.50');
    expect(CurrencyFormatter.parse('10.50'), 10.5);
    expect(CurrencyFormatter.parse('10,5'), 10.5);
    expect(CurrencyFormatter.parse('1,250'), 1250);
  });
}
