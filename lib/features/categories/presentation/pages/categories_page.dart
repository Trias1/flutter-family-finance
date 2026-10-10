import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/constants/app_constants.dart';
import 'package:family_finance_manager/core/locale/app_strings.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/widgets/error_widget.dart';
import 'package:family_finance_manager/core/widgets/loading_widget.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';

/// Friendly, localized text for an error returned by `addCategory`.
/// The provider returns either a duplicate-name message or raw exception
/// text, so the duplicate case is detected here and everything else is
/// shown as a generic save failure.
String _addCategoryErrorText(
  BuildContext context,
  String name,
  List<String> existingNames,
) {
  final s = AppStrings(Localizations.localeOf(context));
  final isId = s.locale.languageCode == 'id';
  final isDuplicate = existingNames.any(
    (n) => n.toLowerCase() == name.toLowerCase(),
  );
  if (isDuplicate) {
    return isId
        ? 'Kategori "$name" sudah ada'
        : 'Category "$name" already exists';
  }
  return s.saveFailed;
}

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  void _showAddCategoryChoice(BuildContext context, WidgetRef ref) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isId ? 'Tambah Kategori' : 'Add Category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.trending_up),
                label: Text(isId ? 'Kategori Pemasukan' : 'Income Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.incomeColor,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddCategoryDialog(context, 'income');
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.trending_down),
                label: Text(isId ? 'Kategori Pengeluaran' : 'Expense Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseColor,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddCategoryDialog(context, 'expense');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, String type) {
    final controller = TextEditingController();
    final familyId = ref.read(financeScopeIdProvider);
    final categories =
        ref.read(categoryStreamProvider(familyId)).valueOrNull ?? [];
    final existingNames = categories
        .where((c) => c.type == type)
        .map((c) => c.name)
        .toList();
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == 'income'
              ? (isId ? 'Tambah Pemasukan' : 'Add Income Category')
              : (isId ? 'Tambah Pengeluaran' : 'Add Expense Category'),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isId ? 'Nama Kategori' : 'Category Name',
            hintText: isId ? 'Contoh: Bonus, Belanja' : 'e.g. Bonus, Groceries',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final error = await ref
                  .read(categoryNotifierProvider.notifier)
                  .addCategory(familyId, type, name, existingNames);
              if (ctx.mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        _addCategoryErrorText(ctx, name, existingNames),
                      ),
                    ),
                  );
                } else {
                  Navigator.pop(ctx);
                }
              }
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(financeScopeIdProvider);
    final categoriesAsync = ref.watch(categoryStreamProvider(familyId));
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';

    return categoriesAsync.when(
      loading: () => LoadingWidget(
        message: isId ? 'Memuat kategori...' : 'Loading categories...',
      ),
      error: (e, _) => AppErrorWidget(
        message: isId
            ? 'Kategori belum bisa dimuat. Coba lagi ya.'
            : "Couldn't load your categories. Try again.",
        onRetry: () => ref.invalidate(categoryStreamProvider(familyId)),
      ),
      data: (categories) {
        final incomeCustom = categories
            .where((c) => c.type == 'income')
            .toList();
        final expenseCustom = categories
            .where((c) => c.type == 'expense')
            .toList();
        final incomeDefault = AppConstants.incomeCategories.where(
          (n) => !incomeCustom.any((c) => c.name == n),
        );
        final expenseDefault = AppConstants.expenseCategories.where(
          (n) => !expenseCustom.any((c) => c.name == n),
        );

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _SectionTitle(title: s.income),
                const SizedBox(height: 8),
                ...incomeCustom.map((c) => _CategoryTile(category: c)),
                ...incomeDefault.map(
                  (n) => _DefaultCategoryTile(name: n, type: 'income'),
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: s.expense),
                const SizedBox(height: 8),
                ...expenseCustom.map((c) => _CategoryTile(category: c)),
                ...expenseDefault.map(
                  (n) => _DefaultCategoryTile(name: n, type: 'expense'),
                ),
                const SizedBox(height: 80),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: () => _showAddCategoryChoice(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
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

class _DefaultCategoryTile extends StatelessWidget {
  final String name;
  final String type;
  const _DefaultCategoryTile({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == 'income'
        ? AppTheme.incomeColor
        : AppTheme.expenseColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'income' ? Icons.trending_up : Icons.trending_down,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  Localizations.localeOf(context).languageCode == 'id'
                      ? 'Bawaan'
                      : 'Default',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock,
            size: 16,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final dynamic category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = category.type == 'income'
        ? AppTheme.incomeColor
        : AppTheme.expenseColor;
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              category.type == 'income'
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isId ? 'Kustom' : 'Custom',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(isId ? 'Hapus Kategori' : 'Delete Category'),
                  content: Text(
                    isId
                        ? 'Hapus "${category.name}"?'
                        : 'Delete "${category.name}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(s.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                      ),
                      child: Text(s.delete),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref
                    .read(categoryNotifierProvider.notifier)
                    .deleteCategory(category.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddCategorySheet extends ConsumerStatefulWidget {
  final String type;
  final List<String> existingNames;
  const AddCategorySheet({
    super.key,
    required this.type,
    this.existingNames = const [],
  });

  @override
  ConsumerState<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<AddCategorySheet> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(Localizations.localeOf(context));
    final isId = s.locale.languageCode == 'id';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.type == 'income'
                ? (isId ? 'Tambah Kategori Pemasukan' : 'Add Income Category')
                : (isId
                      ? 'Tambah Kategori Pengeluaran'
                      : 'Add Expense Category'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: isId ? 'Nama Kategori' : 'Category Name',
              prefixIcon: const Icon(Icons.category),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    final name = _controller.text.trim();
                    if (name.isEmpty) return;
                    setState(() => _loading = true);
                    final familyId = ref.read(financeScopeIdProvider);
                    final error = await ref
                        .read(categoryNotifierProvider.notifier)
                        .addCategory(
                          familyId,
                          widget.type,
                          name,
                          widget.existingNames,
                        );
                    if (mounted) {
                      setState(() => _loading = false);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _addCategoryErrorText(
                                context,
                                name,
                                widget.existingNames,
                              ),
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == 'income'
                  ? AppTheme.incomeColor
                  : AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(s.add),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
