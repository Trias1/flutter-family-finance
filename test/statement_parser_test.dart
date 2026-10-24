import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/statement_parser.dart';

void main() {
  // OCBC TANDA360 transaction history as on-device OCR returns it (rows
  // rebuilt by position, so the amount sits at the end of its row).
  const ocbc = '''
6:31 7.36 KB/s 90%
TANDA360 Komunitas-S
Saldo Aktif
IDR 123.673 08
15 Sep 2026
Refund / CashbackBerita : REFUND FEE/Payment & +2.000,00
Purchase/20260915
Bill payment Dr customer acctBerita : 3969 220.000,00
089678400572 VA OVO
Transfer Masuk BI FastHILMY FAUZAN/Transfer +232.000,00
Kekayaan
Refund / CashbackBerita : REFUND FEE/Payment & +2.000,00
Purchase/20260915
Bill payment Dr customer acctBerita : 1236 10.000,00
089678400572 VA OVO
Transfer Keluar BI FastBerita : ASTI NURHAYATI/- 35.000,00
11 Sep 2026
Pos Sales DebitBerita : 5451 SUPERINDO PDN QR 167.280,00
184 BEKASI KOT.
Pos Sales DebitBerita : 4332 Nikita fried chicken 24.000,00
Vida Bekasi (K
Pos Sales DebitBerita : 0468 WARUNG AA BEBEN, 5.000,00
KBYRN LM JAKARTA S
10 Sep 2026
Pos Sales DebitBerita : 9254 ESB RESTAURANT 10.500,00
TECHNOLOGY JAKARTA B
''';

  test('OCBC history: every row, with date, direction and amount', () {
    final items = StatementParser.parse(ocbc, now: DateTime(2026, 10, 10));
    expect(items.length, 10);

    final incoming = items.where((i) => i.isIncome).toList();
    expect(incoming.map((i) => i.amount), [2000, 232000, 2000]);
    expect(items.where((i) => !i.isIncome).length, 7);

    final salaryLike = items[2];
    expect(salaryLike.isIncome, isTrue);
    expect(salaryLike.amount, 232000);
    expect(salaryLike.date, DateTime(2026, 9, 15));
    expect(salaryLike.description, contains('HILMY FAUZAN'));
    expect(salaryLike.categoryHint, 'transfer_in');

    final ovo = items[1];
    expect(ovo.isIncome, isFalse);
    expect(ovo.amount, 220000);
    expect(ovo.description, contains('VA OVO'));

    final superindo = items[6];
    expect(superindo.amount, 167280);
    expect(superindo.date, DateTime(2026, 9, 11));
    expect(superindo.categoryHint, 'groceries');
    expect(
      superindo.description,
      startsWith('Pos Sales Debit · 5451 SUPERINDO'),
    );

    expect(items[7].categoryHint, 'food'); // Nikita fried chicken
    expect(items[8].categoryHint, 'food'); // WARUNG AA BEBEN

    expect(items.last.date, DateTime(2026, 9, 10));
    expect(items.last.amount, 10500);
  });

  test('a cropped screenshot of one day still works', () {
    const crop = '''
15 Sep 2026
Refund / CashbackBerita : REFUND FEE/Payment & +2.000,00
Purchase/20260915
Bill payment Dr customer acctBerita : 3969 220.000,00
089678400572 VA OVO
Transfer Masuk BI FastHILMY FAUZAN/Transfer +232.000,00
Kekayaan
Refund / CashbackBerita : REFUND FEE/Payment & +2.000,00
Purchase/20260915
Bill payment Dr customer acctBerita : 1236 10.000,00
089678400572 VA OVO
Transfer Keluar BI FastBerita : ASTI NURHAYATI/- 35.000,00
''';
    final items = StatementParser.parse(crop, now: DateTime(2026, 10, 10));
    expect(items.length, 6);
    expect(items.every((i) => i.date == DateTime(2026, 9, 15)), isTrue);
    // Money in that is real income (not a refund): only the transfer.
    final income = items.where((i) => i.isIncome && i.categoryHint != 'refund');
    expect(income.map((i) => i.amount), [232000]);
  });

  test('the balance at the top is never a transaction', () {
    final items = StatementParser.parse(ocbc, now: DateTime(2026, 10, 10));
    expect(
      items.any((i) => i.amount == 123673 || i.amount == 123673.08),
      isFalse,
    );
  });

  test('a shop receipt with many priced items is not a statement', () {
    const receipt = '''
INDOMARET
PT INDOMARCO PRISMATAMA
INDOMIE GORENG 3 3,100 9,300
AQUA 600ML 2 3,500 7,000
TEH PUCUK 1 4,000 4,000
HARGA JUAL : 20,300
TOTAL : 20,300
NON TUNAI : 20,300
KEMBALI : 0
''';
    expect(StatementParser.parse(receipt), isEmpty);
  });

  test('BCA cash-flow rows with "01/10" dates are a statement', () {
    const text = '''
Oktober 2026
01/10 TRIAS ZAEN MUTAQIN - BANK OCBC NISP IDR 260,000.00 CR
03/10 GAJI PT MAJU JAYA IDR 7,500,000.00 CR
05/10 KARTU KREDIT BCA IDR 150,000.00 DB
''';
    final items = StatementParser.parse(text, now: DateTime(2026, 10, 10));
    expect(items.length, 3);
    expect(items[0].isIncome, isTrue);
    expect(items[0].date, DateTime(2026, 10, 1));
    expect(items[1].categoryHint, 'salary');
    expect(items[2].isIncome, isFalse);
  });

  test('a single receipt is not a list', () {
    const receipt = '''
INDOMARET
TOTAL : 16,300
''';
    expect(StatementParser.parse(receipt).length, lessThan(2));
  });
}
