import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dashboardSectionsProvider = FutureProvider<Map<String, bool>>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'progress': prefs.getBool('dashboard_progress') ?? true,
    'calendar': prefs.getBool('dashboard_calendar') ?? true,
    'menu': prefs.getBool('dashboard_menu') ?? true,
    'recent': prefs.getBool('dashboard_recent') ?? true,
  };
});

class DashboardSettingsPage extends ConsumerWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(dashboardSectionsProvider);

    return sections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (values) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pilih bagian yang mau ditampilkan di Dashboard.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SectionSwitch('progress', 'Progress Bulanan', values),
          _SectionSwitch('calendar', 'Kalender Aktivitas', values),
          _SectionSwitch('menu', 'Menu Utama', values),
          _SectionSwitch('recent', 'Transaksi Terbaru', values),
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
