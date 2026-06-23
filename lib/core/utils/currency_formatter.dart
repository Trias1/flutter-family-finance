class CurrencyFormatter {
  static String format(double amount) {
    return 'Rp ${_formatNumber(amount)}';
  }

  static String formatWithoutSymbol(double amount) {
    return _formatNumber(amount);
  }

  static double parse(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0;
  }

  static String _formatNumber(double amount) {
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
