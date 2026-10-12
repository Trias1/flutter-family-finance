import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';

/// A bank balance recorded as money in ("Saldo awal"), e.g. when starting
/// over from screenshots. Always income, never spending.
ReceiptDraft openingBalanceDraft(
  BalanceReading reading,
  BalanceLine line, {
  required bool isId,
}) {
  final pocket = RegExp(r'^saldo$', caseSensitive: false).hasMatch(line.label)
      ? null
      : line.label;
  final where = [?reading.bank, ?pocket].join(' · ');
  final label = isId ? 'Saldo' : 'Balance';
  return ReceiptDraft(
    amount: line.amount,
    isIncoming: true,
    categoryHint: 'opening_balance',
    merchant: where.isEmpty ? label : '$label $where',
  );
}

/// "Untuk Transportasi · Saldo Bank Neo": what the money is for, in front of
/// the note. Null when there is nothing to keep.
String? noteWithPurpose(String note, String? purpose, {required bool isId}) {
  final text = note.trim();
  if (purpose == null || purpose.trim().isEmpty) {
    return text.isEmpty ? null : text;
  }
  final head = '${isId ? 'Untuk' : 'For'} ${purpose.trim()}';
  return text.isEmpty ? head : '$head · $text';
}

/// The budget a balance sets: a new one starts at [amount] with what was
/// already [spent] this month; an existing one keeps its id, usage and
/// rollover and only gets the new amount.
BudgetModel budgetFromBalance({
  BudgetModel? existing,
  required String familyId,
  required String category,
  required String month,
  required double amount,
  required double spent,
}) => BudgetModel(
  id: existing?.id ?? '',
  familyId: familyId,
  month: month,
  category: category,
  budgetAmount: amount,
  usedAmount: existing?.usedAmount ?? spent,
  rolloverAmount: existing?.rolloverAmount ?? 0,
);

/// "Also record as income" starts off when this month already has a Saldo
/// awal from the same pocket ([source], e.g. "Saldo Bank Neo · Neo NOW")
/// and amount: a re-scan would double "In".
bool recordIncomeByDefault(
  List<IncomeModel> incomes, {
  required String source,
  required double amount,
  required DateTime now,
}) => !incomes.any(
  (i) =>
      i.category == 'Saldo awal' &&
      (i.note ?? '').endsWith(source) &&
      i.amount == amount &&
      i.date.year == now.year &&
      i.date.month == now.month,
);

/// "Untuk Transportasi · Saldo Bank Neo · Neo NOW".
String openingBalanceNote(
  BalanceReading r,
  BalanceLine line, {
  required String purpose,
  required bool isId,
}) => noteWithPurpose(
  openingBalanceDraft(r, line, isId: isId).noteFor(isId: isId) ?? '',
  purpose,
  isId: isId,
)!;
