import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/bank_notification_parser.dart';

// Phrasings modelled on common Indonesian bank and e-wallet notifications.
// Replace or extend with real samples from the user's phone.
BankNotification n(String title, String text, {String app = 'BCA mobile'}) =>
    BankNotification(
      id: 'x',
      package: 'com.example.bank',
      app: app,
      title: title,
      text: text,
      time: DateTime(2026, 10, 11, 9, 30),
    );

void main() {
  test('money in from a transfer', () {
    final item = BankNotificationParser.parse(
      n(
        'Dana Masuk',
        'Anda menerima Rp500.000 dari HILMY FAUZAN. Saldo Rp1.250.000',
      ),
    )!;
    expect(item.isIncome, isTrue);
    expect(item.amount, 500000);
    expect(item.categoryHint, 'transfer_in');
    expect(item.description, startsWith('BCA mobile: Anda menerima'));
    expect(item.date, DateTime(2026, 10, 11, 9, 30));
  });

  test('QRIS payment is spending, balance is not the amount', () {
    final item = BankNotificationParser.parse(
      n(
        'Pembayaran Berhasil',
        'Pembayaran QRIS Rp25.000 di KOPI KENANGAN berhasil. Sisa saldo Rp98.673',
        app: 'GoPay',
      ),
    )!;
    expect(item.isIncome, isFalse);
    expect(item.amount, 25000);
    expect(item.categoryHint, 'food');
  });

  test('transfer out and decimal amounts', () {
    final item = BankNotificationParser.parse(
      n(
        'Transfer Berhasil',
        'Transfer Rp 1.250.000,00 ke ASTI NURHAYATI berhasil',
      ),
    )!;
    expect(item.isIncome, isFalse);
    expect(item.amount, 1250000);
    expect(item.categoryHint, 'transfer');

    final idr = BankNotificationParser.parse(
      n('', 'IDR 260,000.00 CR TRIAS ZAEN MUTAQIN - BANK OCBC NISP'),
    )!;
    expect(idr.isIncome, isTrue);
    expect(idr.amount, 260000);
  });

  test('"Transfer Masuk" with no dari/ke is money in', () {
    final item = BankNotificationParser.parse(
      n(
        'Transfer Masuk',
        'Transfer Masuk BI Fast Rp232.000 HILMY FAUZAN',
        app: 'OCBC',
      ),
    )!;
    expect(item.isIncome, isTrue);
    expect(item.amount, 232000);
  });

  test('salary, refund and top up are told apart', () {
    expect(
      BankNotificationParser.parse(
        n('', 'Gaji Rp9.100.000 telah masuk ke rekening Anda'),
      )!.categoryHint,
      'salary',
    );
    expect(
      BankNotificationParser.parse(
        n('', 'Refund Rp2.000 telah diterima'),
      )!.categoryHint,
      'refund',
    );
    final topup = BankNotificationParser.parse(
      n('Top Up Berhasil', 'Top up Rp100.000 ke GoPay berhasil', app: 'GoPay'),
    )!;
    expect(topup.isIncome, isTrue);
    expect(topup.categoryHint, 'topup');
  });

  test('groceries at a minimarket', () {
    final item = BankNotificationParser.parse(
      n('Transaksi Debit', 'Transaksi debit Rp167.280 di SUPERINDO BEKASI'),
    )!;
    expect(item.isIncome, isFalse);
    expect(item.categoryHint, 'groceries');
  });

  test('codes, promos, failures and plain balances are ignored', () {
    for (final text in [
      'Kode OTP Anda 123456 untuk transaksi Rp500.000. Jangan berikan kode ini.',
      'Promo! Cashback hingga Rp50.000 untuk pembayaran QRIS',
      'Transfer Rp100.000 ke BUDI gagal. Silakan coba lagi.',
      'Saldo rekening Anda Rp1.250.000',
      'Tagihan kartu kredit Rp750.000 jatuh tempo 25 Okt',
    ]) {
      expect(BankNotificationParser.parse(n('', text)), isNull, reason: text);
    }
  });

  test('amounts read the Indonesian and English ways', () {
    expect(BankNotificationParser.amountOf('500.000'), 500000);
    expect(BankNotificationParser.amountOf('1.250.000,00'), 1250000);
    expect(BankNotificationParser.amountOf('260,000.00'), 260000);
    expect(BankNotificationParser.amountOf('25.000,50'), 25000.5);
    expect(BankNotificationParser.amountOf('15000.'), 15000);
  });
}
