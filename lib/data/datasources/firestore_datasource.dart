import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/core/constants/firestore_constants.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/category_model.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/debt_payment_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/family_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/models/user_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreConstants.users);
  CollectionReference<Map<String, dynamic>> get _userPublic =>
      _firestore.collection('user_public');
  CollectionReference<Map<String, dynamic>> get _families =>
      _firestore.collection(FirestoreConstants.families);
  CollectionReference<Map<String, dynamic>> get _incomes =>
      _firestore.collection(FirestoreConstants.incomes);
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection(FirestoreConstants.expenses);
  CollectionReference<Map<String, dynamic>> get _savings =>
      _firestore.collection(FirestoreConstants.savings);
  CollectionReference<Map<String, dynamic>> get _budgets =>
      _firestore.collection(FirestoreConstants.budgets);
  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection(FirestoreConstants.categories);

  Future<void> createUser(UserModel user) async {
    final batch = _firestore.batch();
    batch.set(_users.doc(user.id), user.toFirestore());
    batch.set(_userPublic.doc(user.id), {
      'name': user.name,
      'createdAt': Timestamp.fromDate(user.createdAt),
    });
    await batch.commit();
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<List<UserModel>> getUsersByFamilyId(String familyId) async {
    final snapshot = await _users.where('familyId', isEqualTo: familyId).get();
    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// [joinCode] must accompany any change of `familyId` to a family the user
  /// does not own; Firestore rules check it against `family_invites`.
  Future<void> updateUser(UserModel user, {String? joinCode}) async {
    final batch = _firestore.batch();
    batch.update(_users.doc(user.id), {
      ...user.toFirestore(),
      if (joinCode != null) 'joinCode': joinCode,
    });
    batch.set(_userPublic.doc(user.id), {
      'name': user.name,
      'createdAt': Timestamp.fromDate(user.createdAt),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> get _familyInvites =>
      _firestore.collection('family_invites');

  Map<String, dynamic> _inviteData(FamilyModel family) => {
    'familyId': family.id,
    'familyName': family.name,
    'createdBy': family.createdBy,
  };

  /// Creates the family and its invite lookup doc in one batch. Invite codes
  /// live in `family_invites/{code}`, readable one code at a time, so codes
  /// cannot be listed by other users.
  Future<FamilyModel> createFamily(FamilyModel family) async {
    final ref = _families.doc();
    final created = FamilyModel(
      id: ref.id,
      name: family.name,
      photoUrl: family.photoUrl,
      inviteCode: family.inviteCode,
      createdBy: family.createdBy,
      createdAt: family.createdAt,
    );
    final batch = _firestore.batch();
    batch.set(ref, created.toFirestore());
    batch.set(_familyInvites.doc(created.inviteCode), _inviteData(created));
    await batch.commit();
    return created;
  }

  /// Used by the family owner. Touches only the two fields rules let an
  /// owner change on another member's profile, and records a ban so the
  /// member cannot rejoin with the old code.
  Future<void> removeFamilyMember(String uid, String familyId) {
    final batch = _firestore.batch();
    batch.update(_users.doc(uid), {'familyId': null, 'role': 'member'});
    batch.set(_families.doc(familyId).collection('banned').doc(uid), {
      'bannedAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  Future<FamilyModel?> getFamily(String id) async {
    final doc = await _families.doc(id).get();
    if (!doc.exists) return null;
    return FamilyModel.fromFirestore(doc);
  }

  /// Looks up an invite code. Returns a partial family (id, name, owner)
  /// because non-members cannot read the family doc itself.
  Future<FamilyModel?> getFamilyByInviteCode(String code) async {
    final doc = await _familyInvites.doc(code.trim().toUpperCase()).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return FamilyModel(
      id: data['familyId'] as String? ?? '',
      name: data['familyName'] as String? ?? '',
      inviteCode: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  /// Families created before invite docs existed get one the first time
  /// their owner opens the app.
  Future<void> ensureFamilyInvite(FamilyModel family) async {
    if (family.inviteCode.isEmpty) return;
    final ref = _familyInvites.doc(family.inviteCode);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set(_inviteData(family));
  }

  Future<void> updateFamily(FamilyModel family) {
    return _families.doc(family.id).update(family.toFirestore());
  }

  Future<void> transferFamilyOwnership(
    String familyId,
    String newOwnerId,
  ) async {
    final familyRef = _families.doc(familyId);
    final newOwnerRef = _users.doc(newOwnerId);

    await _firestore.runTransaction((transaction) async {
      final familyDoc = await transaction.get(familyRef);
      final previousOwnerId = familyDoc.data()?['createdBy'] as String?;

      if (previousOwnerId != null &&
          previousOwnerId.isNotEmpty &&
          previousOwnerId != newOwnerId) {
        transaction.update(_users.doc(previousOwnerId), {'role': 'member'});
      }

      transaction.update(newOwnerRef, {'role': 'admin'});
      transaction.update(familyRef, {'createdBy': newOwnerId});
      final inviteCode = familyDoc.data()?['inviteCode'] as String?;
      if (inviteCode != null && inviteCode.isNotEmpty) {
        transaction.set(_familyInvites.doc(inviteCode), {
          'createdBy': newOwnerId,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> createIncome(IncomeModel income) {
    return _incomes.add(income.toFirestore());
  }

  Future<List<IncomeModel>> getIncomes(String familyId) async {
    final snapshot = await _incomes
        .where('familyId', isEqualTo: familyId)
        .get();
    final list = snapshot.docs
        .map((doc) => IncomeModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamIncomes(String familyId) {
    return _incomes.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<IncomeModel?> getIncome(String id) async {
    final doc = await _incomes.doc(id).get();
    if (!doc.exists) return null;
    return IncomeModel.fromFirestore(doc);
  }

  Future<void> updateIncome(IncomeModel income) {
    return _incomes.doc(income.id).update(income.toFirestore());
  }

  Future<void> deleteIncome(String id) {
    return _incomes.doc(id).delete();
  }

  Future<void> createExpense(ExpenseModel expense) {
    return _expenses.add(expense.toFirestore());
  }

  Future<List<ExpenseModel>> getExpenses(String familyId) async {
    final snapshot = await _expenses
        .where('familyId', isEqualTo: familyId)
        .get();
    final list = snapshot.docs
        .map((doc) => ExpenseModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamExpenses(String familyId) {
    return _expenses.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<ExpenseModel?> getExpense(String id) async {
    final doc = await _expenses.doc(id).get();
    if (!doc.exists) return null;
    return ExpenseModel.fromFirestore(doc);
  }

  Future<void> updateExpense(ExpenseModel expense) {
    return _expenses.doc(expense.id).update(expense.toFirestore());
  }

  Future<void> deleteExpense(String id) {
    return _expenses.doc(id).delete();
  }

  Future<void> createSaving(SavingModel saving) {
    return _savings.add(saving.toFirestore());
  }

  Future<SavingModel?> getSaving(String id) async {
    final doc = await _savings.doc(id).get();
    if (!doc.exists) return null;
    return SavingModel.fromFirestore(doc);
  }

  Future<List<SavingModel>> getSavings(String familyId) async {
    final snapshot = await _savings
        .where('familyId', isEqualTo: familyId)
        .get();
    final list = snapshot.docs
        .map((doc) => SavingModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSavings(String familyId) {
    return _savings.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<void> updateSaving(SavingModel saving) {
    return _savings.doc(saving.id).update(saving.toFirestore());
  }

  Future<void> deleteSaving(String id) {
    return _savings.doc(id).delete();
  }

  Future<void> setBudget(BudgetModel budget) {
    if (budget.id.isEmpty) {
      return _budgets.add(budget.toFirestore());
    }
    return _budgets.doc(budget.id).set(budget.toFirestore());
  }

  Future<BudgetModel?> getBudget(String id) async {
    final doc = await _budgets.doc(id).get();
    if (!doc.exists) return null;
    return BudgetModel.fromFirestore(doc);
  }

  Future<List<BudgetModel>> getBudgetsByMonth(
    String familyId,
    String month,
  ) async {
    final snapshot = await _budgets
        .where('familyId', isEqualTo: familyId)
        .get();
    final all = snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc))
        .toList();
    all.retainWhere((b) => b.month == month);
    return all;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBudgets(String familyId) {
    return _budgets.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<List<BudgetModel>> getAllBudgets(String familyId) async {
    // Sorted here: familyId + orderBy(month) would need a composite index.
    final snapshot = await _budgets
        .where('familyId', isEqualTo: familyId)
        .get();
    return snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  Future<void> updateBudget(BudgetModel budget) {
    return _budgets.doc(budget.id).update(budget.toFirestore());
  }

  Future<void> deleteBudget(String id) {
    return _budgets.doc(id).delete();
  }

  CollectionReference<Map<String, dynamic>> get _debts =>
      _firestore.collection(FirestoreConstants.debts);
  CollectionReference<Map<String, dynamic>> get _debtPayments =>
      _firestore.collection(FirestoreConstants.debtPayments);

  Future<void> createDebt(DebtModel debt) {
    return _debts.add(debt.toFirestore());
  }

  Future<List<DebtModel>> getDebts(String familyId) async {
    final snapshot = await _debts.where('familyId', isEqualTo: familyId).get();
    final list = snapshot.docs
        .map((doc) => DebtModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDebts(String familyId) {
    return _debts.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<DebtModel?> getDebt(String id) async {
    final doc = await _debts.doc(id).get();
    if (!doc.exists) return null;
    return DebtModel.fromFirestore(doc);
  }

  Future<void> updateDebt(DebtModel debt) {
    return _debts.doc(debt.id).update(debt.toFirestore());
  }

  Future<void> deleteDebt(String id) {
    return _debts.doc(id).delete();
  }

  Future<void> createDebtPayment(DebtPaymentModel payment) {
    return _debtPayments.add(payment.toFirestore());
  }

  Future<List<DebtPaymentModel>> getDebtPayments(String debtId) async {
    final snapshot = await _debtPayments
        .where('debtId', isEqualTo: debtId)
        .get();
    final list = snapshot.docs
        .map((doc) => DebtPaymentModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  CollectionReference<Map<String, dynamic>> get _recurrings =>
      _firestore.collection(FirestoreConstants.recurringTransactions);

  Future<void> createRecurring(RecurringModel recurring) {
    return _recurrings.add(recurring.toFirestore());
  }

  Future<List<RecurringModel>> getRecurrings(String familyId) async {
    final snapshot = await _recurrings
        .where('familyId', isEqualTo: familyId)
        .get();
    return snapshot.docs
        .map((doc) => RecurringModel.fromFirestore(doc))
        .toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRecurrings(
    String familyId,
  ) {
    return _recurrings.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<List<RecurringModel>> getDueRecurrings([String? familyId]) async {
    var query =
        _recurrings.where('isActive', isEqualTo: true)
            as Query<Map<String, dynamic>>;
    if (familyId != null) {
      query = query.where('familyId', isEqualTo: familyId);
    }
    final snapshot = await query.get();
    final all = snapshot.docs
        .map((doc) => RecurringModel.fromFirestore(doc))
        .toList();
    all.retainWhere(
      (r) =>
          r.nextDate.isBefore(DateTime.now()) ||
          r.nextDate.isAtSameMomentAs(DateTime.now()),
    );
    return all;
  }

  Future<void> updateRecurring(RecurringModel recurring) {
    return _recurrings.doc(recurring.id).update(recurring.toFirestore());
  }

  Future<void> deleteRecurring(String id) {
    return _recurrings.doc(id).delete();
  }

  CollectionReference<Map<String, dynamic>> get _bills =>
      _firestore.collection(FirestoreConstants.bills);

  Future<void> createBill(BillModel bill) {
    return _bills.add(bill.toFirestore());
  }

  Future<BillModel?> getBill(String id) async {
    final doc = await _bills.doc(id).get();
    if (!doc.exists) return null;
    return BillModel.fromFirestore(doc);
  }

  Future<List<BillModel>> getBills(String familyId) async {
    final snapshot = await _bills.where('familyId', isEqualTo: familyId).get();
    final list = snapshot.docs
        .map((doc) => BillModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBills(String familyId) {
    return _bills.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<void> updateBill(BillModel bill) {
    return _bills.doc(bill.id).update(bill.toFirestore());
  }

  Future<void> deleteBill(String id) {
    return _bills.doc(id).delete();
  }

  Future<void> createCategory(CategoryModel category) {
    return _categories.add(category.toFirestore());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCategories(
    String familyId,
  ) {
    return _categories.where('familyId', isEqualTo: familyId).snapshots();
  }

  Future<List<CategoryModel>> getCategories(String familyId) async {
    final snapshot = await _categories
        .where('familyId', isEqualTo: familyId)
        .get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .toList();
  }

  Future<void> updateCategory(CategoryModel category) {
    return _categories.doc(category.id).update(category.toFirestore());
  }

  Future<void> deleteCategory(String id) {
    return _categories.doc(id).delete();
  }
}
