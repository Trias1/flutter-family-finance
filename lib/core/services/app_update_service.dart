import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  AppUpdateService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _apkUrl = 'https://finance-family-prod.vercel.app/FamilyFinance.apk';
  static const _playStoreUrl = null;
  final FirebaseFirestore _firestore;

  Future<void> registerDevice(String uid) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_registry_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_registry_id', deviceId);
    }

    final deviceInfo = await getCurrentDeviceInfo();
    final fcmToken = await FirebaseMessaging.instance.getToken();

    await _firestore.collection('users').doc(uid).collection('devices').doc(deviceId).set({
      'deviceId': deviceId,
      'platform': 'android',
      'brand': deviceInfo.brand,
      'model': deviceInfo.model,
      'androidVersion': deviceInfo.androidVersion,
      'appVersionName': deviceInfo.appVersionName,
      'appVersionCode': deviceInfo.appVersionCode,
      'fcmToken': fcmToken,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'privacyNote': 'Basic device info only. No contacts, files, photos, location, phone number, or IMEI are collected.',
    }, SetOptions(merge: true));
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final doc = await _firestore.collection('app_config').doc('android').get();

    final data = doc.data() ?? {};
    final latestCode = (data['latestVersionCode'] as num?)?.toInt() ?? 0;

    // Always upsert Firestore with current version if it's newer
    if (!doc.exists || currentCode > latestCode) {
      await _firestore.collection('app_config').doc('android').set({
        'latestVersionCode': currentCode,
        'latestVersionName': packageInfo.version,
        'apkUrl': _apkUrl,
        'forceUpdate': data['forceUpdate'] == true,
        'releaseNotes': data['releaseNotes']?.toString() ?? 'Versi terbaru tersedia.',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

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
