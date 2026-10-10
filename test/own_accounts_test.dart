import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/own_accounts.dart';

void main() {
  const names = ['Trias Zaen Mutaqin', 'Zulfa Syafiyah'];

  test('transfer to your own account at another bank', () {
    expect(
      OwnAccounts.isOwnTransfer('Transfer Keluar BI Fast · TRIAS ZAEN MUTAQIN/Mandiri', names),
      isTrue,
    );
  });

  test('a name cut short by the bank still counts', () {
    expect(OwnAccounts.isOwnTransfer('TRF BIFAST TRIAS ZAEN MUTAQ', names), isTrue);
  });

  test('transfer to a family member is internal too', () {
    expect(OwnAccounts.isOwnTransfer('Transfer ke ZULFA SYAFIYAH (BSI)', names), isTrue);
  });

  test('someone else, or shopping, is not', () {
    expect(OwnAccounts.isOwnTransfer('Transfer Keluar BI Fast · ASTI NURHAYATI', names), isFalse);
    expect(OwnAccounts.isOwnTransfer('Pos Sales Debit · SUPERINDO', names), isFalse);
  });

  test('a shared first name alone is not enough', () {
    expect(OwnAccounts.mentions('Transfer TRIAS SANTOSO', names), isFalse);
  });
}
