import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signing out another device, like Telegram's active sessions. Firebase
/// cannot end one session on its own, so the user marks the device in
/// `users/{uid}/session_revocations/{deviceId}`; that device watches its own
/// mark, removes it and its device entry, and signs itself out.
class SessionService {
  static const remoteSignOutFlag = 'signed_out_remotely';

  static Future<String?> thisDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_registry_id');
  }

  static CollectionReference<Map<String, dynamic>> _marks(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('session_revocations');

  /// Asks [deviceIds] to sign out.
  static Future<void> signOutDevices(
    String uid,
    Iterable<String> deviceIds,
  ) async {
    final me = await thisDeviceId() ?? 'unknown';
    final batch = FirebaseFirestore.instance.batch();
    for (final id in deviceIds) {
      if (id == me) continue;
      batch.set(_marks(uid).doc(id), {
        'requestedAt': FieldValue.serverTimestamp(),
        'requestedBy': me,
      });
    }
    await batch.commit();
  }

  /// Calls [onSignedOut] once if another device asks this one to sign out,
  /// after clearing the mark and this device's entry.
  static Future<StreamSubscription<void>?> watch(
    String uid,
    Future<void> Function() onSignedOut,
  ) async {
    final me = await thisDeviceId();
    if (me == null) return null;
    var handled = false;
    return _marks(uid).doc(me).snapshots().handleError((_) {}).listen((
      snap,
    ) async {
      if (!snap.exists || handled) return;
      handled = true;
      try {
        await snap.reference.delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(me)
            .delete();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(remoteSignOutFlag, true);
      await onSignedOut();
    });
  }

  /// True once after this device was signed out from another one.
  static Future<bool> takeRemoteSignOutNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(remoteSignOutFlag) ?? false;
    if (value) await prefs.remove(remoteSignOutFlag);
    return value;
  }
}
