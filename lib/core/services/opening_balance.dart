import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';

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

/// Money set aside for savings: the goal's balance can follow it.
bool isSavingsPurpose(String? purpose) =>
    purpose != null && purpose.toLowerCase().contains('tabungan');
