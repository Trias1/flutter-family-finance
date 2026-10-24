import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppUpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final String apkUrl;
  final bool forceUpdate;
  final String releaseNotes;

  const AppUpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkUrl,
    required this.forceUpdate,
    required this.releaseNotes,
  });
}

class AppDeviceInfo {
  final String brand;
  final String model;
  final String androidVersion;
  final String appVersionName;
  final int appVersionCode;

  const AppDeviceInfo({
    required this.brand,
    required this.model,
    required this.androidVersion,
    required this.appVersionName,
    required this.appVersionCode,
  });
}

class AppUpdateService {
  AppUpdateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _apkUrl = 'https://finance.west-solutions.web.id/FamilyFinance.apk';
  static const _playStoreUrl = null;
  final FirebaseFirestore _firestore;

  Future<void> registerDevice(String uid) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final previousId = prefs.getString('device_registry_id');
    // The same phone keeps the same id after a reinstall, so it shows once
    // in Active sessions; a random id is only the fallback.
    final deviceId = await _stableDeviceId() ?? previousId ?? const Uuid().v4();
    if (deviceId != previousId) {
      await prefs.setString('device_registry_id', deviceId);
    }

    final deviceInfo = await getCurrentDeviceInfo();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final devices = _firestore
        .collection('users')
        .doc(uid)
        .collection('devices');

    await devices.doc(deviceId).set({
      'deviceId': deviceId,
      'platform': 'android',
      'brand': deviceInfo.brand,
      'model': deviceInfo.model,
      'androidVersion': deviceInfo.androidVersion,
      'appVersionName': deviceInfo.appVersionName,
      'appVersionCode': deviceInfo.appVersionCode,
      'fcmToken': fcmToken,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'privacyNote':
          'Basic device info only. No contacts, files, photos, location, phone number, or IMEI are collected.',
    }, SetOptions(merge: true));

    // Entries this phone left before (older random ids, reinstalls): same
    // brand and model on Android, but another id.
    try {
      final mine = await devices.where('platform', isEqualTo: 'android').get();
      for (final doc in mine.docs) {
        final d = doc.data();
        if (doc.id != deviceId &&
            d['brand'] == deviceInfo.brand &&
            d['model'] == deviceInfo.model) {
          await doc.reference.delete();
        }
      }
    } catch (_) {
      // Offline; tidied up on a later start.
    }
  }

  static const _deviceChannel = MethodChannel('family_finance/device');

  /// A hash of Android's per-app id: the same on this phone after a
  /// reinstall, and not the IMEI or anything that names the phone.
  Future<String?> _stableDeviceId() async {
    try {
      final androidId = await _deviceChannel.invokeMethod<String>('androidId');
      if (androidId == null || androidId.isEmpty) return null;
      return const Uuid().v5(
        '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
        'family-finance:$androidId',
      );
    } catch (_) {
      return null;
    }
  }

  /// Marks this phone as active right now for the admin's "online" count.
  /// Touches only lastSeenAt on the doc registerDevice created.
  Future<void> heartbeat(String uid) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_registry_id');
    if (deviceId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Offline or not registered yet; the next beat or app start catches up.
    }
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final doc = await _firestore.collection('app_config').doc('android').get();

    final data = doc.data() ?? {};
    final latestCode = (data['latestVersionCode'] as num?)?.toInt() ?? 0;

    if (latestCode <= currentCode) return null;

    return AppUpdateInfo(
      latestVersionCode: latestCode,
      latestVersionName: data['latestVersionName']?.toString() ?? '',
      apkUrl: data['apkUrl']?.toString() ?? _apkUrl,
      forceUpdate: data['forceUpdate'] == true,
      releaseNotes: data['releaseNotes']?.toString() ?? 'Versi baru tersedia.',
    );
  }

  Future<AppDeviceInfo> getCurrentDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    return AppDeviceInfo(
      brand: androidInfo.brand,
      model: androidInfo.model,
      androidVersion: androidInfo.version.release,
      appVersionName: packageInfo.version,
      appVersionCode: int.tryParse(packageInfo.buildNumber) ?? 0,
    );
  }
}
