/// Turns the text read from a shopping receipt or a payment screenshot
/// (QRIS, transfer) into a draft expense. Pure Dart, so it is unit tested;
/// the text itself comes from on-device OCR. The user always reviews the
/// result before saving.
enum ReceiptKind { store, qris, transfer, other }

class ReceiptDraft {
  final double? amount;
  final String? merchant;
  final String? paidWith;

  /// For transfers: who received the money and at which bank.
  final String? recipient;
  final String? recipientBank;
  final ReceiptKind kind;
  final bool isQris;
  final DateTime? date;
  final String? categoryHint;

  const ReceiptDraft({
    this.amount,
    this.merchant,
    this.paidWith,
    this.recipient,
    this.recipientBank,
    this.kind = ReceiptKind.other,
    this.isQris = false,
    this.date,
    this.categoryHint,
  });

  bool get isEmpty => amount == null && merchant == null && paidWith == null;

  /// e.g. "Indomaret · QRIS BCA", "Kopi Kenangan · GoPay" or
  /// "Transfer to ASTI NURHAYATI (blu by BCA Digital) · OCBC".
  String? noteFor({required bool isId}) {
    final via = paidWith == null
        ? (isQris ? 'QRIS' : null)
        : (isQris ? 'QRIS $paidWith' : paidWith);
    String? what = merchant;
    if (kind == ReceiptKind.transfer && recipient != null) {
      final bank = recipientBank == null ? '' : ' ($recipientBank)';
      what = '${isId ? 'Transfer ke' : 'Transfer to'} $recipient$bank';
    }
    final parts = [?what, ?via];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class ReceiptParser {
  // Name shown to the user -> words that identify it on a receipt/screenshot.
  // Order matters: more specific names first (e.g. "BCA Digital" before "BCA").
  static const _payers = <String, List<String>>{
    'blu by BCA Digital': [
      'blu by bca',
      'bank digital bca',
      'bca digital',
      'blubybcadigital',
    ],
    'BCA Syariah': ['bca syariah'],
    'BCA': [
      'bca mobile',
      'm-bca',
      'mybca',
      'klikbca',
      'bank central asia',
      'bca',
    ],
    'Mandiri': ["livin'", 'livin by mandiri', 'bank mandiri', 'mandiri'],
    'BRI': ['brimo', 'bank rakyat indonesia', 'bank bri', 'bri'],
    'BNI': ['bni mobile', 'wondr', 'bank negara indonesia', 'bni'],
    'BSI': ['bsi mobile', 'bank syariah indonesia', 'bsi'],
    'CIMB Niaga': ['octo mobile', 'octo', 'cimb niaga', 'cimb'],
    'Permata': ['permatamobile', 'permata'],
    'Danamon': ['d-bank', 'danamon'],
    'BTN': ['btn mobile', 'bale by btn', 'bank btn', 'btn'],
    'Bank Jago': ['bank jago', 'jago'],
    'SeaBank': ['seabank', 'sea bank'],
    'Jenius': ['jenius', 'btpn'],
    'OCBC': ['ocbc', 'nyala'],
    'Maybank': ['maybank', 'm2u'],
    'Allo Bank': ['allo bank', 'allo'],
    'superbank': ['superbank'],
    'Bank DKI': ['bank dki', 'jakone'],
    'BJB': ['bank bjb', 'bjb'],
    'Bank Neo': ['neo commerce', 'neobank', 'bank neo'],
    'Line Bank': ['line bank'],
    'Krom': ['krom'],
    'GoPay': ['gopay', 'gojek'],
    'OVO': ['ovo'],
    'DANA': ['dana'],
    'ShopeePay': ['shopeepay', 'shopee pay', 'spay'],
    'LinkAja': ['linkaja'],
    'i.saku': ['i.saku', 'isaku'],
    'Flip': ['flip'],
    'AstraPay': ['astrapay'],
  };

  static const _stores = <String, List<String>>{
    'Indomaret': ['indomaret', 'indomaret point', 'indogrosir'],
    'Alfamidi': ['alfamidi'],
    'Alfamart': ['alfamart', 'alfa express'],
    'Lawson': ['lawson'],
    'FamilyMart': ['familymart', 'family mart'],
    'Circle K': ['circle k'],
    'Superindo': ['superindo'],
    'Hypermart': ['hypermart'],
    'Transmart': ['transmart'],
    'Lotte Mart': ['lotte mart', 'lottemart', 'lotte grosir'],
    'Hero': ['hero supermarket'],
    'Yogya': ['yogya', 'griya'],
    'Ranch Market': ['ranch market', 'farmers market'],
    'Giant': ['giant'],
    'Foodmart': ['foodmart'],
    'Sakinah': ['sakinah'],
  };

  // Lines that hold the amount actually paid, strongest first.
  static const _totalKeys = [
    'total bayar',
    'total belanja',
    'total pembayaran',
    'total transaksi',
    'grand total',
    'jumlah bayar',
    'nominal transaksi',
    'nominal pembayaran',
    'jumlah pembayaran',
    'total amount',
    'amount',
    'nominal',
    'jumlah',
    'total',
    'non tunai',
  ];

  // Lines whose numbers are never the expense itself.
  static const _skipKeys = [
    'kembali',
    'kembalian',
    'change',
    'diskon',
    'discount',
    'hemat',
    'ppn',
    'dpp',
    'pajak',
    'tax',
    'biaya admin',
    'admin fee',
    'saldo',
    'balance',
    'poin',
    'point',
    'npwp',
    'telp',
    'no.',
    'ref',
    'tunai',
  ];

  static final _number = RegExp(
    r'(?<![\d])(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{2}))?(?![\d])',
  );

  static ReceiptDraft parse(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lower = raw.toLowerCase();

    final store = _findName(_stores, lower);
    final isQris =
        lower.contains('qris') ||
        lower.contains('qr code') ||
        lower.contains('scan qr');
    final isTransfer =
        !isQris &&
        RegExp(
          r'\b(transfer|bifast|bi-fast|bi fast|skn|rtgs|online transfer|kirim uang)\b',
        ).hasMatch(lower);

    // Every bank/e-wallet mention with its line. The app that made the
    // screenshot shows its name at the top (logo) or as the source of funds;
    // a bank under the recipient's name is where the money went.
    final mentions = <({int line, String name})>[];
    for (var i = 0; i < lines.length; i++) {
      final name = _findName(_payers, lines[i].toLowerCase());
      if (name != null) mentions.add((line: i, name: name));
    }
    String? payer;
    String? recipient;
    String? recipientBank;
    final sourceLabel = RegExp(
      r'(sumber dana|rekening sumber|dari rekening|from account|debit dari|paid with|bayar pakai|metode pembayaran)',
      caseSensitive: false,
    );
    for (final m in mentions) {
      final labelled =
          sourceLabel.hasMatch(lines[m.line]) ||
          (m.line > 0 && sourceLabel.hasMatch(lines[m.line - 1]));
      if (labelled || m.line <= 2) {
        payer ??= m.name;
      }
    }
    if (isTransfer) {
      for (final m in mentions) {
        if (m.name == payer && mentions.length > 1) continue;
        // A recipient's bank sits right under their (usually capitalised) name.
        final above = m.line > 0 ? lines[m.line - 1] : '';
        if (_looksLikeName(above)) {
          recipient = above;
          recipientBank = m.name;
          break;
        }
      }
    }
    payer ??= mentions
        .where((m) => m.name != recipientBank)
        .map((m) => m.name)
        .firstOrNull;

    return ReceiptDraft(
      amount: _findAmount(lines),
      merchant: store ?? (isTransfer ? null : _findMerchantLine(lines)),
      paidWith: payer,
      recipient: recipient,
      recipientBank: recipientBank,
      kind: store != null
          ? ReceiptKind.store
          : isQris
          ? ReceiptKind.qris
          : isTransfer
          ? ReceiptKind.transfer
          : ReceiptKind.other,
      isQris: isQris,
      date: _findDate(lines),
      categoryHint: store != null
          ? 'groceries'
          : (isTransfer ? 'transfer' : null),
    );
  }

  static bool _looksLikeName(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 40 || RegExp(r'\d').hasMatch(t))
      return false;
    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.length >= 3 && letters == letters.toUpperCase();
  }

  static String? _findName(Map<String, List<String>> table, String lower) {
    for (final entry in table.entries) {
      for (final word in entry.value) {
        // Whole-word match so "dana" does not fire on "danamon" or "dananya".
        final pattern = RegExp('(^|[^a-z])${RegExp.escape(word)}(?![a-z])');
        if (pattern.hasMatch(lower)) return entry.key;
      }
    }
    return null;
  }

  /// Payment screenshots label the merchant ("Merchant", "Nama Merchant",
  /// "Penerima", "Ke"); the value is on the same line or the next one.
  static String? _findMerchantLine(List<String> lines) {
    final label = RegExp(
      r'^(nama merchant|merchant name|merchant|nama toko|penerima|tujuan|ke|to)\s*:?\s*(.*)$',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length; i++) {
      final m = label.firstMatch(lines[i]);
      if (m == null) continue;
      final sameLine = m.group(2)?.trim() ?? '';
      final value = sameLine.isNotEmpty
          ? sameLine
          : (i + 1 < lines.length ? lines[i + 1] : '');
      final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isNotEmpty &&
          !_number.hasMatch(clean.replaceAll(' ', '')) &&
          clean.length <= 60) {
        return clean;
      }
    }
    return null;
  }

