import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:family_finance_manager/core/constants/firestore_constants.dart';
import 'package:family_finance_manager/core/services/notification_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      _messaging.onTokenRefresh.listen(_saveToken);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  Future<void> _saveToken(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final existing = await FirebaseFirestore.instance
          .collection(FirestoreConstants.fcmTokens)
          .where('token', isEqualTo: token)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        await FirebaseFirestore.instance.collection(FirestoreConstants.fcmTokens).add({
          'token': token,
          'uid': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Family Finance';
    final body = message.notification?.body ?? '';
    await NotificationService().show(id: DateTime.now().millisecondsSinceEpoch % 2147483647, title: title, body: body);
  }

  Future<void> _handleMessageOpened(RemoteMessage message) async {}

  Future<String?> getToken() => _messaging.getToken();

  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Family Finance';
    final body = message.notification?.body ?? '';
    await NotificationService().show(id: DateTime.now().millisecondsSinceEpoch % 2147483647, title: title, body: body);
  }
}
