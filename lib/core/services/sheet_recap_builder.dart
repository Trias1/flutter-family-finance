/// Builds one month of the recap spreadsheet: the same layout every month,
/// modelled on the family's own budget sheet (one block per spending group,
/// an income block, then the monthly recap). Pure, so it can be tested
/// without Google.
library;

enum CellStyle { normal, title, subtitle, blockTitle, header, total, label }

class SheetCell {
  final String? text;
  final double? number;

  /// A formula without row numbers baked in: `{r}` is replaced with the
  /// 1-based row of a named anchor (see [SheetRow.anchor]) when written.
  final String? formula;
  final CellStyle style;
  final bool money;

  const SheetCell.text(this.text, {this.style = CellStyle.normal})
    : number = null,
      formula = null,
      money = false;
  const SheetCell.money(this.number, {this.style = CellStyle.normal})
    : text = null,
      formula = null,
      money = true;
  const SheetCell.formula(
    this.formula, {
    this.style = CellStyle.normal,
    this.money = true,
  }) : text = null,
       number = null;
  const SheetCell.empty({this.style = CellStyle.normal})
    : text = null,
      number = null,
      formula = null,
      money = false;
}

class SheetRow {
  final List<SheetCell> cells;

  /// Name other formulas use to point at this row.
  final String? anchor;
  const SheetRow(this.cells, {this.anchor});
  static const blank = SheetRow([]);
}

/// One transaction as the sheet needs it.
class RecapEntry {
  final DateTime date;
  final double amount;
  final String category;
  final String? note;
  const RecapEntry({
    required this.date,
    required this.amount,
    required this.category,
    this.note,
  });
}

class RecapBlock {
  final String key;
  final String id;
  final String en;
  const RecapBlock(this.key, this.id, this.en);
  String label(bool isId) => isId ? id : en;
}

class SheetRecapBuilder {
  static const blocks = [
    RecapBlock('arisan', 'Arisan', 'Arisan (rotating savings)'),
    RecapBlock(
      'rent',
      'Kebutuhan pokok (Sewa kontrakan)',
      'Essentials (Rent / housing)',
    ),
    RecapBlock(
      'food',
      'Kebutuhan pokok (Makan dan belanja)',
      'Essentials (Food & groceries)',
    ),
    RecapBlock(
      'transport',
      'Kebutuhan pokok (Transportasi)',
      'Essentials (Transport)',
    ),
    RecapBlock(
      'bills',
      'Kebutuhan pokok tagihan (Listrik, Air, Internet)',
      'Essential bills (Power, Water, Internet)',
    ),
    RecapBlock('emergency', 'Tabungan dana darurat', 'Emergency fund'),
    RecapBlock('goal', 'Tabungan tujuan', 'Savings goals'),
    RecapBlock('invest', 'Tabungan investasi', 'Investments'),
    RecapBlock(
      'hangout',
      'Lifestyle (Hangout / Jalan)',
      'Lifestyle (Going out / Trips)',
    ),
    RecapBlock(
      'personal',
      'Lifestyle (Pakaian & Kebutuhan Pribadi)',
      'Lifestyle (Clothes & Personal care)',
    ),
    RecapBlock(
      'hobby',
      'Lifestyle (Hobi & Hiburan)',
      'Lifestyle (Hobbies & Entertainment)',
    ),
    RecapBlock(
      'social',
      'Lifestyle (Dana Sosial / Hadiah)',
      'Lifestyle (Social & Gifts)',
    ),
    RecapBlock('charity', 'Sedekah / Infaq', 'Charity / Donations'),
    RecapBlock('other', 'Lainnya', 'Other'),
  ];

  static const _monthsId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String monthTitle(DateTime month, bool isId) =>
      '${(isId ? _monthsId : _monthsEn)[month.month - 1]} ${month.year}';

