import 'dart:async';
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
  static final _open = StreamController<void>.broadcast();
  static bool _listening = false;

  /// Fires when the "transactions to check" notification is tapped while
  /// the app is running.
  static Stream<void> get onOpenInbox {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'openInbox') _open.add(null);
      });
    }
    return _open.stream;
  }

  /// Whether the app was opened from that notification; asked once.
  static Future<bool> takeOpenRequest() async {
    try {
      return await _channel.invokeMethod<bool>('takeOpenRequest') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether this build can read notifications at all (debug builds only
  /// until the feature is finished).
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

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

  /// Keeps the app's notification in step with the "to check" list.
  static Future<void> syncSummary(int count) async {
    try {
      await _channel.invokeMethod<void>('syncSummary', {'count': count});
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

final bankFeatureProvider = FutureProvider<bool>(
  (ref) => BankNotifications.isAvailable(),
);

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
  Future<void>? _inFlight;

  String get _key => 'bank_inbox_$_uid';

  /// Reads what the listener kept since last time and adds the ones that
  /// look like transactions.
  /// A second call while one runs waits for it instead of starting again.
  Future<void> refresh() {
    if (_uid == null) return Future.value();
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
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
      if (BankNotificationParser.parse(BankNotification.fromJson(r)) == null) {
        continue;
      }
      _raw.add(r);
    }
    // Keep the last 100; older ones are surely handled by now.
    if (_raw.length > 100) _raw = _raw.sublist(_raw.length - 100);
    await prefs.setString(_key, jsonEncode(_raw));
    _publish();
  }

  /// Drops waiting rows that were already saved from this very notification
  /// (same direction, amount, day and the notification's text as the note),
  /// so a saved transaction never has to be checked twice. A second, real
  /// purchase of the same amount that day is kept.
  Future<void> pruneRecorded({
    required List<({DateTime date, double amount, String? note})> incomes,
    required List<({DateTime date, double amount, String? note})> expenses,
  }) async {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool recorded(
      StatementItem item,
      List<({DateTime date, double amount, String? note})> l,
    ) =>
        item.date != null &&
        l.any(
          (e) =>
              (e.amount - item.amount).abs() < 0.5 &&
              sameDay(e.date, item.date!) &&
              e.note?.trim() == item.description.trim(),
        );
    final done = [
      for (final e in state)
        if (recorded(e.item, e.item.isIncome ? incomes : expenses)) e.source.id,
    ];
    if (done.isNotEmpty) await remove(done);
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
    BankNotifications.syncSummary(entries.length);
  }
}
