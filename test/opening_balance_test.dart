import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/core/services/opening_balance.dart';

void main() {
  const neo = BalanceReading([
    BalanceLine('Total Saldo', 281643.2),
    BalanceLine('Neo NOW', 81416.69),
  ], 'Bank Neo');

  test('a balance becomes money in under Saldo awal, never spending', () {
    final draft = openingBalanceDraft(neo, neo.lines[1], isId: true);
    expect(draft.isIncoming, isTrue);
    expect(draft.amount, 81416.69);
    expect(draft.categoryHint, 'opening_balance');
    expect(draft.noteFor(isId: true), 'Saldo Bank Neo · Neo NOW');
  });

  test('a bare "Saldo" label and an unknown bank keep the note short', () {
    const plain = BalanceReading([BalanceLine('Saldo', 500000)], null);
    expect(
      openingBalanceDraft(plain, plain.lines.first, isId: true).noteFor(
        isId: true,
      ),
      'Saldo',
    );
    expect(
      openingBalanceDraft(plain, plain.lines.first, isId: false).noteFor(
        isId: false,
      ),
      'Balance',
    );
  });

  test('"Untuk" goes in front of the note', () {
    expect(
      noteWithPurpose('Saldo Bank Neo · Neo NOW', 'Transportasi', isId: true),
      'Untuk Transportasi · Saldo Bank Neo · Neo NOW',
    );
    expect(noteWithPurpose('', 'Makanan', isId: false), 'For Makanan');
    expect(noteWithPurpose('Gaji', null, isId: true), 'Gaji');
    expect(noteWithPurpose('', null, isId: true), isNull);
  });

  test('only the Tabungan purpose offers to update a goal', () {
    expect(isSavingsPurpose('Tabungan'), isTrue);
    expect(isSavingsPurpose('tabungan haji'), isTrue);
    expect(isSavingsPurpose('Transportasi'), isFalse);
    expect(isSavingsPurpose(null), isFalse);
  });
}