  /// The month a tab title names, or null for other tabs.
  static DateTime? parseMonthTitle(String title) {
    final parts = title.trim().split(' ');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[1]);
    if (year == null) return null;
    var i = _monthsId.indexOf(parts[0]);
    if (i < 0) i = _monthsEn.indexOf(parts[0]);
    return i < 0 ? null : DateTime(year, i + 1);
  }

  static bool isSavings(String category) {
    final c = category.toLowerCase();
    return c == 'tabungan' || c == 'savings';
  }

  /// Whether [text] has a word starting with one of [words]; a trailing
  /// `!` asks for the whole word (so "kos" does not match "kosmetik").
  static bool _has(String text, List<String> words) => words.any((w) {
    final whole = w.endsWith('!');
    final stem = whole ? w.substring(0, w.length - 1) : w;
    return RegExp(
      '(^|[^a-z])$stem${whole ? r'($|[^a-z])' : ''}',
      caseSensitive: false,
    ).hasMatch(text);
  });

  /// Which template block an expense belongs to, from its category (and,
  /// for savings, the goal name the app writes into the note).
  static String blockFor(String category, String? note) {
    final c = category.toLowerCase();
    final n = (note ?? '').toLowerCase();
    if (isSavings(c) || _has(c, ['tabungan', 'savings'])) {
      final both = '$c $n';
      if (_has(both, ['darurat', 'emergency'])) return 'emergency';
      if (_has(both, [
        'investasi',
        'invest',
        'emas',
        'gold',
        'reksa',
        'saham',
        'deposito',
      ])) {
        return 'invest';
      }
      return 'goal';
    }
    if (_has(c, ['darurat', 'emergency'])) return 'emergency';
    if (_has(c, [
      'investasi',
      'invest',
      'emas',
      'gold',
      'reksa',
      'saham',
      'deposito',
    ])) {
      return 'invest';
    }
    if (_has(c, [
      'sedekah',
      'infaq',
      'infak',
      'zakat',
      'donasi',
      'charity',
      'donation',
    ])) {
      return 'charity';
    }
    if (_has(c, ['arisan'])) return 'arisan';
    if (_has(c, [
      'sewa',
      'kontrakan',
      'kost!',
      'kos!',
      'rent!',
      'kpr!',
      'housing',
    ])) {
      return 'rent';
    }
    if (_has(c, [
      'tagihan',
      'listrik',
      'air!',
      'internet',
      'wifi',
      'pulsa',
      'pln!',
      'pdam!',
      'bill',
      'utilit',
    ])) {
      return 'bills';
    }
    if (_has(c, [
      'transport',
      'bensin',
      'bbm!',
      'ojek',
      'parkir',
      'tol!',
      'fuel',
    ])) {
      return 'transport';
    }
    if (_has(c, [
      'makan',
      'belanja',
      'groceries',
      'grocery',
      'food',
      'minum',
      'jajan',
      'dapur',
      'sembako',
      'shopping',
    ])) {
      return 'food';
    }
    if (_has(c, [
      'hangout',
      'jalan',
      'nongkrong',
      'liburan',
      'travel',
      'trip',
    ])) {
      return 'hangout';
    }
    if (_has(c, [
      'pakaian',
      'baju',
      'kebutuhan pribadi',
      'kebutuuan',
      'skincare',
      'personal',
      'cloth',
    ])) {
      return 'personal';
    }
    if (_has(c, [
      'hobi',
      'hobby',
      'hiburan',
      'entertain',
      'game',
      'streaming',
    ])) {
      return 'hobby';
    }
    if (_has(c, ['sosial', 'social', 'hadiah', 'kado', 'gift', 'kondangan'])) {
      return 'social';
    }
    return 'other';
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Rows for one month. The first rows hold the month's totals at fixed
  /// places (C3 income, C4 spending, C5 left) so the overview tab can point
  /// at them whatever the month's length.
  static List<SheetRow> month({
    required DateTime month,
    required List<RecapEntry> expenses,
    required List<RecapEntry> incomes,
    required bool isId,
    required DateTime updatedAt,
  }) {
    String t(String id, String en) => isId ? id : en;
    final rows = <SheetRow>[];
    final title = monthTitle(month, isId);

    rows.add(
      SheetRow([
        SheetCell.text(
          t('Pengeluaran Bulanan - $title', 'Monthly Spending - $title'),
          style: CellStyle.title,
        ),
      ]),
    );
    rows.add(
      SheetRow([
        SheetCell.text(
          t(
            'Dibuat otomatis oleh Family Finance · diperbarui ${_date(updatedAt)}. Ubah data lewat aplikasi; isi tab ini ditulis ulang saat sinkron.',
            'Made by Family Finance · updated ${_date(updatedAt)}. Edit records in the app; this tab is rewritten on every sync.',
          ),
          style: CellStyle.subtitle,
        ),
      ]),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(),
        SheetCell.text(t('Pendapatan', 'Income'), style: CellStyle.label),
        const SheetCell.formula('=C{income_total}', style: CellStyle.total),
      ]),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(),
        SheetCell.text(t('Pengeluaran', 'Spending'), style: CellStyle.label),
        const SheetCell.formula('=C{spend_total}', style: CellStyle.total),
      ]),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(),
        SheetCell.text(t('Sisa saldo', 'Left over'), style: CellStyle.label),
        const SheetCell.formula('=C3-C4', style: CellStyle.total),
      ]),
    );
    rows.add(SheetRow.blank);

    final header = [
      SheetCell.text(t('Tanggal', 'Date'), style: CellStyle.header),
      SheetCell.text(
        t('Rincian Pengeluaran', 'Details'),
        style: CellStyle.header,
      ),
      SheetCell.text(t('Nominal (Rp)', 'Amount'), style: CellStyle.header),
      SheetCell.text(t('Catatan', 'Notes'), style: CellStyle.header),
    ];

    void block(
      String label,
      String anchor,
      List<RecapEntry> entries,
      List<SheetCell> head,
    ) {
      rows.add(SheetRow([SheetCell.text(label, style: CellStyle.blockTitle)]));
      rows.add(SheetRow(head, anchor: '${anchor}_head'));
      final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
      if (sorted.isEmpty) {
        rows.add(SheetRow.blank);
      }
      for (final e in sorted) {
        final note = e.note?.trim() ?? '';
        rows.add(
          SheetRow([
            SheetCell.text(_date(e.date)),
            SheetCell.text(note.isEmpty ? e.category : note),
            SheetCell.money(e.amount),
            SheetCell.text(note.isEmpty ? '' : e.category),
          ]),
        );
      }
      rows.add(
        SheetRow([
          const SheetCell.empty(style: CellStyle.total),
          const SheetCell.text('Total', style: CellStyle.total),
          SheetCell.formula(
            '=SUM(C{${anchor}_first}:C{${anchor}_last})',
            style: CellStyle.total,
          ),
          const SheetCell.empty(style: CellStyle.total),
        ], anchor: anchor),
      );
      rows.add(SheetRow.blank);
    }

    final byBlock = <String, List<RecapEntry>>{};
    for (final e in expenses) {
      byBlock.putIfAbsent(blockFor(e.category, e.note), () => []).add(e);
    }
    for (final b in blocks) {
      block(b.label(isId), 'b_${b.key}', byBlock[b.key] ?? const [], header);
    }

    block(t('Pemasukan', 'Income'), 'income', incomes, [
      SheetCell.text(t('Tanggal', 'Date'), style: CellStyle.header),
      SheetCell.text(t('Sumber', 'Source'), style: CellStyle.header),
      SheetCell.text(t('Nominal (Rp)', 'Amount'), style: CellStyle.header),
      SheetCell.text(t('Catatan', 'Notes'), style: CellStyle.header),
    ]);

    rows.add(
      SheetRow([
        SheetCell.text(
          t('Rekapitulasi Pengeluaran Bulanan', 'Monthly Spending Recap'),
          style: CellStyle.blockTitle,
        ),
      ]),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(style: CellStyle.header),
        SheetCell.text(t('Kategori', 'Category'), style: CellStyle.header),
        const SheetCell.text('Total', style: CellStyle.header),
      ], anchor: 'recap_head'),
    );
    for (final b in blocks) {
      rows.add(
        SheetRow([
          const SheetCell.empty(),
          SheetCell.text(b.label(isId)),
          SheetCell.formula('=C{b_${b.key}}'),
        ]),
      );
    }
    rows.add(
      SheetRow([
        const SheetCell.empty(style: CellStyle.total),
        SheetCell.text(
          t('TOTAL PENGELUARAN', 'TOTAL SPENDING'),
          style: CellStyle.total,
        ),
        const SheetCell.formula(
          '=SUM(C{recap_first}:C{recap_last})',
          style: CellStyle.total,
        ),
      ], anchor: 'spend_total'),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(),
        SheetCell.text(t('Pendapatan Bulanan', 'Monthly Income')),
        const SheetCell.formula('=C{income}'),
      ], anchor: 'income_total'),
    );
    rows.add(
      SheetRow([
        const SheetCell.empty(style: CellStyle.total),
        SheetCell.text(t('Sisa Saldo', 'Left Over'), style: CellStyle.total),
        const SheetCell.formula(
          '=C{income_total}-C{spend_total}',
          style: CellStyle.total,
        ),
      ]),
    );
    return rows;
  }

  /// Resolves `{anchor}`, `{x_first}` and `{x_last}` placeholders to 1-based
  /// row numbers. `x_first`/`x_last` are the rows between `x_head` and `x`.
  static String resolve(String formula, List<SheetRow> rows) {
    final at = <String, int>{};
    for (var i = 0; i < rows.length; i++) {
      final a = rows[i].anchor;
      if (a != null) at[a] = i + 1;
    }
    return formula.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final name = m[1]!;
      if (at.containsKey(name)) return '${at[name]}';
      if (name.endsWith('_first')) {
        return '${at[name.replaceFirst(RegExp(r'_first$'), '_head')]! + 1}';
      }
      if (name.endsWith('_last')) {
        final base = name.replaceFirst(RegExp(r'_last$'), '');
        // The recap list ends right before the TOTAL row.
        if (base == 'recap') return '${at['spend_total']! - 1}';
        return '${at[base]! - 1}';
      }
      throw StateError('unknown anchor $name');
    });
  }
}
