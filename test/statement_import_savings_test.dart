import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/transactions/presentation/pages/statement_import_page.dart';

void main() {
  test('an imported savings row links its goal by id, not by name', () {
    final neoNow = SavingModel(
      id: 'g2',
      familyId: 'f',
      name: 'Neo NOW',
      targetAmount: 1000000,
      currentAmount: 0,
      targetDate: DateTime(2027, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
    final e = importedSavingsExpense(
      scope: 'f',
      uid: 'u',
      amount: 200000,
      date: DateTime(2026, 10, 12),
      description: 'Transfer ke Neo',
      goal: neoNow,
    );
    expect(e.category, 'Tabungan');
    expect(e.savingId, 'g2');
    expect(e.note, 'Neo NOW · Transfer ke Neo');
  });

  test('no goal picked: plain Tabungan row', () {
    final e = importedSavingsExpense(
      scope: 'f',
      uid: 'u',
      amount: 200000,
      date: DateTime(2026, 10, 12),
      description: 'Transfer ke Neo',
    );
    expect(e.savingId, isNull);
    expect(e.note, 'Transfer ke Neo');
  });
}
