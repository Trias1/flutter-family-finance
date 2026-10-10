import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/sheet_recap_builder.dart';

void main() {
  group('blockFor', () {
    test('app defaults land in the template groups', () {
      expect(SheetRecapBuilder.blockFor('Makanan', null), 'food');
      expect(SheetRecapBuilder.blockFor('Belanja', null), 'food');
      expect(SheetRecapBuilder.blockFor('Transportasi', null), 'transport');
      expect(SheetRecapBuilder.blockFor('Tagihan', null), 'bills');
      expect(SheetRecapBuilder.blockFor('Hiburan', null), 'hobby');
      expect(SheetRecapBuilder.blockFor('Kesehatan', null), 'other');
      expect(SheetRecapBuilder.blockFor('Lainnya', null), 'other');
    });

    test('custom categories named like the sheet', () {
      expect(
        SheetRecapBuilder.blockFor('Listrik dan Internet', null),
        'bills',
      );
      expect(SheetRecapBuilder.blockFor('Hangout Jalan', null), 'hangout');
      expect(
        SheetRecapBuilder.blockFor('Pakaian dan kebutuuan', null),
        'personal',
      );
      expect(
        SheetRecapBuilder.blockFor('Dana Sosial dan Hadiah', null),
        'social',
      );
      expect(SheetRecapBuilder.blockFor('Sedekah', null), 'charity');
      expect(SheetRecapBuilder.blockFor('Arisan', null), 'arisan');
      expect(SheetRecapBuilder.blockFor('Sewa kontrakan', null), 'rent');
    });

    test('short words only match whole words', () {
      expect(SheetRecapBuilder.blockFor('Kosmetik', null), 'other');
      expect(SheetRecapBuilder.blockFor('Kos', null), 'rent');
      expect(SheetRecapBuilder.blockFor('Air galon', null), 'bills');
    });

    test('savings split by the goal in the note', () {
      expect(SheetRecapBuilder.blockFor('Tabungan', 'Dana Darurat'), 'emergency');
      expect(SheetRecapBuilder.blockFor('Tabungan', 'Emas Antam'), 'invest');
      expect(SheetRecapBuilder.blockFor('Tabungan', 'Liburan Bali'), 'goal');
      expect(SheetRecapBuilder.blockFor('Savings', null), 'goal');
    });
  });

  test('month titles round-trip in both languages', () {
    final m = DateTime(2026, 9);
    expect(SheetRecapBuilder.monthTitle(m, true), 'September 2026');
    expect(SheetRecapBuilder.monthTitle(DateTime(2026, 10), true), 'Oktober 2026');
    expect(SheetRecapBuilder.parseMonthTitle('Oktober 2026'), DateTime(2026, 10));
    expect(SheetRecapBuilder.parseMonthTitle('May 2026'), DateTime(2026, 5));
    expect(SheetRecapBuilder.parseMonthTitle('Ringkasan'), isNull);
  });

  test('formulas point at the right rows', () {
    final rows = SheetRecapBuilder.month(
      month: DateTime(2026, 9),
      expenses: [
        RecapEntry(date: DateTime(2026, 9, 3), amount: 50000, category: 'Makanan'),
        RecapEntry(date: DateTime(2026, 9, 1), amount: 20000, category: 'Makanan', note: 'Sayur'),
        RecapEntry(date: DateTime(2026, 9, 5), amount: 300000, category: 'Tabungan', note: 'Dana darurat'),
      ],
      incomes: [
        RecapEntry(date: DateTime(2026, 9, 25), amount: 8400000, category: 'Gaji'),
      ],
      isId: true,
      updatedAt: DateTime(2026, 10, 1),
    );

    int rowOf(String text) =>
        rows.indexWhere((r) => r.cells.any((c) => c.text == text)) + 1;
    String formulaIn(int row) => SheetRecapBuilder.resolve(
      rows[row - 1].cells.firstWhere((c) => c.formula != null).formula!,
      rows,
    );

    // Food block: title, header, two rows (oldest first), total.
    final food = rowOf('Kebutuhan pokok (Makan dan belanja)');
    expect(rows[food + 1].cells[1].text, 'Sayur');
    expect(rows[food + 2].cells[1].text, 'Makanan');
    expect(formulaIn(food + 4), '=SUM(C${food + 2}:C${food + 3})');

    // Empty block keeps one blank row so the template stays the same.
    final arisan = rowOf('Arisan');
    expect(formulaIn(arisan + 3), '=SUM(C${arisan + 2}:C${arisan + 2})');

    final spend = rowOf('TOTAL PENGELUARAN');
    final recapFirst = rowOf('Rekapitulasi Pengeluaran Bulanan') + 2;
    expect(formulaIn(spend), '=SUM(C$recapFirst:C${spend - 1})');
    expect(spend - recapFirst, SheetRecapBuilder.blocks.length);

    // Fixed summary cells at the top.
    expect(formulaIn(3), '=C${spend + 1}');
    expect(formulaIn(4), '=C$spend');
    expect(formulaIn(5), '=C3-C4');
  });
}