  static double? _toAmount(String text) {
    double? best;
    for (final m in _number.allMatches(text)) {
      final whole = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      final cents = m.group(2);
      final value = double.tryParse(cents == null ? whole : '$whole.$cents');
      if (value == null || value < 100 || value > 1000000000) continue;
      if (best == null || value > best) best = value;
    }
    return best;
  }

  static bool _hasCurrency(String lower) =>
      RegExp(r'(^|[^a-z])(rp|idr)([^a-z]|$)').hasMatch(lower);

  static double? _findAmount(List<String> lines) {
    // Lines right below "Admin Fee", "Saldo", "Kembalian"... hold those values.
    final skipped = <int>{};
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (_skipKeys.any(l.contains) &&
          _toAmount(lines[i]) == null &&
          i + 1 < lines.length) {
        skipped.add(i + 1);
      }
    }

    // 1. A line labelled as the total (value on the line or the next one).
    for (final key in _totalKeys) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (!l.contains(key) ||
            _skipKeys.any((s) => l.contains(s) && !key.contains(s))) {
          continue;
        }
        final here = _toAmount(lines[i]);
        if (here != null) return here;
        if (i + 1 < lines.length) {
          final next = _toAmount(lines[i + 1]);
          if (next != null) return next;
        }
      }
    }
    // 2. Otherwise the largest Rp/IDR figure that is not change, tax, a fee or
    //    a balance. A bare "IDR" line takes its number from the next line.
    double? best;
    for (var i = 0; i < lines.length; i++) {
      if (skipped.contains(i)) continue;
      final l = lines[i].toLowerCase();
      if (!_hasCurrency(l) || _skipKeys.any(l.contains)) continue;
      var v = _toAmount(lines[i]);
      if (v == null && i + 1 < lines.length && !skipped.contains(i + 1)) {
        v = _toAmount(lines[i + 1]);
      }
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

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

  static DateTime? _findDate(List<String> lines) {
    final numeric = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})');
    final named = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?\s+(\d{4})');
    final now = DateTime.now();
    for (final line in lines) {
      DateTime? d;
      final n = numeric.firstMatch(line);
      if (n != null) {
        var y = int.parse(n.group(3)!);
        if (y < 100) y += 2000;
        d = _safeDate(y, int.parse(n.group(2)!), int.parse(n.group(1)!));
      } else {
        final m = named.firstMatch(line);
        final month = m == null ? null : _months[m.group(2)!.toLowerCase()];
        if (m != null && month != null) {
          d = _safeDate(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
        }
      }
      // Ignore impossible or far-off dates (often other numbers in a line).
      if (d != null &&
          !d.isAfter(now.add(const Duration(days: 1))) &&
          now.difference(d).inDays < 400) {
        return d;
      }
    }
    return null;
  }

  static DateTime? _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }
}
