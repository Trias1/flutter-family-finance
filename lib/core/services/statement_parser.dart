import 'package:family_finance_manager/core/services/receipt_parser.dart';

/// One row of a bank statement / transaction history screenshot.
class StatementItem {
  final DateTime? date;
  final double amount;
  final bool isIncome;
  final String description;
  final String? categoryHint;

  const StatementItem({
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.description,
    this.categoryHint,
  });
}

/// Reads a list of transactions (mutasi rekening, cash flow, e-wallet
/// history) from OCR text, one row per screen row. Dates come from headings
/// like "15 Sep 2026"; amounts from the right end of a row ("+232.000,00",
/// "35.000,00", "IDR 260,000.00 CR"); a "+", "CR" or words like "masuk",
/// "refund" mark money in. Pure Dart, unit tested; the user reviews every
/// row before anything is saved.
class StatementParser {
  static final _dateHeading = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]{3,})\.?\s+(\d{4})$',
  );
  static final _amountAtEnd = RegExp(
    r'([+\-−]?)\s*(?:rp\.?|idr)?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+[.,]\d{2})\s*(cr|db|kredit|debit)?\s*$',
    caseSensitive: false,
  );
  static final _shortDate = RegExp(r'^(\d{1,2})/(\d{1,2})\b');

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'mei': 5,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'agu': 8,
    'agt': 8,
    'aug': 8,
    'sep': 9,
    'okt': 10,
    'oct': 10,
    'nov': 11,
    'des': 12,
    'dec': 12,
  };

  static const _incomeWords = [
    'masuk',
    'refund',
    'cashback',
    'kredit',
    'bunga',
    'interest',
    'gaji',
    'payroll',
    'salary',
    'terima',
    'received',
    'incoming',
    'setor',
  ];

  static const _skipWords = ['saldo', 'balance', 'limit', 'total'];

  /// Returns the rows found; fewer than two means it is not a list (use the
  /// single-receipt reader instead).
  static List<StatementItem> parse(String raw, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final rows = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final hasHeadings = rows.any((r) => _dateHeading.hasMatch(r));

    // A shop receipt also has many rows ending in prices; those are items of
    // one purchase, not separate transactions. A statement shows dates
    // (headings or "01/10" rows) or signed / CR amounts.
    final lowerAll = raw.toLowerCase();
    final looksLikeReceipt = RegExp(
      r'\b(kembali|kembalian|tunai|harga jual|total belanja|subtotal|kasir|struk)\b',
    ).hasMatch(lowerAll);
    final hasRowDates = rows.any((r) => _shortDate.hasMatch(r));
    final hasSigned = rows.any(
      (r) =>
          RegExp(r'(^|\s)[+]\s*\d').hasMatch(r) ||
          RegExp(r'\b(cr|db)\s*$', caseSensitive: false).hasMatch(r),
    );
    if (looksLikeReceipt || !(hasHeadings || hasRowDates || hasSigned)) {
      return const [];
    }

    final items = <_Draft>[];
    DateTime? current;
    var started = !hasHeadings;
    for (final row in rows) {
      final heading = _dateHeading.firstMatch(row);
      if (heading != null) {
        current = _date(heading, today) ?? current;
        started = true;
        continue;
      }
      if (!started) continue; // header area: account name, balance, clock
      final lower = row.toLowerCase();
      final m = _amountAtEnd.firstMatch(row);
      final isSkip = _skipWords.any(lower.contains);
      if (m != null && !isSkip) {
        final amount = _amount(m.group(2)!);
        if (amount == null || amount <= 0) continue;
        var text = row.substring(0, m.start).trim();
        DateTime? rowDate = current;
        final short = _shortDate.firstMatch(text);
        if (short != null) {
          rowDate = _shortToDate(short, current ?? today, today) ?? rowDate;
          text = text.substring(short.end).trim();
        }
        items.add(
          _Draft(
            date: rowDate,
            amount: amount,
            sign: m.group(1) ?? '',
            suffix: (m.group(3) ?? '').toLowerCase(),
            text: text,
          ),
        );
      } else if (items.isNotEmpty && !isSkip) {
        // A wrapped description continues on the next row.
        items.last.text = '${items.last.text} $row'.trim();
      }
    }

    return [
      for (final d in items)
        StatementItem(
          date: d.date,
          amount: d.amount,
          isIncome: _isIncome(d),
          description: _clean(d.text),
          categoryHint: _hint(d),
        ),
    ];
  }

  static bool _isIncome(_Draft d) {
    if (d.sign == '+') return true;
    if (d.sign == '-' || d.sign == '−') return false;
    if (d.suffix == 'cr' || d.suffix == 'kredit') return true;
    if (d.suffix == 'db' || d.suffix == 'debit') return false;
    final lower = d.text.toLowerCase();
    if (lower.contains('keluar') ||
        lower.contains(' dr ') ||
        lower.contains('debit')) {
      return false;
    }
    return _incomeWords.any(lower.contains);
  }

  static String? _hint(_Draft d) {
    final lower = d.text.toLowerCase();
    if (RegExp(r'\b(gaji|payroll|salary)\b').hasMatch(lower)) return 'salary';
    if (lower.contains('refund') || lower.contains('cashback')) return 'refund';
    final draft = ReceiptParser.parse(d.text);
    if (draft.kind == ReceiptKind.store) return 'groceries';
    if (RegExp(
      r'\b(warung|resto|restaurant|restoran|cafe|kafe|coffee|kopi|chicken|ayam|bakso|mie|sate|food|kfc|mcd|mcdonald|burger|pizza|geprek|nasi|bakery|roti)\b',
    ).hasMatch(lower)) {
      return 'food';
    }
    if (lower.contains('transfer'))
      return _isIncome(d) ? 'transfer_in' : 'transfer';
    return null;
  }

  /// "Pos Sales DebitBerita : 5451 SUPERINDO" -> "Pos Sales Debit · 5451 SUPERINDO".
  static String _clean(String text) {
    var t = text.replaceAll(
      RegExp(r'\s*berita\s*:\s*', caseSensitive: false),
      ' · ',
    );
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'(\s*·\s*)+$'), '');
    if (t.endsWith('/-')) t = t.substring(0, t.length - 2).trim();
    return t.length > 120 ? '${t.substring(0, 117)}...' : t;
  }

  static double? _amount(String s) {
    // The decimal separator is the last "." or "," followed by 1-2 digits.
    final m = RegExp(r'^(.*?)[.,](\d{1,2})$').firstMatch(s);
    final whole = (m?.group(1) ?? s).replaceAll(RegExp(r'[.,]'), '');
    final cents = m?.group(2);
    return double.tryParse(cents == null ? whole : '$whole.$cents');
  }

  static DateTime? _date(RegExpMatch m, DateTime today) {
    final month = _months[m.group(2)!.substring(0, 3).toLowerCase()];
    if (month == null) return null;
    final d = DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
    return d.month == month ? d : null;
  }

  static DateTime? _shortToDate(
    RegExpMatch m,
    DateTime context,
    DateTime today,
  ) {
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    var d = DateTime(context.year, month, day);
    if (d.isAfter(today)) d = DateTime(context.year - 1, month, day);
    return d.month == month ? d : null;
  }
}

class _Draft {
  final DateTime? date;
  final double amount;
  final String sign;
  final String suffix;
  String text;

  _Draft({
    required this.date,
    required this.amount,
    required this.sign,
    required this.suffix,
    required this.text,
  });
}
