import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';

final dashboardSectionsProvider = FutureProvider<Map<String, bool>>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'progress': prefs.getBool('dashboard_progress') ?? true,
    'calendar': prefs.getBool('dashboard_calendar') ?? true,
    'menu': prefs.getBool('dashboard_menu') ?? true,
    'recent': prefs.getBool('dashboard_recent') ?? true,
    'insights': prefs.getBool('dashboard_insights') ?? true,
  };
});

class DashboardSettingsPage extends ConsumerWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(dashboardSectionsProvider);
    final id = ref.watch(localeProvider).languageCode == 'id';

    return sections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(id ? 'Pengaturan gagal dimuat.' : "Couldn't load settings."),
      ),
      data: (values) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            id
                ? 'Pilih bagian yang mau ditampilkan di Dashboard.'
                : 'Choose what the Dashboard shows.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SectionSwitch(
            'progress',
            id ? 'Progress bulanan' : 'Monthly progress',
            values,
          ),
          _SectionSwitch(
            'calendar',
            id ? 'Kalender aktivitas' : 'Activity calendar',
            values,
          ),
          _SectionSwitch('menu', id ? 'Menu utama' : 'Main menu', values),
          _SectionSwitch(
            'insights',
            id
                ? 'Ringkasan (per anggota, kategori, hutang, perkiraan)'
                : 'Insights (members, categories, debts, outlook)',
            values,
          ),
          _SectionSwitch(
            'recent',
            id ? 'Transaksi terbaru' : 'Recent transactions',
            values,
          ),
        ],
      ),
    );
  }
}

class _SectionSwitch extends ConsumerWidget {
  final String keyName;
  final String title;
  final Map<String, bool> values;

  const _SectionSwitch(this.keyName, this.title, this.values);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      value: values[keyName] ?? true,
      title: Text(title),
      onChanged: (value) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('dashboard_$keyName', value);
        ref.invalidate(dashboardSectionsProvider);
      },
    );
  }
}
