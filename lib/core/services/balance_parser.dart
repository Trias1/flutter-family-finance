import 'package:family_finance_manager/core/services/receipt_parser.dart';

/// A savings balance read from a bank app screenshot.
class BalanceReading {
  final double amount;

  /// Bank or e-wallet named on the screen, when there is one.
  final String? bank;
  const BalanceReading(this.amount, this.bank);
}

/// Reads the balance off a bank app's account screen ("Saldo Aktif
/// Rp3.000.000", "Tabungan Rp 3,000,000.00"). Screens that are a payment,
/// a transfer receipt or a shop receipt give null, so they keep going to the
/// transaction flows. Pure Dart and unit tested; the user confirms every
/// update.
class BalanceParser {
  static final _balanceLabel = RegExp(
    r'\b(saldo aktif|saldo efektif|saldo tersedia|total saldo|saldo|'
    r'available balance|total balance|balance|tabungan|total aset)\b',
    caseSensitive: false,
  );

  // Words of a single transaction rather than an account screen.
  static final _transaction = RegExp(
    r'\b(berhasil|sukses|successful|transfer ke|transfer berhasil|'
    r'pembayaran|bayar|payment|total belanja|kembali|kembalian|'
    r'no\.? ?ref|referensi|reference|struk|kasir)\b',
    caseSensitive: false,
  );

  static final _amount = RegExp(
    r'(?:rp\.?|idr)?\s?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{2})?|[0-9]{4,}(?:[.,][0-9]{2})?)',
    caseSensitive: false,
  );

  static BalanceReading? parse(String text) {
    if (text.trim().isEmpty || _transaction.hasMatch(text)) return null;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length; i++) {
      final label = _balanceLabel.firstMatch(lines[i]);
      if (label == null) continue;
      // The amount sits after the label on the same row, or just below it.
      final candidates = [
        lines[i].substring(label.end),
        if (i + 1 < lines.length) lines[i + 1],
        if (i + 2 < lines.length) lines[i + 2],
      ];
      for (final c in candidates) {
        final value = _firstAmount(c);
        if (value != null && value > 0) {
          return BalanceReading(value, ReceiptParser.bankIn(text));
        }
      }
    }
    return null;
  }

  static double? _firstAmount(String s) {
    for (final m in _amount.allMatches(s)) {
      final raw = m[1]!;
      // Years and account numbers are not balances: "2026", "1234567890".
      final grouped = RegExp(r'[.,]').hasMatch(raw);
      final hasCurrency = RegExp(
        r'(rp|idr)',
        caseSensitive: false,
      ).hasMatch(m[0]!);
      if (!grouped && !hasCurrency) continue;
      final value = amountOf(raw);
      if (value != null) return value;
    }
    return null;
  }

  /// "3.000.000", "3,000,000.00", "1.250.000,50" -> a number.
  static double? amountOf(String raw) {
    var s = raw.replaceAll(RegExp(r'[.,]+$'), '');
    var cents = 0.0;
    final dec = RegExp(r'[.,](\d{2})$').firstMatch(s);
    if (dec != null) {
      cents = int.parse(dec[1]!) / 100;
      s = s.substring(0, dec.start);
    }
    final whole = int.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
    return whole == null ? null : whole + cents;
  }
}
