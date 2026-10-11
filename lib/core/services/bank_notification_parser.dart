import 'package:family_finance_manager/core/services/statement_parser.dart';

/// One notification kept by the Android listener: only ones that mention an
/// amount, from apps other than chats.
class BankNotification {
  final String id;
  final String package;
  final String app;
  final String title;
  final String text;
  final DateTime time;

  const BankNotification({
    required this.id,
    required this.package,
    required this.app,
    required this.title,
    required this.text,
    required this.time,
  });

  factory BankNotification.fromJson(Map<String, dynamic> json) =>
      BankNotification(
        id: json['id'] as String? ?? '',
        package: json['package'] as String? ?? '',
        app: json['app'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(
          (json['time'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// Turns a bank or e-wallet notification ("Dana masuk Rp500.000 dari ...",
/// "Pembayaran QRIS Rp25.000 di ... berhasil") into a transaction to review.
/// Codes, promos, failed transfers and balance-only messages give null.
/// Pure Dart and unit tested; the user still checks every row before saving.
class BankNotificationParser {
  static final _amount = RegExp(
    r'(?:rp\.?|idr)\s?([0-9][0-9.,]*)',
    caseSensitive: false,
  );

  static final _skip = RegExp(
    r'\b(otp|kode verifikasi|verification code|jangan berikan|password|pin anda|'
    r'promo|diskon|discount|voucher|menangkan|undian|penawaran|dapatkan|'
    r'cashback hingga|jatuh tempo|akan didebet|gagal|failed|dibatalkan|ditolak)\b',
    caseSensitive: false,
  );

  static final _incoming = RegExp(
    r'\b(menerima|diterima|terima|masuk|bertambah|kredit|cr|received|'
    r'incoming|credited|refund|cashback|top ?up)\b',
    caseSensitive: false,
  );

  static final _outgoing = RegExp(
    r'\b(bayar|membayar|pembayaran|dibayar|transfer|kirim|mengirim|keluar|'
    r'berkurang|debit|db|tarik|penarikan|belanja|pembelian|purchase|payment|'
    r'paid|spent|qris)\b',
    caseSensitive: false,
  );

  static final _food = RegExp(
    r'\b(makan|resto|restoran|kopi|coffee|cafe|food|gofood|grabfood|'
    r'shopeefood|bakso|ayam|chicken|warung|mie|martabak)\b',
    caseSensitive: false,
  );

  static final _groceries = RegExp(
    r'\b(indomaret|alfamart|alfamidi|superindo|hypermart|transmart|lotte|'
    r'giant|hero|farmers)\b',
    caseSensitive: false,
  );

  static StatementItem? parse(BankNotification n) {
    final all = '${n.title}\n${n.text}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_skip.hasMatch(all)) return null;

    final amount = _transactionAmount(all);
    if (amount == null || amount <= 0) return null;

    final isIncome = _direction(all);
    if (isIncome == null) return null;

    final text = n.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final body = text.isEmpty ? n.title.trim() : text;
    final summary = body.length > 140 ? '${body.substring(0, 140)}…' : body;
    final app = n.app.trim().isEmpty ? n.package : n.app.trim();

    return StatementItem(
      date: n.time,
      amount: amount,
      isIncome: isIncome,
      description: '$app: $summary',
      categoryHint: _hint(all, isIncome),
    );
  }

  /// The first amount that is not the remaining balance ("Saldo Rp...").
  static double? _transactionAmount(String all) {
    for (final m in _amount.allMatches(all)) {
      final before = all
          .substring((m.start - 20).clamp(0, m.start), m.start)
          .toLowerCase();
      if (before.contains('saldo') || before.contains('balance')) continue;
      final value = amountOf(m[1]!);
      if (value != null) return value;
    }
    return null;
  }

  /// "500.000", "1.250.000,00", "260,000.00" -> a number. Two digits after
  /// the last separator are cents; other separators group thousands.
  static double? amountOf(String raw) {
    var s = raw.replaceAll(RegExp(r'[.,]+$'), '');
    var cents = 0.0;
    final dec = RegExp(r'[.,](\d{2})$').firstMatch(s);
    if (dec != null) {
      cents = int.parse(dec[1]!) / 100;
      s = s.substring(0, dec.start);
    }
    final digits = s.replaceAll(RegExp(r'[.,]'), '');
    final whole = int.tryParse(digits);
    return whole == null ? null : whole + cents;
  }

  /// true for money in, false for money out, null when it is not clear this
  /// is a transaction at all.
  static bool? _direction(String all) {
    final inMatch = _incoming.firstMatch(all);
    final outMatch = _outgoing.firstMatch(all);
    if (inMatch == null && outMatch == null) return null;
    if (outMatch == null) return true;
    if (inMatch == null) return false;
    final lower = all.toLowerCase();
    // "Transfer masuk ... dari X" vs "Transfer ... ke X".
    final from = RegExp(r'\bdari\b').hasMatch(lower);
    final to = RegExp(r'\b(ke|di)\b').hasMatch(lower);
    if (from && !to) return true;
    if (to && !from) return false;
    // "Transfer Masuk BI Fast": the money-in word is the specific one.
    return true;
  }

  static String? _hint(String all, bool isIncome) {
    final lower = all.toLowerCase();
    if (isIncome) {
      if (RegExp(r'\b(gaji|salary|payroll)\b').hasMatch(lower)) {
        return 'salary';
      }
      if (RegExp(r'\b(refund|cashback)\b').hasMatch(lower)) return 'refund';
      if (RegExp(r'\btop ?up\b').hasMatch(lower)) return 'topup';
      return 'transfer_in';
    }
    if (_groceries.hasMatch(lower)) return 'groceries';
    if (_food.hasMatch(lower)) return 'food';
    if (RegExp(r'\b(transfer|kirim)\b').hasMatch(lower) &&
        RegExp(r'\bke\b').hasMatch(lower)) {
      return 'transfer';
    }
    return null;
  }
}
