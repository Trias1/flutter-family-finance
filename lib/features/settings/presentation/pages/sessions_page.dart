import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/session_service.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/settings/presentation/widgets/profile_sections.dart';

/// Phones and browsers signed in to the account, newest first.
final sessionDevicesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
      if (uid == null) return Stream.value(const []);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .snapshots()
          .map((snap) {
            final list = [
              for (final d in snap.docs) {...d.data(), 'id': d.id},
            ];
            int seen(Map<String, dynamic> d) =>
                (d['lastSeenAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            list.sort((a, b) => seen(b).compareTo(seen(a)));
            return list;
          })
          .handleError((_) {});
    });

final thisDeviceIdProvider = FutureProvider.autoDispose<String?>(
  (ref) => SessionService.thisDeviceId(),
);

const _os = {
  'Win32': 'Windows',
  'Win64': 'Windows',
  'MacIntel': 'Mac',
  'Linux x86_64': 'Linux',
};

bool _isWeb(Map<String, dynamic> d) => d['platform'] == 'web';

String deviceName(Map<String, dynamic> d) {
  final brand = (d['brand'] ?? '').toString().trim();
  final model = (d['model'] ?? '').toString().trim();
  if (_isWeb(d)) {
    return [brand, _os[model] ?? model].where((s) => s.isNotEmpty).join(' · ');
  }
  final name = '$brand $model'.trim();
  return name.isEmpty ? 'Android' : name;
}

String _details(Map<String, dynamic> d) {
  final version = (d['androidVersion'] ?? '').toString().trim();
  final app = (d['appVersionName'] ?? '').toString().trim();
  return [
    if (_isWeb(d)) 'Browser' else if (version.isNotEmpty) 'Android $version',
    if (app.isNotEmpty) 'Family Finance $app',
  ].join(' · ');
}

String _ago(Map<String, dynamic> d, bool isId) {
  final at = (d['lastSeenAt'] as Timestamp?)?.toDate();
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 2) return isId ? 'aktif sekarang' : 'active now';
  if (diff.inHours < 1) {
    return isId ? '${diff.inMinutes} menit lalu' : '${diff.inMinutes} min ago';
  }
  if (diff.inDays < 1) {
    return isId ? '${diff.inHours} jam lalu' : '${diff.inHours} h ago';
  }
  if (isId) return '${diff.inDays} hari lalu';
  return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
}

class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  Future<bool> _confirm(
    BuildContext context,
    bool isId, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _end(
    BuildContext context,
    String uid,
    List<Map<String, dynamic>> devices,
    bool isId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SessionService.signOutDevices(uid, [
        for (final d in devices) d['id'] as String,
      ]);
      // Off the list now; the device signs itself out when it sees the mark
      // (at once if it is open, otherwise the next time it opens).
      final batch = FirebaseFirestore.instance.batch();
      for (final d in devices) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('devices')
              .doc(d['id'] as String),
        );
      }
      await batch.commit();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? (devices.length == 1
                      ? '${deviceName(devices.first)} dikeluarkan.'
                      : '${devices.length} perangkat dikeluarkan.')
                : (devices.length == 1
                      ? '${deviceName(devices.first)} was signed out.'
                      : '${devices.length} devices were signed out.'),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Gagal. Cek koneksi lalu coba lagi.'
                : 'That did not work. Check your connection and retry.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _openSession(
    BuildContext context,
    String uid,
    Map<String, dynamic> d,
    bool isId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DeviceIcon(device: d, size: 64),
              const SizedBox(height: 12),
              Text(
                deviceName(d),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  _details(d),
                  _ago(d, isId),
                ].where((s) => s.isNotEmpty).join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final ok = await _confirm(
                      context,
                      isId,
                      title: isId ? 'Keluarkan perangkat?' : 'Sign out device?',
                      body: isId
                          ? '${deviceName(d)} akan keluar dari akunmu: langsung kalau aplikasinya sedang terbuka, atau saat dibuka berikutnya.'
                          : '${deviceName(d)} will be signed out of your account: right away if the app is open there, otherwise the next time it opens.',
                      action: isId ? 'Keluarkan' : 'Sign out',
                    );
                    if (ok && context.mounted)
                      await _end(context, uid, [d], isId);
                  },
                  child: Text(
                    isId ? 'Keluarkan perangkat ini' : 'Sign out this device',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isId = ref.watch(localeProvider).languageCode == 'id';
    final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
    final devicesAsync = ref.watch(sessionDevicesProvider);
    final thisId = ref.watch(thisDeviceIdProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    final devices = devicesAsync.valueOrNull ?? const [];
    final current = devices.where((d) => d['id'] == thisId).toList();
    final others = devices.where((d) => d['id'] != thisId).toList();

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );

    Widget group(List<Widget> children) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: groupColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );

    return Scaffold(
      appBar: AppBar(title: Text(isId ? 'Perangkat aktif' : 'Active sessions')),
      body: devicesAsync.isLoading && devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                label(isId ? 'Perangkat ini' : 'This device'),
                group([
                  for (final d in current)
                    _SessionTile(
                      device: d,
                      subtitle: _details(d),
                      trailing: Text(
                        isId ? 'online' : 'online',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.incomeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (current.isEmpty)
                    ListTile(
                      title: Text(isId ? 'Perangkat ini' : 'This device'),
                      subtitle: Text(
                        isId
                            ? 'Belum tercatat. Buka ulang aplikasi.'
                            : 'Not registered yet. Reopen the app.',
                      ),
                    ),
                  if (others.isNotEmpty && uid != null) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.front_hand_outlined,
                        color: AppTheme.errorColor,
                      ),
                      title: Text(
                        isId
                            ? 'Keluarkan semua perangkat lain'
                            : 'Terminate all other sessions',
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                      onTap: () async {
                        final ok = await _confirm(
                          context,
                          isId,
                          title: isId
                              ? 'Keluarkan semua perangkat lain?'
                              : 'Terminate all other sessions?',
                          body: isId
                              ? '${others.length} perangkat lain akan keluar dari akunmu. Perangkat ini tetap masuk.'
                              : '${others.length} other devices will be signed out of your account. This one stays signed in.',
                          action: isId ? 'Keluarkan' : 'Terminate',
                        );
                        if (ok && context.mounted) {
                          await _end(context, uid, others, isId);
                        }
                      },
                    ),
                  ],
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    isId
                        ? 'Keluarkan perangkat yang tidak kamu kenali, lalu ganti password.'
                        : "Sign out any device you don't recognise, then change your password.",
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (others.isNotEmpty) ...[
                  label(isId ? 'Perangkat lain' : 'Other sessions'),
                  group([
                    for (var i = 0; i < others.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _SessionTile(
                        device: others[i],
                        subtitle: _details(others[i]),
                        trailing: Text(
                          _ago(others[i], isId),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: uid == null
                            ? null
                            : () => _openSession(context, uid, others[i], isId),
                      ),
                    ],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      isId
                          ? 'Ketuk perangkat untuk mengeluarkannya.'
                          : 'Tap a session to terminate it.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final Map<String, dynamic> device;
  final double size;
  const _DeviceIcon({required this.device, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final web = _isWeb(device);
    final color = web ? const Color(0xFF3D6189) : const Color(0xFF2F7354);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        web ? Icons.laptop_rounded : Icons.phone_android_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> device;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SessionTile({
    required this.device,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _DeviceIcon(device: device),
      title: Text(
        deviceName(device),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: trailing,
    );
  }
}
