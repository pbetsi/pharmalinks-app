import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final _client = Supabase.instance.client;

  // ============================================
  // CONVERSATIONS
  // ============================================
  
  /// Créer ou récupérer une conversation existante
  Future<String> getOrCreateConversation({
    required String pharmacyId,
    required String medicineId,
    String? reservationId,
  }) async {
    final patientId = _client.auth.currentUser?.id;
    if (patientId == null) throw Exception('Utilisateur non connecté');

    // Chercher conversation existante
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('patient_id', patientId)
        .eq('pharmacy_id', pharmacyId)
        .eq('medicine_id', medicineId)
        .eq('status', 'open')
        .maybeSingle();

    if (existing != null) {
      return existing['id'];
    }

    // Créer nouvelle conversation
    final response = await _client
        .from('conversations')
        .insert({
          'patient_id': patientId,
          'pharmacy_id': pharmacyId,
          'medicine_id': medicineId,
          'reservation_id': reservationId,
          'status': 'open',
        })
        .select('id')
        .single();

    return response['id'];
  }

  /// Lister les conversations d'un utilisateur
  Future<List<Map<String, dynamic>>> getConversations({
    bool isPharmacist = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    if (isPharmacist) {
      // 1. Récupérer l'ID de la pharmacie
      final pharmacyResult = await _client
          .from('pharmacies')
          .select('id')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      
      if (pharmacyResult == null) {
        print('⚠️ Aucune pharmacie trouvée');
        return [];
      }
      
      final pharmacyId = pharmacyResult['id'] as String;
      print('🏥 Pharmacy ID: $pharmacyId');

      // 2. Récupérer les conversations
      final response = await _client
          .from('conversations')
          .select('''
            id,
            status,
            last_message_at,
            created_at,
            patient_id,
            pharmacy_id,
            medicine_id,
            users!conversations_patient_id_fkey(full_name, email),
            medicines(name),
            messages(content, created_at, read)
          ''')
          .eq('pharmacy_id', pharmacyId)
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
      
    } else {
      // Patient : voir SES conversations
      final response = await _client
          .from('conversations')
          .select('''
            id,
            status,
            last_message_at,
            created_at,
            patient_id,
            pharmacy_id,
            medicine_id,
            pharmacies(name, address),
            medicines(name),
            messages(content, created_at, read)
          ''')
          .eq('patient_id', userId)
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    }
  }

  // ============================================
  // MESSAGES
  // ============================================
  
  /// 🔔 Déclencher une notification push via Edge Function
  Future<void> _triggerNotification({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      print('🔔 Déclenchement notification...');
      
      final response = await _client.functions.invoke(
        'send-chat-notification',
        body: {
          'message_id': messageId,
          'conversation_id': conversationId,
        },
      );
      
      if (response.status >= 400) {
        print('❌ Erreur notification: ${response.data}');
      } else {
        print('✅ Notification déclenchée avec succès');
      }
    } catch (e) {
      print('⚠️ Erreur appel Edge Function: $e');
      // Ne pas bloquer l'envoi du message si la notification échoue
    }
  }

  /// Envoyer un message + déclencher notification push
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('Utilisateur non connecté');

    // 1. Insérer le message dans la base
    final response = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content.trim(),
      'message_type': messageType,
      'attachment_url': attachmentUrl,
      'read': false,
    }).select('id').single();

    final messageId = response['id'] as String;
    
    // 2. ✅ Déclencher la notification push (asynchrone, ne bloque pas l'UI)
    // On utilise un Future.microtask pour ne pas attendre la notification
    Future.microtask(() {
      _triggerNotification(
        messageId: messageId,
        conversationId: conversationId,
      );
    });
  }

Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
  return _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true)
      .map((data) {
        // Filtrage manuel
        return data
            .where((msg) => 
                msg['conversation_id'] == conversationId && 
                msg['deleted'] == false
            )
            .toList();
      });
}

  /// Marquer les messages comme lus
  Future<void> markMessagesAsRead(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('messages')
        .update({'read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('read', false);
  }

  // ============================================
  // UTILITAIRES
  // ============================================
  
  /// Vérifier si l'utilisateur est pharmacien
  Future<bool> isUserPharmacist() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    
    return response?['role'] == 'pharmacie';
  }

  /// Obtenir les infos d'une conversation
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final response = await _client
        .from('conversations')
        .select('''
          id,
          status,
          patient_id,
          pharmacy_id,
          pharmacies(name, address, phone),
          medicines(name, dosage)
        ''')
        .eq('id', conversationId)
        .maybeSingle();
    
    return response;
  }

  /// Obtenir les informations d'un utilisateur
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('full_name, email, phone')
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Erreur récupération user info: $e');
      return null;
    }
  }
}