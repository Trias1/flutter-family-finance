# Tagihan bisa di-scan (Bagian 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paying a bill (scanned receipt or "mark paid") records one expense in the bill's category (so its budget is cut), marks the bill paid and moves a repeating bill to its next due date; each bill has its own category, pay window and fixed/variable amount.

**Architecture:** Pure bill rules live in `lib/core/services/bill_logic.dart` (next due date, status, pay window, matching a receipt to a bill, state after paying/unpaying), unit tested. `BillModel` gains `category`, `payFromDay`, `dueDay`, `variableAmount`. One payment path, `recordBillPayment`, opens the existing expense form prefilled (so Budget/Tabungan source still works) and updates the bill only when the expense was saved. The scan flow asks "Ini bayar tagihan X?" before the normal expense flow.

**Tech Stack:** Flutter 3.44, Riverpod, Cloud Firestore, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-12-budget-savings-bills-design.md` (Bagian 4)

## Global Constraints

- One payment = one expense. Marking a bill paid never records a second expense for the same payment.
- Pay dates are set by the user per bill (e.g. Listrik 1–20, Internet 1–17); nothing date-specific is hard-coded.
- Variable bills (Listrik) match by keyword only and take the receipt's amount (the bill's amount becomes next month's estimate); fixed bills (Internet) may also match by amount.
- A receipt that matches no bill goes through the existing expense flow unchanged; a balance screenshot never reaches this flow (already returns earlier).
- No Firestore rules change (`/bills` has no key whitelist).
- Shell: Git Bash from `D:/project-pribadi/fluter`; `export JAVA_HOME=D:/android/jbr npm_config_cache=D:/npm-cache`; tests `flutter test <file>`; full suite `flutter test $(ls test/*_test.dart | grep -v widget_test)` (widget_test fails before this work); `flutter analyze lib` must add no errors or warnings. No emulator, no `flutter run/build`.
- Shell heredocs turn `\b` into a backspace: write Dart with file tools.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- UI text Indonesian with English fallback via `isId`, like the surrounding code.

## Review Focus

1. A repeating bill paid early (before its pay window, e.g. Internet paid on the 28th for next month) must still roll to the following period exactly once — test in Task 1.
2. Monthly due day 31 must not drift to 28 after February — test in Task 1 (`dueDay`).
3. Two unpaid bills matching the same receipt (e.g. "Listrik rumah" and "Listrik kos") — the earliest due wins, and the dialog names it so the user can say "Bukan" — test in Task 1.
4. Cancelling the expense form after "Iya, bayar tagihan" must leave the bill unpaid — manual check in Task 3.
5. Un-marking a paid one-off bill clears `paidDate` — test in Task 1.

---

### Task 1: Bill model fields and pure bill rules

**Files:**
- Modify: `lib/data/models/bill_model.dart` (fields, constructor, from/toFirestore, copyWith with `clearPaidDate`)
- Create: `lib/core/services/bill_logic.dart`
- Test: `test/bill_logic_test.dart`

**Interfaces:**
- Produces:
  - `BillModel` fields: `String? category`, `int? payFromDay`, `int? dueDay`, `bool variableAmount` (default false); Firestore keys `category`, `payFromDay`, `dueDay`, `variableAmount`; `copyWith({..., String? category, int? payFromDay, int? dueDay, bool? variableAmount, bool clearPaidDate = false})`.
  - `String billCategory(BillModel b)` → `b.category` if non-empty else `b.name`.
  - `DateTime nextDueDate(DateTime due, BillRepeatType repeat, {int? dueDay})`
  - `bool isOverdue(BillModel b, DateTime now)`
  - `bool inPayWindow(BillModel b, DateTime date)`
  - `BillModel afterPayment(BillModel b, {required DateTime paidAt, required double paidAmount})`
  - `BillModel afterUnpay(BillModel b)`
  - `BillModel? matchBill(String text, double? amount, DateTime date, List<BillModel> bills)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/bill_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/bill_logic.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';

BillModel bill(
  String name, {
  double amount = 350000,
  DateTime? due,
  BillRepeatType repeat = BillRepeatType.monthly,
  BillStatus status = BillStatus.unpaid,
  String? category,
  int? payFromDay,
  int? dueDay,
  bool variable = false,
  DateTime? paidDate,
}) => BillModel(
  id: name,
  familyId: 'f',
  name: name,
  amount: amount,
  dueDate: due ?? DateTime(2026, 10, 17),
  repeatType: repeat,
  status: status,
  category: category,
  payFromDay: payFromDay,
  dueDay: dueDay,
  variableAmount: variable,
  paidDate: paidDate,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('category defaults to the bill name', () {
    expect(billCategory(bill('Internet')), 'Internet');
    expect(billCategory(bill('Wifi rumah', category: 'Internet')), 'Internet');
  });

  test('next due date: monthly keeps the day, end of month clamps without drift', () {
    expect(nextDueDate(DateTime(2026, 10, 17), BillRepeatType.monthly), DateTime(2026, 11, 17));
    expect(nextDueDate(DateTime(2026, 1, 31), BillRepeatType.monthly, dueDay: 31), DateTime(2026, 2, 28));
    expect(nextDueDate(DateTime(2026, 2, 28), BillRepeatType.monthly, dueDay: 31), DateTime(2026, 3, 31));
    expect(nextDueDate(DateTime(2026, 10, 17), BillRepeatType.weekly), DateTime(2026, 10, 24));
    expect(nextDueDate(DateTime(2028, 2, 29), BillRepeatType.yearly), DateTime(2029, 2, 28));
    expect(nextDueDate(DateTime(2026, 10, 17), BillRepeatType.none), DateTime(2026, 10, 17));
  });

  test('overdue only after the whole due day has passed and while unpaid', () {
    final b = bill('Internet', due: DateTime(2026, 10, 17));
    expect(isOverdue(b, DateTime(2026, 10, 17, 23, 59)), isFalse);
    expect(isOverdue(b, DateTime(2026, 10, 18)), isTrue);
    expect(isOverdue(b.copyWith(status: BillStatus.paid), DateTime(2026, 10, 18)), isFalse);
  });

  test('pay window: from payFromDay of the due month up to the due date', () {
    final b = bill('Listrik', due: DateTime(2026, 10, 20), payFromDay: 1);
    expect(inPayWindow(b, DateTime(2026, 10, 1)), isTrue);
    expect(inPayWindow(b, DateTime(2026, 10, 20, 22)), isTrue);
    expect(inPayWindow(b, DateTime(2026, 9, 30)), isFalse);
    expect(inPayWindow(b, DateTime(2026, 10, 21)), isFalse);
    // No payFromDay: the whole month up to the due date.
    expect(inPayWindow(bill('Internet'), DateTime(2026, 10, 2)), isTrue);
  });

  test('paying a monthly bill moves it to next month, unpaid again', () {
    final paid = afterPayment(
      bill('Internet', due: DateTime(2026, 10, 17)),
      paidAt: DateTime(2026, 10, 15),
      paidAmount: 350000,
    );
    expect(paid.dueDate, DateTime(2026, 11, 17));
    expect(paid.status, BillStatus.unpaid);
    expect(paid.paidDate, DateTime(2026, 10, 15));
    expect(paid.amount, 350000);
  });

  test('paying early (before the window) still moves exactly one period', () {
    final paid = afterPayment(
      bill('Internet', due: DateTime(2026, 11, 17), payFromDay: 1),
      paidAt: DateTime(2026, 10, 28),
      paidAmount: 350000,
    );
    expect(paid.dueDate, DateTime(2026, 12, 17));
  });

  test('a variable bill keeps the paid amount as next estimate', () {
    final paid = afterPayment(
      bill('Listrik', amount: 300000, due: DateTime(2026, 10, 20), variable: true),
      paidAt: DateTime(2026, 10, 10),
      paidAmount: 342500,
    );
    expect(paid.amount, 342500);
  });

  test('a one-off bill becomes paid; unpaying clears the paid date', () {
    final once = bill('Servis AC', repeat: BillRepeatType.none);
    final paid = afterPayment(once, paidAt: DateTime(2026, 10, 3), paidAmount: 350000);
    expect(paid.status, BillStatus.paid);
    expect(paid.paidDate, DateTime(2026, 10, 3));
    final back = afterUnpay(paid);
    expect(back.status, BillStatus.unpaid);
    expect(back.paidDate, isNull);
  });

  test('match by provider words for the bill kind', () {
    final listrik = bill('Listrik', variable: true, due: DateTime(2026, 10, 20));
    final internet = bill('Internet', due: DateTime(2026, 10, 17));
    final bills = [listrik, internet];
    expect(matchBill('PLN Prabayar\nToken 1234 5678\nRp 202.500', 202500, DateTime(2026, 10, 5), bills)?.name, 'Listrik');
    expect(matchBill('Pembayaran IndiHome\nRp 350.000', 350000, DateTime(2026, 10, 5), bills)?.name, 'Internet');
    expect(matchBill('BIZNET HOME\nTotal 350.000', 350000, DateTime(2026, 10, 5), bills)?.name, 'Internet');
  });

  test('a fixed bill also matches by amount inside its window; variable does not', () {
    final internet = bill('Internet', amount: 350000, due: DateTime(2026, 10, 17), payFromDay: 1);
    final listrik = bill('Listrik', amount: 300000, variable: true, due: DateTime(2026, 10, 20));
    expect(matchBill('Transfer ke PT ABC\nRp 350.000', 350000, DateTime(2026, 10, 10), [internet, listrik])?.name, 'Internet');
    expect(matchBill('Transfer ke PT ABC\nRp 350.000', 350000, DateTime(2026, 9, 10), [internet]), isNull);
    expect(matchBill('Transfer ke PT ABC\nRp 300.000', 300000, DateTime(2026, 10, 10), [listrik]), isNull);
  });

  test('paid, no match, or two of a kind: earliest unpaid due wins', () {
    final rumah = bill('Listrik rumah', due: DateTime(2026, 10, 20));
    final kos = bill('Listrik kos', due: DateTime(2026, 10, 12));
    expect(matchBill('PLN token\nRp 100.000', 100000, DateTime(2026, 10, 5), [rumah, kos])?.name, 'Listrik kos');
    expect(matchBill('Indomaret\nTotal 20.300', 20300, DateTime(2026, 10, 5), [rumah, kos]), isNull);
    final paidKos = kos.copyWith(status: BillStatus.paid);
    expect(matchBill('PLN token\nRp 100.000', 100000, DateTime(2026, 10, 5), [paidKos])?.name, isNull);
  });

  test('new fields round-trip through Firestore data', () {
    final data = bill('Listrik', category: 'Listrik', payFromDay: 1, dueDay: 20, variable: true).toFirestore();
    expect(data['category'], 'Listrik');
    expect(data['payFromDay'], 1);
    expect(data['dueDay'], 20);
    expect(data['variableAmount'], isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/bill_logic_test.dart`
Expected: FAIL — `bill_logic.dart` not found / unknown named parameters.

- [ ] **Step 3: Extend `BillModel`**

In `lib/data/models/bill_model.dart` add after `note`:

```dart
  /// Expense category a payment is recorded under (default: the name).
  final String? category;

  /// "Bisa dibayar mulai tanggal" (1-31); null = from the 1st.
  final int? payFromDay;

  /// Day of month the bill is due, kept so 31 -> Feb 28 -> Mar 31.
  final int? dueDay;

  /// Amount changes every period (Listrik); fixed when false (Internet).
  final bool variableAmount;
```

Constructor: `this.category, this.payFromDay, this.dueDay, this.variableAmount = false,`.
`toFirestore`: add `'category': category, 'payFromDay': payFromDay, 'dueDay': dueDay, 'variableAmount': variableAmount,`.
`fromFirestore`: `category: data['category'], payFromDay: (data['payFromDay'] as num?)?.toInt(), dueDay: (data['dueDay'] as num?)?.toInt(), variableAmount: data['variableAmount'] == true,`.
`copyWith`: add the four parameters (`?? this.x`) and `bool clearPaidDate = false` with `paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate)`.

- [ ] **Step 4: Write `bill_logic.dart`**

```dart
import 'package:family_finance_manager/data/models/bill_model.dart';

String billCategory(BillModel b) =>
    (b.category ?? '').trim().isNotEmpty ? b.category!.trim() : b.name;

DateTime _monthDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

DateTime nextDueDate(DateTime due, BillRepeatType repeat, {int? dueDay}) {
  switch (repeat) {
    case BillRepeatType.none:
      return due;
    case BillRepeatType.weekly:
      return DateTime(due.year, due.month, due.day + 7);
    case BillRepeatType.monthly:
      return _monthDay(due.year, due.month + 1, dueDay ?? due.day);
    case BillRepeatType.yearly:
      return _monthDay(due.year + 1, due.month, dueDay ?? due.day);
  }
}

DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

bool isOverdue(BillModel b, DateTime now) =>
    b.status != BillStatus.paid && now.isAfter(_endOfDay(b.dueDate));

bool inPayWindow(BillModel b, DateTime date) {
  final start = _monthDay(b.dueDate.year, b.dueDate.month, b.payFromDay ?? 1);
  final from = start.isAfter(b.dueDate) ? b.dueDate : start;
  return !date.isBefore(from) && !date.isAfter(_endOfDay(b.dueDate));
}

BillModel afterPayment(
  BillModel b, {
  required DateTime paidAt,
  required double paidAmount,
}) {
  final amount = b.variableAmount ? paidAmount : b.amount;
  if (b.repeatType == BillRepeatType.none) {
    return b.copyWith(status: BillStatus.paid, paidDate: paidAt, amount: amount);
  }
  return b.copyWith(
    dueDate: nextDueDate(b.dueDate, b.repeatType, dueDay: b.dueDay),
    status: BillStatus.unpaid,
    paidDate: paidAt,
    amount: amount,
  );
}

BillModel afterUnpay(BillModel b) =>
    b.copyWith(status: BillStatus.unpaid, clearPaidDate: true);

const _kindWords = <String, List<String>>{
  'listrik': ['pln', 'token listrik', 'listrik', 'electricity', 'prabayar', 'pascabayar'],
  'internet': ['indihome', 'telkom', 'biznet', 'first media', 'firstmedia', 'myrepublic', 'iconnet', 'cbn', 'wifi', 'internet'],
  'air': ['pdam', 'air minum'],
};

List<String> _wordsFor(BillModel b) {
  final label = '${b.name} ${b.category ?? ''}'.toLowerCase();
  final words = <String>{b.name.toLowerCase().trim()};
  for (final entry in _kindWords.entries) {
    if (entry.value.any(label.contains) || label.contains(entry.key)) {
      words.addAll(entry.value);
    }
  }
  return words.where((w) => w.length >= 3).toList();
}

bool _hasWord(String lower, String word) =>
    RegExp('(^|[^a-z])${RegExp.escape(word)}(?![a-z])').hasMatch(lower);

/// The unpaid bill this receipt pays: provider/name words first, then (for
/// fixed bills) the same amount within the pay window. Earliest due wins.
BillModel? matchBill(
  String text,
  double? amount,
  DateTime date,
  List<BillModel> bills,
) {
  final lower = text.toLowerCase();
  final unpaid = bills.where((b) => b.status != BillStatus.paid).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  for (final b in unpaid) {
    if (_wordsFor(b).any((w) => _hasWord(lower, w))) return b;
  }
  if (amount == null || amount <= 0) return null;
  for (final b in unpaid) {
    if (b.variableAmount) continue;
    final close = (amount - b.amount).abs() <= b.amount * 0.01;
    if (close && inPayWindow(b, date)) return b;
  }
  return null;
}
```

Note on the "two of a kind" test: both "Listrik rumah" and "Listrik kos" match by kind words; the sorted loop returns the earlier due ("Listrik kos").

- [ ] **Step 5: Run tests** — `flutter test test/bill_logic_test.dart` → PASS (12).

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/bill_model.dart lib/core/services/bill_logic.dart test/bill_logic_test.dart
git commit -m "feat(android): bill rules for due dates, pay windows and receipt matching

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Bill form fields and card label

**Files:**
- Modify: `lib/features/bills/presentation/pages/bills_page.dart` — `BillFormSheet` (`:275-559`) and `_BillCard` (`:166-273`) only. Do not touch `_togglePaid` (Task 3).

**Interfaces:**
- Consumes: `BillModel.category/payFromDay/dueDay/variableAmount`, `billCategory`, `isOverdue`, `effectiveExpenseCategoriesProvider`, `categoryNotifierProvider.addCategory(familyId, 'expense', name, existingNames)` (verify the name in `lib/features/categories/presentation/providers/category_provider.dart`).

- [ ] **Step 1: Form state** — add `String? _category; int? _payFromDay; bool _variable = false;` filled from the bill in `initState`.
- [ ] **Step 2: Fields** (after the repeat dropdown, before the note):
  - `DropdownButtonFormField<String>` "Kategori pengeluaran" with the expense categories (no "Tabungan"), plus an item `'__new__'` "Sama dengan nama tagihan"; default `_category ?? (categories contain name ? name : '__new__')`.
  - `DropdownButtonFormField<int?>` "Bisa dibayar mulai tanggal": items `null` ("Kapan saja") and 1–28.
  - The existing due date picker label becomes "Batas bayar" (keep the date picker; that date's day is the due day).
  - `SwitchListTile` "Nominal berubah-ubah (mis. listrik)" with subtitle "Nominal tagihan ikut struk terakhir; dicocokkan dari nama/penyedia saja."
- [ ] **Step 3: Save** — in `_submit`, both edit and new: pass `category: <chosen category or name>`, `payFromDay: _payFromDay`, `dueDay: _dueDate.day`, `variableAmount: _variable`, and for new bills also `note:` (bug: new bills dropped the note). If the chosen category is not an existing expense category, add it with `categoryNotifierProvider` before saving.
- [ ] **Step 4: Card label** — under the name show `'${billCategory(bill)} · ${payFromDay != null ? 'bayar tgl ${bill.payFromDay}–${bill.dueDate.day}' : 'batas tgl ${bill.dueDate.day}'}'` and a "Telat" chip when `isOverdue(bill, DateTime.now())` (replace the inline `dueDate.isBefore(now)` check at `:180` with `isOverdue`); "~" before the amount when `variableAmount`.
- [ ] **Step 5: Analyze** — `flutter analyze lib/features/bills` → no errors/new warnings.
- [ ] **Step 6: Commit** — `feat(android): bills have a category, pay window and fixed/variable amount`.

---

### Task 3: One payment path — mark paid, and scan to pay

**Files:**
- Modify: `lib/features/expense/presentation/pages/expense_page.dart` (`openFromReceipt` returns the saved expense; optional preset category)
- Create: `lib/features/bills/presentation/widgets/bill_payment.dart`
- Modify: `lib/features/bills/presentation/pages/bills_page.dart` — `_togglePaid` only
- Modify: `lib/core/widgets/main_shell.dart` — the expense branch at the end of `_scanReceipt`
- Test: `test/bill_logic_test.dart` (one case for the draft builder)

**Interfaces:**
- Consumes: Task 1 functions; `billStreamProvider`, `billNotifierProvider.updateBill`.
- Produces:
  - `static Future<ExpenseModel?> ExpensePage.openFromReceipt(BuildContext, WidgetRef, ReceiptDraft, {String? category})` — returns the saved expense, null when cancelled.
  - `ReceiptDraft billPaymentDraft(BillModel b, {ReceiptDraft? scanned, required bool isId})`
  - `Future<bool> recordBillPayment(BuildContext, WidgetRef, BillModel, {ReceiptDraft? scanned})`
  - `Future<bool> askBillPayment(BuildContext, BillModel, {required double? amount, required bool isId})`

- [ ] **Step 1: Failing test for the draft**

```dart
  test('payment draft: receipt amount and date win, note names the bill', () {
    final b = bill('Internet', amount: 350000);
    final d = billPaymentDraft(b, isId: true);
    expect(d.amount, 350000);
    expect(d.noteFor(isId: true), 'Bayar tagihan Internet');
    final scanned = ReceiptDraft(amount: 351500, date: DateTime(2026, 10, 9), paidWith: 'BCA');
    final s = billPaymentDraft(b, scanned: scanned, isId: true);
    expect(s.amount, 351500);
    expect(s.date, DateTime(2026, 10, 9));
    expect(s.noteFor(isId: true), 'Bayar tagihan Internet · BCA');
  });
```

(Add `import 'package:family_finance_manager/core/services/receipt_parser.dart';` and the bill_payment import — `billPaymentDraft` lives in `bill_logic.dart` so the test stays pure.)

- [ ] **Step 2: Run** — FAIL (`billPaymentDraft` undefined).
- [ ] **Step 3: Implement in `bill_logic.dart`**

```dart
ReceiptDraft billPaymentDraft(BillModel b, {ReceiptDraft? scanned, required bool isId}) =>
    ReceiptDraft(
      amount: scanned?.amount ?? b.amount,
      date: scanned?.date,
      paidWith: scanned?.paidWith,
      merchant: '${isId ? 'Bayar tagihan' : 'Bill payment'} ${b.name}',
    );
```
(import `receipt_parser.dart`). Run → PASS.

- [ ] **Step 4: Expense form returns what it saved** — `_showExpenseForm` gains `String? presetCategory` (used as the initial `selectedCategory` when non-null) and returns `Future<ExpenseModel?>`: `showModalBottomSheet<ExpenseModel>(...)`, and the success branch pops with the saved `model` (`Navigator.pop(ctx, model)`). `openFromReceipt(..., {String? category})` passes `presetCategory: category` and returns the sheet result. Other callers (`openNew`, `openEditor`, FAB) keep `Future<void>` by ignoring the value.

- [ ] **Step 5: `bill_payment.dart`**

```dart
/// Records paying [bill]: the expense form opens prefilled (amount, date,
/// the bill's category; Budget/Tabungan source as usual). Only when that
/// expense is saved is the bill marked paid / moved to its next due date.
Future<bool> recordBillPayment(BuildContext context, WidgetRef ref, BillModel bill, {ReceiptDraft? scanned}) async {
  final isId = Localizations.localeOf(context).languageCode == 'id';
  final saved = await ExpensePage.openFromReceipt(
    context, ref, billPaymentDraft(bill, scanned: scanned, isId: isId),
    category: billCategory(bill),
  );
  if (saved == null) return false; // cancelled: bill stays unpaid
  final err = await ref.read(billNotifierProvider.notifier)
      .updateBill(afterPayment(bill, paidAt: saved.date, paidAmount: saved.amount));
  ref.invalidate(billStreamProvider(bill.familyId));
  ref.invalidate(dashboardProvider);
  return err == null;
}

/// "Ini bayar tagihan Internet Rp 350.000?" — true for Iya.
Future<bool> askBillPayment(BuildContext context, BillModel bill, {required double? amount, required bool isId}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isId ? 'Bayar tagihan ${bill.name}?' : 'Pay ${bill.name}?'),
        content: Text(isId
            ? 'Struk ini terbaca sebagai pembayaran ${bill.name} ${CurrencyFormatter.format(amount ?? bill.amount)}. Tagihannya ditandai lunas dan budget ${billCategory(bill)} terpotong.'
            : 'This receipt reads as paying ${bill.name} ${CurrencyFormatter.format(amount ?? bill.amount)}. The bill is marked paid and the ${billCategory(bill)} budget is cut.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isId ? 'Bukan' : 'No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isId ? 'Iya, bayar' : 'Yes, pay')),
        ],
      ),
    ) ?? false;
```

- [ ] **Step 6: Mark paid from the Bills page** — `_togglePaid`:
  - paid → unpaid: `updateBill(afterUnpay(bill))`.
  - unpaid → paid: dialog "Catat sebagai pengeluaran Rp X?" with **Catat pengeluaran** (→ `recordBillPayment(context, ref, bill)`), **Tandai lunas saja** (→ `updateBill(afterPayment(bill, paidAt: DateTime.now(), paidAmount: bill.amount))`), and Batal.

- [ ] **Step 7: Scan to pay** — in `main_shell.dart` replace the last `else` branch of `_scanReceipt`:

```dart
    if (draft.isIncoming) {
      await IncomePage.openFromReceipt(context, ref, draft);
      return;
    }
    final scope = ref.read(financeScopeIdProvider);
    final bills = await ref
        .read(billStreamProvider(scope).future)
        .timeout(const Duration(seconds: 5), onTimeout: () => const <BillModel>[])
        .catchError((_) => const <BillModel>[]);
    final match = matchBill(scan.text, draft.amount, draft.date ?? DateTime.now(), bills);
    if (match != null && mounted &&
        await askBillPayment(context, match, amount: draft.amount, isId: isId)) {
      if (mounted) await recordBillPayment(context, ref, match, scanned: draft);
      return;
    }
    if (mounted) await ExpensePage.openFromReceipt(context, ref, draft);
```

- [ ] **Step 8: Verify** — `flutter test $(ls test/*_test.dart | grep -v widget_test)` → all pass; `flutter analyze lib` → no errors/new warnings. Manual (on the phone after release): scan a PLN receipt → "Bayar tagihan Listrik?" → Iya → expense form with Listrik and the receipt amount → save → Listrik budget cut, bill moves to next month; Iya then cancel the form → bill stays unpaid (Review Focus 4); "Bukan" → normal expense form.
- [ ] **Step 9: Commit** — `feat(android): pay a bill by scanning its receipt or marking it paid`.

---

### Task 4: Docs

- [ ] AGENTS.md: change `- [ ] Tagihan bisa di-scan (Bagian 4) & Utang dari scan (Bagian 5)` to `- [x] Tagihan bisa di-scan (Bagian 4): kategori, jendela bayar, nominal tetap/berubah, lunas = satu pengeluaran, bulanan pindah ke jatuh tempo berikutnya` and `- [ ] Utang dari scan (Bagian 5)`. Add Key Decision: `**Tagihan** - aturan di lib/core/services/bill_logic.dart; bayar = satu expense lewat form pengeluaran (sumber Budget/Tabungan), tagihan diperbarui hanya jika expense tersimpan`.
- [ ] Commit `docs: bills from scans (Bagian 4) done`.
