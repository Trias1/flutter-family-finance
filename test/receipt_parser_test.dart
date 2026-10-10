import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';

void main() {
  group('bank transfer screenshot (OCBC to blu by BCA Digital)', () {
    // How on-device OCR reads the OCBC "Transaction Successful" screen.
    const ocbcSplit = '''
OCBC
Transaction Successful
Transfer
From
ACH. CHUSNUL CHIKAM
****-****-6851 (IDR)
AN
ASTI NURHAYATI
BANK DIGITAL BCA
0097-9899-5176 (IDR)
28 Sep 2026 • 06:51:46 WIB
IDR
35,000
Transfer Method
BIFAST
Admin Fee
IDR 2,500 IDR 0
Transfer Time
28 Sep 2026
Transfer Purpose
Fund Transfer
Reference Number
202609280651445722
''';

    test('amount, payer bank, recipient and date', () {
      final d = ReceiptParser.parse(ocbcSplit);
      expect(d.amount, 35000);
      expect(d.paidWith, 'OCBC');
      expect(d.kind, ReceiptKind.transfer);
      expect(d.recipient, 'ASTI NURHAYATI');
      expect(d.recipientBank, 'blu by BCA Digital');
      expect(d.date, DateTime(2026, 9, 28));
      expect(
        d.noteFor(isId: true),
        'Transfer ke ASTI NURHAYATI (blu by BCA Digital) · OCBC',
      );
    });

    test('currency and amount on one line', () {
      final d = ReceiptParser.parse(ocbcSplit.replaceFirst('IDR\n35,000', 'IDR 35,000'));
      expect(d.amount, 35000);
    });
  });

  test('Indomaret receipt: total, not change or tax', () {
    const text = '''
INDOMARET
PT INDOMARCO PRISMATAMA
JL MERDEKA NO 10
NPWP 01.337.994.6-092.000
INDOMIE GORENG 3 3,100 9,300
AQUA 600ML 2 3,500 7,000
HARGA JUAL : 16,300
TOTAL : 16,300
NON TUNAI : 16,300
PPN : 1,615
KEMBALI : 0
03.10.26-14:22 2.0.36 1234/KASIR/01
''';
    final d = ReceiptParser.parse(text);
    expect(d.amount, 16300);
    expect(d.merchant, 'Indomaret');
    expect(d.kind, ReceiptKind.store);
    expect(d.categoryHint, 'groceries');
  });

  test('QRIS payment from GoPay', () {
    const text = '''
gopay
Pembayaran berhasil
QRIS
Nama Merchant
KOPI KENANGAN SUDIRMAN
Total Pembayaran
Rp25.000
05 Okt 2026 12:10
''';
    final d = ReceiptParser.parse(text);
    expect(d.amount, 25000);
    expect(d.paidWith, 'GoPay');
    expect(d.isQris, isTrue);
    expect(d.merchant, 'KOPI KENANGAN SUDIRMAN');
    expect(d.noteFor(isId: true), 'KOPI KENANGAN SUDIRMAN · QRIS GoPay');
  });

  test('"dana" inside another word is not DANA', () {
    final d = ReceiptParser.parse('Bank Danamon\nTotal Rp 50.000');
    expect(d.paidWith, 'Danamon');
  });

  group('money coming in goes to Income', () {
    test('salary credited (BCA)', () {
      const text = '''
BCA
Transfer Masuk
Dari
PT MAJU JAYA SENTOSA
Keterangan
GAJI OKTOBER 2026
Rp 7.500.000,00
01 Okt 2026
''';
      final d = ReceiptParser.parse(text);
      expect(d.isIncoming, isTrue);
      expect(d.amount, 7500000);
      expect(d.categoryHint, 'salary');
      expect(d.sender, 'PT MAJU JAYA SENTOSA');
      expect(d.noteFor(isId: true), 'Gaji dari PT MAJU JAYA SENTOSA · BCA');
    });

    test('transfer received in DANA', () {
      const text = '''
DANA
Kamu menerima
Rp50.000
Dari
BUDI SANTOSO
05 Okt 2026
''';
      final d = ReceiptParser.parse(text);
      expect(d.isIncoming, isTrue);
      expect(d.amount, 50000);
      expect(d.categoryHint, 'transfer_in');
      expect(d.noteFor(isId: false), 'Money received from BUDI SANTOSO · DANA');
    });

    test('paying with a credit card is still spending', () {
      final d = ReceiptParser.parse(
        'ALFAMART\nTOTAL 45.000\nKARTU KREDIT BNI 45.000',
      );
      expect(d.isIncoming, isFalse);
      expect(d.amount, 45000);
    });

    test('an outgoing transfer is not income', () {
      final d = ReceiptParser.parse(
        'OCBC\nTransfer\nASTI NURHAYATI\nBANK DIGITAL BCA\nIDR 35,000',
      );
      expect(d.isIncoming, isFalse);
    });
  });
}
