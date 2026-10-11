import 'package:family_finance_manager/core/services/receipt_parser.dart';

/// One balance on an account screen: "Tabungan Neo  Rp200.226".
class BalanceLine {
  final String label;
  final double amount;
  const BalanceLine(this.label, this.amount);
}

/// The balances read from a bank app screenshot. Most screens show one;
/// some (Bank Neo, Jago, Seabank) show a total and one per pocket.
class BalanceReading {
  final List<BalanceLine> lines;

  /// Bank or e-wallet named on the screen, when there is one.
  final String? bank;
  const BalanceReading(this.lines, this.bank);

  /// The first balance on the screen.
  double get amount => lines.first.amount;

  /// The pocket named in [goalName] ("Dana darurat Neo NOW" -> "Neo NOW"):
  /// every distinctive word of the pocket's label is in the goal's name; the
  /// most specific pocket wins ("Neo NOW" over "Tabungan Neo").
  BalanceLine? lineFor(String goalName) {
    final goal = _words(goalName);
    BalanceLine? best;
    var bestWords = 0;
    for (final line in lines) {
      final words = _words(line.label).difference(_generic);
      if (words.length > bestWords && goal.containsAll(words)) {
        best = line;
        bestWords = words.length;
      }
    }
    return best;
  }

  static const _generic = {
    'saldo',
    'total',
    'tabungan',
    'rekening',
    'balance',
    'aktif',
    'efektif',
    'tersedia',
    'available',
    'bank',
  };

  static Set<String> _words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toSet();
}

/// Reads the balances off a bank app's account screen ("Saldo Aktif
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

  // A label that says "balance" and nothing else; the pocket's name is then
  // the heading above it.
  static final _bareLabel = RegExp(
    r'^(saldo|saldo aktif|saldo efektif|saldo tersedia|balance|'
    r'available balance)\s*:?$',
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
    final found = <BalanceLine>[];
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
        if (value == null || value <= 0) continue;
        // "Tabungan Neo" and the "Saldo" under it read the same number.
        if (!found.any((f) => f.amount == value)) {
          found.add(BalanceLine(_nameFor(lines, i), value));
        }
        break;
      }
    }
    if (found.isEmpty) return null;
    return BalanceReading(found, ReceiptParser.bankIn(text));
  }

  /// "Tabungan Neo" for its own row; for a bare "Saldo", the heading above
  /// it ("Neo NOW"), else "Saldo".
  static String _nameFor(List<String> lines, int i) {
    final own = _withoutAmounts(lines[i]);
    if (!_bareLabel.hasMatch(own)) return own;
    for (var k = i - 1; k >= 0 && k >= i - 2; k--) {
      final heading = lines[k];
      if (RegExp(r'\d').hasMatch(heading) ||
          _bareLabel.hasMatch(heading) ||
          heading.length > 40) {
        continue;
      }
      return heading;
    }
    return own.replaceAll(RegExp(r'\s*:$'), '');
  }

  static String _withoutAmounts(String line) => line
      .replaceAll(_amount, '')
      .replaceAll(RegExp(r'\b(rp\.?|idr)\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
