import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';  // ← Pour Colors
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import '../firebase_options.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _isInitialized = false;
  String? _fcmToken;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialiser Firebase
      await Firebase.initializeApp(  // ← Ligne 23
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialisé');

      // 2. Initialiser Awesome Notifications
      await AwesomeNotifications().initialize(
        'resource://drawable/ic_launcher',
        [
          NotificationChannel(
            channelKey: 'high_importance_channel',
            channelName: 'Messages Pharmalink',
            channelDescription: 'Notifications de nouveaux messages et réservations',
            importance: NotificationImportance.High,
            defaultColor: const Color(0xFF00897B),  // ← Ligne 38
            ledColor: Colors.white,                  // ← Ligne 39
            playSound: true,
            enableVibration: true,
          ),
        ],
        debug: kDebugMode,
      );
      print('✅ Awesome Notifications initialisé');

      // 3. Demander les permissions
      await _requestPermissions();

      // 4. Gérer les tokens et messages
      await _setupTokenHandling();
      await _setupForegroundMessaging();
      await _setupBackgroundMessaging();

      _isInitialized = true;
      print('✅ NotificationService initialisé');
    } catch (e) {
      print('❌ Erreur initialisation: $e');
    }
  }

  Future<void> _requestPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    print('✅ Permissions: $isAllowed');
  }

  Future<void> _setupTokenHandling() async {
    _fcmToken = await _messaging.getToken();
    print('📱 FCM Token: $_fcmToken');

    if (_fcmToken != null) {
      await _saveFcmTokenToSupabase(_fcmToken!);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveFcmTokenToSupabase(newToken);
    });
  }

  Future<void> _saveFcmTokenToSupabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({
              'fcm_token': token,
              'fcm_token_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }
    } catch (e) {
      print('❌ Erreur sauvegarde token: $e');
    }
  }

  Future<void> _setupForegroundMessaging() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📩 Message foreground: ${message.messageId}');
      await _showLocalNotification(message);
    });
  }

  Future<void> _setupBackgroundMessaging() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification cliquée');
      _handleNotificationTap(message.data['conversation_id']);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App lancée depuis notification');
      _handleNotificationTap(initialMessage.data['conversation_id']);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    if (notification == null) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notification.hashCode,
        channelKey: 'high_importance_channel',
        title: notification.title ?? 'Nouveau message',
        body: notification.body ?? 'Vous avez un nouveau message',
        notificationLayout: NotificationLayout.Default,
        payload: data.map((key, value) => MapEntry(key, value.toString())),  // ← Ligne 155
      ),
    );
  }

  void _handleNotificationTap(String? conversationId) {
    if (conversationId == null) return;
    print('🎯 Navigation vers conversation: $conversationId');
  }

  Future<void> sendTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'high_importance_channel',
        title: '🔔 Pharmalink Africa',
        body: 'Les notifications fonctionnent !',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  Future<void> unsubscribe() async {
    try {
      await _messaging.deleteToken();
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': null})
            .eq('id', user.id);
      }
      print('✅ Désabonné');
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }

  String? get fcmToken => _fcmToken;
}