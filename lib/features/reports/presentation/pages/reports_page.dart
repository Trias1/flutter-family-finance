import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/reports/presentation/providers/report_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _selectedFilter = 'Bulanan';
  bool _isExporting = false;

  bool get _isId => Localizations.localeOf(context).languageCode == 'id';
  AppStrings get _s => AppStrings(Localizations.localeOf(context));

  /// Display label for a filter key (keys stay Indonesian for logic).
  String _filterLabel(String filter) {
    final s = _s;
    switch (filter) {
      case 'Harian':
        return s.daily;
      case 'Mingguan':
        return s.weekly;
      case 'Tahunan':
        return s.yearly;
      case 'Bulanan':
        return s.monthly;
      default:
        return filter;
    }
  }

  String get _reportTitle => _isId ? 'Laporan Keuangan' : 'Financial Report';
  String get _exportFailedMsg => _isId
      ? 'Gagal export laporan. Coba lagi.'
      : "Couldn't export the report. Try again.";

  List<IncomeModel> _filterIncomes(List<IncomeModel> incomes, String filter) {
    final now = DateTime.now();
    return incomes.where((i) => _inRange(i.date, filter, now)).toList();
  }

  List<ExpenseModel> _filterExpenses(
    List<ExpenseModel> expenses,
    String filter,
  ) {
    final now = DateTime.now();
    return expenses.where((e) => _inRange(e.date, filter, now)).toList();
  }

  bool _inRange(DateTime date, String filter, DateTime now) {
    switch (filter) {
      case 'Harian':
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case 'Mingguan':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd);
      case 'Tahunan':
        return date.year == now.year;
      case 'Bulanan':
      default:
        return date.year == now.year && date.month == now.month;
    }
  }

  double _sumIncomes(List<IncomeModel> list) =>
      list.fold<double>(0, (s, e) => s + e.amount);
  double _sumExpenses(List<ExpenseModel> list) =>
      list.fold<double>(0, (s, e) => s + e.amount);

  Future<void> _exportCSV(ReportData data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    bool dialogShowing = false;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isId ? 'Menyiapkan CSV...' : 'Preparing CSV...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      dialogShowing = true;
    }
    final isId = _isId;
    final s = _s;
    final reportTitle = _reportTitle;
    final exportFailedMsg = _exportFailedMsg;
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        isId
            ? 'Tipe,Kategori,Catatan,Jumlah,Tanggal'
            : 'Type,Category,Note,Amount,Date',
      );
      for (final i in data.filteredIncomes) {
        buffer.writeln(
          '${s.income},${i.category},${i.note ?? ''},${i.amount.toStringAsFixed(0)},${_formatDate(i.date)}',
        );
      }
      for (final e in data.filteredExpenses) {
        buffer.writeln(
          '${s.expense},${e.category},${e.note ?? ''},${e.amount.toStringAsFixed(0)},${_formatDate(e.date)}',
        );
      }
      final dir = await _getTemporaryDirectory();
      final file = File('${dir.path}/laporan_keuangan.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: reportTitle);
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(exportFailedMsg),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        });
      }
    } finally {
      if (dialogShowing && context.mounted) Navigator.of(context).pop();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPDF(ReportData data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    bool dialogShowing = false;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isId ? 'Menyiapkan PDF...' : 'Preparing PDF...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      dialogShowing = true;
    }
    final isId = _isId;
    final s = _s;
    final reportTitle = _reportTitle;
    final periodLabel = _filterLabel(_selectedFilter);
    final exportFailedMsg = _exportFailedMsg;
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                text: reportTitle,
                textStyle: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Paragraph(
                text: '${isId ? 'Periode' : 'Period'}: $periodLabel',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),
              pw.Header(level: 1, text: isId ? 'Ringkasan' : 'Summary'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStat(
                    isId ? 'Total Pemasukan' : 'Total Income',
                    CurrencyFormatter.format(data.filteredTotalIncome),
                    PdfColors.green,
                  ),
                  _pdfStat(
                    isId ? 'Total Pengeluaran' : 'Total Expenses',
                    CurrencyFormatter.format(data.filteredTotalExpense),
                    PdfColors.red,
                  ),
                  _pdfStat(
                    isId ? 'Saldo' : 'Balance',
                    CurrencyFormatter.format(data.filteredTotalBalance),
                    PdfColors.blue,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                text: isId ? 'Pemasukan per Kategori' : 'Income by Category',
              ),
              _pdfCategoryTable(
                context,
                data.filteredIncomes
                    .map((i) => _Cat(i.category, i.amount))
                    .toList(),
                s.income,
                isId,
              ),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                text: isId
                    ? 'Pengeluaran per Kategori'
                    : 'Expenses by Category',
              ),
              _pdfCategoryTable(
                context,
                data.filteredExpenses
                    .map((e) => _Cat(e.category, e.amount))
                    .toList(),
                s.expense,
                isId,
              ),
              pw.SizedBox(height: 20),
              pw.Header(level: 1, text: isId ? 'Transaksi' : 'Transactions'),
              _pdfTransactionTable(context, data, s, isId),
            ];
          },
        ),
      );
      final dir = await _getTemporaryDirectory();
      final file = File('${dir.path}/laporan_keuangan.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: reportTitle);
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(exportFailedMsg),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        });
      }
    } finally {
      if (dialogShowing && context.mounted) Navigator.of(context).pop();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _printPDF(ReportData data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final isId = _isId;
    final s = _s;
    final reportTitle = _reportTitle;
    final periodLabel = _filterLabel(_selectedFilter);
    final printFailedMsg = isId
        ? 'Gagal print laporan. Coba lagi.'
        : "Couldn't print the report. Try again.";
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                text: reportTitle,
                textStyle: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Paragraph(
                text: '${isId ? 'Periode' : 'Period'}: $periodLabel',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),
              pw.Header(level: 1, text: isId ? 'Ringkasan' : 'Summary'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStat(
                    isId ? 'Total Pemasukan' : 'Total Income',
                    CurrencyFormatter.format(data.filteredTotalIncome),
                    PdfColors.green,
                  ),
                  _pdfStat(
                    isId ? 'Total Pengeluaran' : 'Total Expenses',
                    CurrencyFormatter.format(data.filteredTotalExpense),
                    PdfColors.red,
                  ),
                  _pdfStat(
                    isId ? 'Saldo' : 'Balance',
                    CurrencyFormatter.format(data.filteredTotalBalance),
                    PdfColors.blue,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                text: isId ? 'Pemasukan per Kategori' : 'Income by Category',
              ),
              _pdfCategoryTable(
                context,
                data.filteredIncomes
                    .map((i) => _Cat(i.category, i.amount))
                    .toList(),
                s.income,
                isId,
              ),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                text: isId
                    ? 'Pengeluaran per Kategori'
                    : 'Expenses by Category',
              ),
              _pdfCategoryTable(
                context,
                data.filteredExpenses
                    .map((e) => _Cat(e.category, e.amount))
                    .toList(),
                s.expense,
                isId,
              ),
              pw.SizedBox(height: 20),
              pw.Header(level: 1, text: isId ? 'Transaksi' : 'Transactions'),
              _pdfTransactionTable(context, data, s, isId),
            ];
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        format: PdfPageFormat.a4,
        name: reportTitle,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(printFailedMsg),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Table _pdfCategoryTable(
    pw.Context context,
    List<_Cat> cats,
    String type,
    bool isId,
  ) {
    final totals = <String, double>{};
    for (final c in cats) {
      totals[c.name] = (totals[c.name] ?? 0) + c.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Text(
              isId ? 'Kategori' : 'Category',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              isId ? 'Jumlah' : 'Amount',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '%',
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        ...entries.map(
          (e) => pw.TableRow(
            children: [
              pw.Text(e.key),
              pw.Text(CurrencyFormatter.format(e.value)),
              pw.Text(
                '${(e.value / cats.fold<double>(0, (s, c) => s + c.amount) * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Table _pdfTransactionTable(
    pw.Context context,
    ReportData data,
    AppStrings s,
    bool isId,
  ) {
    final items = <_Trans>[
      ...data.filteredIncomes.map(
        (i) => _Trans(
          s.income,
          i.category,
          i.note ?? '',
          CurrencyFormatter.format(i.amount),
          _formatDate(i.date),
        ),
      ),
      ...data.filteredExpenses.map(
        (e) => _Trans(
          s.expense,
          e.category,
          e.note ?? '',
          CurrencyFormatter.format(e.amount),
          _formatDate(e.date),
        ),
      ),
    ];
    items.sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) return pw.Table(children: []);
    final header = isId
        ? ['Tipe', 'Kategori', 'Catatan', 'Jumlah', 'Tanggal']
        : ['Type', 'Category', 'Note', 'Amount', 'Date'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: header
              .map(
                (h) => pw.Text(
                  h,
                  style: const pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              )
              .toList(),
        ),
        ...items
            .take(50)
            .map(
              (t) => pw.TableRow(
                children: [
                  pw.Text(t.type, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(t.category, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(t.note, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(t.amount, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(t.date, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Directory> _getTemporaryDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final reportAsync = ref.watch(reportProvider(familyId));
    final isId = _isId;
    final s = _s;

    return reportAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat laporan...' : 'Loading report...',
      ),
      error: (e, _) => AppErrorWidget(
        message: s.loadFailed,
        onRetry: () => ref.invalidate(reportProvider(familyId)),
      ),
      data: (data) {
        final filteredIncomes = _filterIncomes(data.incomes, _selectedFilter);
        final filteredExpenses = _filterExpenses(
          data.expenses,
          _selectedFilter,
        );
        final filteredTotalIncome = _sumIncomes(filteredIncomes);
        final filteredTotalExpense = _sumExpenses(filteredExpenses);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(reportProvider(familyId)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppConstants.reportFilters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            _filterLabel(filter),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedFilter = filter),
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _SummaryRow(
                  totalIncome: filteredTotalIncome,
                  totalExpense: filteredTotalExpense,
                  totalBalance: filteredTotalIncome - filteredTotalExpense,
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: isId
                      ? 'Cashflow ${_filterLabel(_selectedFilter)}'
                      : '${_filterLabel(_selectedFilter)} Cashflow',
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  child: SizedBox(
                    height: 220,
                    child: _CashflowChart(
                      incomes: filteredIncomes,
                      expenses: filteredExpenses,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: isId ? 'Pemasukan per Kategori' : 'Income by Category',
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  child: SizedBox(
                    height: 220,
                    child: _IncomePieChart(incomes: filteredIncomes),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: isId
                      ? 'Pengeluaran per Kategori'
                      : 'Expenses by Category',
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  child: SizedBox(
                    height: 220,
                    child: _ExpensePieChart(expenses: filteredExpenses),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: isId ? 'Progres Goals' : 'Goals Progress'),
                const SizedBox(height: 12),
                _ChartCard(
                  child: SizedBox(
                    height: 220,
                    child: _SavingsChart(savings: data.savings),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportCSV(data),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text(
                          'Export CSV',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportPDF(data),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.expenseColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printPDF(data),
                        icon: const Icon(Icons.print, size: 18),
                        label: Text(
                          isId ? 'Cetak' : 'Print',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.savingsColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double totalBalance;
  const _SummaryRow({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalBalance,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = AppStrings(locale);
    final isId = locale.languageCode == 'id';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            label: s.income,
            amount: totalIncome,
            color: AppTheme.incomeColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _Stat(
            label: s.expense,
            amount: totalExpense,
            color: AppTheme.expenseColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _Stat(
            label: isId ? 'Saldo' : 'Balance',
            amount: totalBalance,
            color: AppTheme.savingsColor,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _Stat({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CashflowChart extends StatelessWidget {
  final List<IncomeModel> incomes;
  final List<ExpenseModel> expenses;
  const _CashflowChart({required this.incomes, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayMap = <int, double>{};
    final dayExpMap = <int, double>{};
    for (int d = 1; d <= daysInMonth; d++) {
      dayMap[d] = 0;
      dayExpMap[d] = 0;
    }
    for (final i in incomes) {
      dayMap[i.date.day] = (dayMap[i.date.day] ?? 0) + i.amount;
    }
    for (final e in expenses) {
      dayExpMap[e.date.day] = (dayExpMap[e.date.day] ?? 0) + e.amount;
    }

    final maxVal = [
      dayMap.values.fold(0.0, max),
      dayExpMap.values.fold(0.0, max),
    ].reduce(max);
    final effectiveMax = maxVal == 0 ? 1000000.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: effectiveMax,
        barGroups: List.generate(daysInMonth, (i) {
          final day = i + 1;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: dayMap[day] ?? 0,
                color: AppTheme.incomeColor,
                width: 4,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              BarChartRodData(
                toY: -(dayExpMap[day] ?? 0),
                color: AppTheme.expenseColor,
                width: 4,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final d = v.toInt();
                if (d % 5 == 1 || d == daysInMonth)
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: effectiveMax / 4,
        ),
      ),
    );
  }
}

class _IncomePieChart extends StatelessWidget {
  final List<IncomeModel> incomes;
  const _IncomePieChart({required this.incomes});

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final i in incomes) {
      totals[i.category] = (totals[i.category] ?? 0) + i.amount;
    }
    final isId = Localizations.localeOf(context).languageCode == 'id';
    if (totals.isEmpty) {
      return Center(
        child: Text(isId ? 'Belum ada pemasukan' : 'No income yet'),
      );
    }
    final colors = [
      AppTheme.incomeColor,
      Colors.green,
      Colors.teal,
      Colors.lightGreen,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.brown,
    ];
    return PieChart(
      PieChartData(
        sections: totals.entries
            .toList()
            .asMap()
            .entries
            .map(
              (e) => PieChartSectionData(
                value: e.value.value,
                title:
                    '${e.value.key}\n${CurrencyFormatter.formatWithoutSymbol(e.value.value)}',
                color: colors[e.key % colors.length],
                radius: 45,
                titleStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
            .toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _ExpensePieChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final isId = Localizations.localeOf(context).languageCode == 'id';
    if (totals.isEmpty) {
      return Center(
        child: Text(isId ? 'Belum ada pengeluaran' : 'No expenses yet'),
      );
    }
    final colors = [
      AppTheme.expenseColor,
      AppTheme.warningColor,
      AppTheme.savingsColor,
      AppTheme.primaryColor,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.brown,
      Colors.cyan,
    ];
    return PieChart(
      PieChartData(
        sections: totals.entries
            .toList()
            .asMap()
            .entries
            .map(
              (e) => PieChartSectionData(
                value: e.value.value,
                title:
                    '${e.value.key}\n${CurrencyFormatter.formatWithoutSymbol(e.value.value)}',
                color: colors[e.key % colors.length],
                radius: 45,
                titleStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
            .toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      ),
    );
  }
}

class _SavingsChart extends StatelessWidget {
  final List<SavingModel> savings;
  const _SavingsChart({required this.savings});

  @override
  Widget build(BuildContext context) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    if (savings.isEmpty) {
      return Center(child: Text(isId ? 'Belum ada Goals' : 'No Goals yet'));
    }
    return ListView.separated(
      itemCount: savings.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, i) {
        final s = savings[i];
        final pct = s.targetAmount > 0
            ? (s.currentAmount / s.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${CurrencyFormatter.formatWithoutSymbol(s.currentAmount)} / ${CurrencyFormatter.formatWithoutSymbol(s.targetAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 1 ? AppTheme.incomeColor : AppTheme.savingsColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cat {
  final String name;
  final double amount;
  _Cat(this.name, this.amount);
}

class _Trans {
  final String type;
  final String category;
  final String note;
  final String amount;
  final String date;
  _Trans(this.type, this.category, this.note, this.amount, this.date);
}
