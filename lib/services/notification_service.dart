import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ✅ SIMULATION DE FCM TOKEN
  String get fcmToken => "N/A (Notifications DB activées)";

  // ✅ MÉTHODE INIT (pour initialiser les notifications)
  Future<void> init() async {
    print('🔔 Initialisation du service de notifications...');
    // Les notifications locales sont déjà initialisées dans main.dart
    // Cette méthode peut être utilisée pour initialiser Firebase si besoin
    print('✅ Service de notifications initialisé');
  }

  // ✅ CRÉER UNE NOTIFICATION (Base de données)
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ Notification DB créée pour $userId');
      
      // ✅ Afficher aussi une notification locale immédiate
      await _showLocalNotification(title, message);
    } catch (e) {
      print('❌ Erreur création notification: $e');
    }
  }

  // ✅ AFFICHER NOTIFICATION LOCALE (Awesome Notifications)
  Future<void> _showLocalNotification(String title, String message) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'pharmalink_channel',
          title: title,
          body: message,
          notificationLayout: NotificationLayout.Default,
        ),
      );
      print('🔔 Notification locale affichée');
    } catch (e) {
      print(' Erreur notification locale: $e');
    }
  }

  // ✅ MÉTHODE DE TEST (Pour debug_screen)
  Future<void> sendTestNotification() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Créer une notification de test dans la DB et sur le téléphone
    await createNotification(
      userId: user.id,
      type: 'test',
      title: '🧪 Notification de Test',
      message: 'Ceci est une notification de test envoyée depuis le mode débogage.',
      data: {'test': true},
    );
  }

  // ✅ NOTIFIER LE PATIENT QUAND LE PHARMACIEN RÉPOND
  Future<void> notifyPatientWhenPharmacistReplies({
    required String patientId,
    required String pharmacyName,
    required String conversationId,
    required String messageContent,
  }) async {
    await createNotification(
      userId: patientId,
      type: 'message',
      title: 'Nouveau message de $pharmacyName',
      message: messageContent.length > 50 
          ? '${messageContent.substring(0, 50)}...' 
          : messageContent,
      data: {
        'conversationId': conversationId,
        'pharmacyName': pharmacyName,
        'type': 'pharmacist_reply',
      },
    );
  }

  // ✅ NOTIFIER LE PHARMACIEN QUAND LE PATIENT ENVOIE UN MESSAGE
  Future<void> notifyPharmacistWhenPatientSendsMessage({
    required String pharmacyId,
    required String patientName,
    required String conversationId,
    required String messageContent,
  }) async {
    await createNotification(
      userId: pharmacyId,
      type: 'message',
      title: 'Nouveau message de $patientName',
      message: messageContent.length > 50 
          ? '${messageContent.substring(0, 50)}...' 
          : messageContent,
      data: {
        'conversationId': conversationId,
        'patientName': patientName,
        'type': 'patient_message',
      },
    );
  }

  // ✅ OBTENIR LES NOTIFICATIONS NON LUES
  Future<List<Map<String, dynamic>>> getUnreadNotifications(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('read', false)
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur récupération notifications: $e');
      return [];
    }
  }

  // ✅ MARQUER TOUTES LES NOTIFICATIONS COMME LUES
  Future<void> markAllAsRead(String userId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);
      
      print('✅ Toutes les notifications marquées comme lues');
    } catch (e) {
      print('❌ Erreur markAllAsRead: $e');
    }
  }
}