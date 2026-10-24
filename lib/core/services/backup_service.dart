import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/category_model.dart';

class BackupData {
  final Map<String, dynamic> data;
  final DateTime createdAt;

  BackupData({required this.data, required this.createdAt});

  // Firestore Timestamps are not JSON; store them as ISO-8601 strings.
  String toJson() => jsonEncode(
    {'version': 1, 'createdAt': createdAt.toIso8601String(), 'data': data},
    toEncodable: (value) {
      if (value is Timestamp) return value.toDate().toIso8601String();
      if (value is DateTime) return value.toIso8601String();
      return value.toString();
    },
  );

  factory BackupData.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return BackupData(
      data: map['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class BackupService {
  Future<BackupData> collectData(
    FirestoreDataSource ds,
    String familyId,
  ) async {
    final results = await Future.wait([
      ds.getIncomes(familyId),
      ds.getExpenses(familyId),
      ds.getSavings(familyId),
      ds.getAllBudgets(familyId),
      ds.getDebts(familyId),
      ds.getCategories(familyId),
    ]);

    return BackupData(
      data: {
        'incomes': (results[0] as List<IncomeModel>)
            .map((e) => e.toFirestore())
            .toList(),
        'expenses': (results[1] as List<ExpenseModel>)
            .map((e) => e.toFirestore())
            .toList(),
        'savings': (results[2] as List<SavingModel>)
            .map((e) => e.toFirestore())
            .toList(),
        'budgets': (results[3] as List<BudgetModel>)
            .map((e) => e.toFirestore())
            .toList(),
        'debts': (results[4] as List<DebtModel>)
            .map((e) => e.toFirestore())
            .toList(),
        'categories': (results[5] as List<CategoryModel>)
            .map((e) => e.toFirestore())
            .toList(),
      },
      createdAt: DateTime.now(),
    );
  }

  Future<File> saveToFile(BackupData backup) async {
    final dir = await getTemporaryDirectory();
    // The share target may still be reading the newest file, so clear older
    // copies here instead of right after sharing.
    for (final old in dir.listSync().whereType<File>()) {
      final name = old.uri.pathSegments.last;
      if (name.startsWith('backup_') && name.endsWith('.json')) {
        try {
          old.deleteSync();
        } catch (_) {}
      }
    }
    final file = File(
      '${dir.path}/backup_${backup.createdAt.millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(backup.toJson());
    return file;
  }

  Future<void> shareBackup(BackupData backup) async {
    final file = await saveToFile(backup);
    await Share.shareXFiles([XFile(file.path)], text: 'Backup Family Finance');
  }

  Future<BackupData> readFromFile(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    return BackupData.fromJson(json);
  }
}
