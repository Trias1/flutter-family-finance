class CurrencyModel {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  const CurrencyModel({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalDigits = 0,
  });

  static const List<CurrencyModel> supported = [
    CurrencyModel(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
    CurrencyModel(code: 'USD', symbol: '\$', name: 'US Dollar', decimalDigits: 2),
    CurrencyModel(code: 'EUR', symbol: '€', name: 'Euro', decimalDigits: 2),
    CurrencyModel(code: 'GBP', symbol: '£', name: 'British Pound', decimalDigits: 2),
    CurrencyModel(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    CurrencyModel(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', decimalDigits: 2),
    CurrencyModel(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', decimalDigits: 2),
    CurrencyModel(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal', decimalDigits: 2),
  ];

  static final _default = supported.first;

  static CurrencyModel fromCode(String code) =>
      supported.firstWhere((c) => c.code == code, orElse: () => _default);
}
