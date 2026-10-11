import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/services/bank_notification_parser.dart';
import 'package:family_finance_manager/core/services/statement_parser.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// The Android side: Notification access status and the waiting
/// notifications kept by the listener.
class BankNotifications {
  static const _channel = MethodChannel('family_finance/bank_notifications');

  static Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android's own screen; only the user can turn access on or off.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> takePending() async {
    try {
      final raw = await _channel.invokeMethod<String>('takePending');
      final list = jsonDecode(raw ?? '[]') as List;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

final bankAccessProvider = FutureProvider<bool>(
  (ref) => BankNotifications.isEnabled(),
);

/// A notification read as a transaction, waiting for the user to check it.
class BankInboxEntry {
  final BankNotification source;
  final StatementItem item;
  const BankInboxEntry(this.source, this.item);
}

final bankInboxProvider =
    StateNotifierProvider<BankInboxNotifier, List<BankInboxEntry>>((ref) {
      final uid = ref.watch(
        authNotifierProvider.select((u) => u.valueOrNull?.id),
      );
      return BankInboxNotifier(uid);
    });

/// "Waiting to be checked": kept on this phone per account, never uploaded
/// until the user saves rows on the review screen.
class BankInboxNotifier extends StateNotifier<List<BankInboxEntry>> {
  BankInboxNotifier(this._uid) : super(const []) {
    if (_uid != null) refresh();
  }

  final String? _uid;
  List<Map<String, dynamic>> _raw = [];
  bool _busy = false;

  String get _key => 'bank_inbox_$_uid';

  /// Reads what the listener kept since last time and adds the ones that
  /// look like transactions.
  Future<void> refresh() async {
    if (_uid == null || _busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        _raw = (jsonDecode(prefs.getString(_key) ?? '[]') as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        _raw = [];
      }
      final known = {for (final r in _raw) r['id']};
      final fresh = await BankNotifications.takePending();
      for (final r in fresh) {
        if (known.contains(r['id'])) continue;
        if (BankNotificationParser.parse(BankNotification.fromJson(r)) ==
            null) {
          continue;
        }
        _raw.add(r);
      }
      // Keep the last 100; older ones are surely handled by now.
      if (_raw.length > 100) _raw = _raw.sublist(_raw.length - 100);
      await prefs.setString(_key, jsonEncode(_raw));
      _publish();
    } finally {
      _busy = false;
    }
  }

  /// Rows reviewed (saved or skipped) leave the inbox.
  Future<void> remove(Iterable<String> ids) async {
    final gone = ids.toSet();
    _raw = _raw.where((r) => !gone.contains(r['id'])).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_raw));
    _publish();
  }

  void _publish() {
    final entries = <BankInboxEntry>[];
    for (final r in _raw) {
      final source = BankNotification.fromJson(r);
      final item = BankNotificationParser.parse(source);
      if (item != null) entries.add(BankInboxEntry(source, item));
    }
    entries.sort((a, b) => a.source.time.compareTo(b.source.time));
    if (mounted) state = entries;
  }
}
