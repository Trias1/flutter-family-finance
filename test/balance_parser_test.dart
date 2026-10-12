import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/balance_parser.dart';

// Account screens as on-device OCR returns them. Modelled on common layouts;
// tune with the user's real screenshots.
void main() {
  test('Bank Neo savings screen', () {
    final r = BalanceParser.parse('''
neobank
Bank Neo Commerce
Tabungan Kontrakan
Saldo
Rp3.000.000
No. Rekening 5859 1234 5678
''')!;
    expect(r.amount, 3000000);
    expect(r.bank, 'Bank Neo');
  });

  test('balance on the same row, IDR with cents', () {
    final r = BalanceParser.parse('''
OCBC
Saldo Aktif IDR 1,250,000.00
Tabungan TANDA360
''')!;
    expect(r.amount, 1250000);
    expect(r.bank, 'OCBC');
  });

  test('BSI with decimal comma', () {
    final r = BalanceParser.parse('''
BSI Mobile
Rekening Tabungan Haji
Saldo Efektif
Rp 12.500.000,00
''')!;
    expect(r.amount, 12500000);
    expect(r.bank, 'BSI');
  });

  test('account numbers and years are not balances', () {
    expect(
      BalanceParser.parse('''
Bank Jago
Saldo
5859123456
Oktober 2026
'''),
      isNull,
    );
  });

  test('payments, transfers and receipts are not balance screens', () {
    expect(
      BalanceParser.parse(
        'Transfer Berhasil\nRp500.000\nSisa saldo Rp2.000.000',
      ),
      isNull,
    );
    expect(
      BalanceParser.parse(
        'INDOMARET\nTOTAL BELANJA 20.300\nKEMBALI 0\nSaldo Rp 100.000',
      ),
      isNull,
    );
  });

  test('a hidden balance gives nothing', () {
    expect(BalanceParser.parse('BCA\nSaldo\nRp ••••••'), isNull);
  });

  test('a bank home screen with Transfer/Bayar menu buttons is a balance', () {
    final r = BalanceParser.parse('''
livin' by mandiri
Halo, TRIAS
Rekening Tabungan
Saldo Rekening
Rp 1.500.000,00
Transfer
Bayar
Top-up
Pembayaran
QRIS
''')!;
    expect(r.amount, 1500000);
    expect(r.bank, 'Mandiri');
  });

  neoTests();
}

// Bank Neo's account screen: one total and a balance per pocket. OCR reads
// the two-column Neo NOW row left column first.
const _neoAccounts = '''
10.14
Rekening
Total Saldo
Rp281,643.20
Est. bunga kemarin
+Rp5.10
Tabungan Neo
Saldo
Rp200,226.51
5859000000000000
Neo NOW
Saldo
Bunga kemarin
Rp81,416.69
+Rp5.10
Lainnya
Tambah Dana
Neo WOW Deposito
Maksimum 8% p.a.
Total Pokok Deposito
Rp0.00
''';

void neoTests() {
  test('Neo: every pocket is read, each balance once', () {
    final r = BalanceParser.parse(_neoAccounts)!;
    expect(r.bank, 'Bank Neo');
    expect(r.lines.map((l) => '${l.label}=${l.amount}').toList(), [
      'Total Saldo=281643.2',
      'Tabungan Neo=200226.51',
      'Neo NOW=81416.69',
    ]);
    expect(r.amount, 281643.2);
  });

  test('a pocket is matched to the goal named after it', () {
    final r = BalanceParser.parse(_neoAccounts)!;
    expect(r.lineFor('Dana darurat Neo NOW')?.label, 'Neo NOW');
    expect(r.lineFor('Tabungan Neo')?.label, 'Tabungan Neo');
    expect(r.lineFor('Kontrakan'), isNull);
  });
}
