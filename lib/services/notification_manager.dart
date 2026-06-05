import 'dart:async'; // ✅ IMPORTANT: Requis pour StreamSubscription
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _reservationsSubscription;

  // Initialiser les notifications
  Future<void> initialize() async {
    // Demander la permission
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  // Écouter les nouveaux messages pour une pharmacie
  void listenForNewMessages(String pharmacyId) {
    // Annuler l'écoute précédente si elle existe
    _messagesSubscription?.cancel();

    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', '') // Sera mis à jour dynamiquement
        .listen((data) {
      for (var message in data) {
        _showMessageNotification(message);
      }
    });
  }

  // ✅ Écouter les nouvelles réservations - CORRIGÉ
  void listenForNewReservations(String pharmacyId) {
    _reservationsSubscription?.cancel();

    _reservationsSubscription = Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('pharmacy_id', pharmacyId)
       .listen((data) {
  // Filtrer manuellement les réservations pending
  final pendingReservations = data.where((r) => r['status'] == 'pending').toList();
  for (var reservation in pendingReservations) {
    _showReservationNotification(reservation);
  }
});
  }

  // Afficher une notification de message
  Future<void> _showMessageNotification(Map<String, dynamic> message) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'messages_channel',
          title: '📬 Nouveau Message',
          body: message['content']?.toString().substring(0, 100) ?? 'Vous avez reçu un nouveau message',
          notificationLayout: NotificationLayout.Default,
          payload: {
            'type': 'message',
            'conversation_id': message['conversation_id'],
          },
        ),
      );
    } catch (e) {
      print('❌ Erreur notification message: $e');
    }
  }

  // Afficher une notification de réservation
  Future<void> _showReservationNotification(Map<String, dynamic> reservation) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
          channelKey: 'reservations_channel',
          title: '📦 Nouvelle Réservation',
          body: 'Une nouvelle réservation est en attente de validation',
          notificationLayout: NotificationLayout.Default,
          payload: {
            'type': 'reservation',
            'reservation_id': reservation['id'],
          },
        ),
      );
    } catch (e) {
      print('❌ Erreur notification réservation: $e');
    }
  }

  // ✅ Obtenir le nombre de messages non lus - CORRIGÉ
  Future<int> getUnreadMessagesCount(String pharmacyId) async {
    try {
      final conversationIds = await _getPharmacyConversationIds(pharmacyId);
      
      if (conversationIds.isEmpty) return 0;

      // ✅ Ne pas utiliser count, compter manuellement
final response = await Supabase.instance.client
    .from('messages')
    .select('id')  // Pas de count
    .eq('read', false)
    .neq('sender_id', pharmacyId)
    .inFilter('conversation_id', conversationIds);

return response.length;  // Compter le résultat
    } catch (e) {
      print('❌ Erreur comptage messages non lus: $e');
      return 0;
    }
  }

  // Obtenir les IDs des conversations de la pharmacie
  Future<List<String>> _getPharmacyConversationIds(String pharmacyId) async {
    try {
      final response = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('pharmacy_id', pharmacyId);
      
      return response.map((c) => c['id'] as String).toList();
    } catch (e) {
      print('❌ Erreur récupération conversations: $e');
      return [];
    }
  }

  // Marquer les messages comme lus
  Future<void> markMessagesAsRead(List<String> messageIds) async {
    try {
      if (messageIds.isEmpty) return;
      
      await Supabase.instance.client
          .from('messages')
          .update({'read': true})
          .inFilter('id', messageIds); // ✅ CORRECTION: utiliser inFilter
    } catch (e) {
      print('❌ Erreur marquage comme lu: $e');
    }
  }

  // Nettoyer les écouteurs
  void dispose() {
    _messagesSubscription?.cancel();
    _reservationsSubscription?.cancel();
  }
}