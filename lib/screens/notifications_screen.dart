import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart'; // ✅ Import pour les notifications

class PharmacistChatScreen extends StatefulWidget {
  final String conversationId;
  final String patientName;
  final String patientId;

  const PharmacistChatScreen({
    super.key,
    required this.conversationId,
    required this.patientName,
    required this.patientId,
  });

  @override
  State<PharmacistChatScreen> createState() => _PharmacistChatScreenState();
}

class _PharmacistChatScreenState extends State<PharmacistChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _notificationService = NotificationService(); // ✅ Service de notifications
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _pharmacyName = 'Pharmacie';

  @override
  void initState() {
    super.initState();
    print('🔍 Patient ID reçu: ${widget.patientId}');
    print('🔍 Conversation ID reçu: ${widget.conversationId}');
    _loadPharmacyName();
    _loadMessages();
    _setupRealtimeListener();
  }

  Future<void> _loadPharmacyName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final pharmacy = await Supabase.instance.client
            .from('pharmacies')
            .select('name')
            .eq('id', user.id)
            .single();
        
        setState(() {
          _pharmacyName = pharmacy['name'] ?? 'Pharmacie';
        });
      }
    } catch (e) {
      print('⚠️ Erreur chargement nom pharmacie: $e');
    }
  }

  void _setupRealtimeListener() {
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .listen((data) {
      _loadMessages();
    });
  }

  // ✅ FONCTION CORRIGÉE : Marquer les notifications comme lues
  Future<void> _markNotificationsAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    print('🔔 Marquer notifications comme lues pour conversation: ${widget.conversationId}');

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('type', 'message')
          .eq('read', false)
          .select();
      
      // ✅ CORRECTION LIGNE 86 : Gestion sécurisée de response.length
      final count = response == null ? 0 : response.length;
      print('✅ Notifications mises à jour: $count');
    } catch (e) {
      print('❌ Erreur marquage notifications: $e');
    }
  }

  // ✅ FONCTION _loadMessages CORRIGÉE
  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('📦 Messages chargés: ${response.length}');

      setState(() {
        final existingIds = _messages.map((m) => m['id']).toSet();
        final newMessages = response.where((m) => !existingIds.contains(m['id'])).toList();
        _messages.addAll(newMessages);
        
        _messages.sort((a, b) {
          final dateA = DateTime.parse(a['created_at']);
          final dateB = DateTime.parse(b['created_at']);
          return dateA.compareTo(dateB);
        });
        
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      await _markMessagesAsRead();
      await _markNotificationsAsRead();
      
    } catch (e) {
      print('❌ Erreur chargement messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final unreadMessages = _messages.where((m) => 
      m['read'] == false && m['sender_id'] != user.id
    ).toList();

    for (final msg in unreadMessages) {
      await Supabase.instance.client
          .from('messages')
          .update({'read': true})
          .eq('id', msg['id']);
    }
  }

  // ✅ FONCTION CORRIGÉE : Créer notification pour le destinataire
  // ✅ CORRECTION LIGNE 156 : async ajouté et syntaxe Future<void> correcte
  Future<void> _createNotificationForRecipient(Map<String, dynamic> message) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final conversation = await Supabase.instance.client
          .from('conversations')
          .select('patient_id, pharmacy_id')
          .eq('id', widget.conversationId)
          .single();

      final isPharmacist = conversation['pharmacy_id'] == user.id;
      final recipientId = isPharmacist 
          ? conversation['patient_id']
          : conversation['pharmacy_id'];

      String senderName;
      if (isPharmacist) {
        final pharmacy = await Supabase.instance.client
            .from('pharmacies')
            .select('name')
            .eq('id', user.id)
            .single();
        senderName = pharmacy['name'];
      } else {
        final patientUser = await Supabase.instance.client
            .from('users')
            .select('full_name')
            .eq('id', user.id)
            .single();
        senderName = patientUser['full_name'] ?? 'Patient';
      }

      await Supabase.instance.client.from('notifications').insert({
        'user_id': recipientId,
        'type': 'message',
        'title': 'Nouveau message de $senderName',
        'message': message['content'],
        'data': {
          'conversationId': widget.conversationId,
          'medicineName': 'Discussion',
          'messageId': message['id'],
          'senderId': user.id,
          'senderName': senderName,
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Notification créée pour $recipientId avec senderId: ${user.id}');
    } catch (e) {
      print('❌ Erreur création notification: $e');
    }
  }

  // ✅ FONCTION _sendMessage CORRIGÉE
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      print('⚠️ Message vide');
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ Utilisateur non connecté');
        return;
      }

      print('📤 Pharmacien envoie: $content');
      print('📤 Pour patient: ${widget.patientId}');
      print('📤 Conversation: ${widget.conversationId}');

      final tempMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'content': content,
        'message_type': 'text',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _messages.add(tempMessage);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      final messageData = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': widget.conversationId,
            'sender_id': user.id,
            'content': content,
            'message_type': 'text',
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      print('✅ Message envoyé: ${messageData['id']}');

      if (widget.patientId.isNotEmpty) {
        try {
          final patientUser = await Supabase.instance.client
              .from('users')
              .select('id')
              .eq('id', widget.patientId)
              .single();
          
          print('👤 Patient user_id trouvé: ${patientUser['id']}');

          await Supabase.instance.client
              .from('notifications')
              .insert({
                'user_id': patientUser['id'],
                'type': 'message',
                'title': 'Nouveau message de $_pharmacyName',
                'message': content.length > 50 
                    ? '${content.substring(0, 50)}...' 
                    : content,
                'data': {
                  'conversationId': widget.conversationId,
                  'pharmacyName': _pharmacyName,
                  'pharmacyId': user.id,
                  'messageId': messageData['id'],
                  'type': 'pharmacist_reply',
                  'senderId': user.id,
                  'senderName': _pharmacyName,
                },
                'read': false,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select();

          print('✅ Notification créée');
        } catch (notifError) {
          print('❌ Erreur création notification: $notifError');
        }
      }

      await Supabase.instance.client
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);

      _messageController.clear();

      await Future.delayed(const Duration(milliseconds: 500));
      await _loadMessages();
      
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patientName),
            const Text(
              'Patient',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucun message encore',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final user = Supabase.instance.client.auth.currentUser;
                          final isMe = msg['sender_id'] == user?.id;

                          return Align(
                            alignment: isMe 
                                ? Alignment.centerRight 
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.teal : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['content'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe 
                                          ? Colors.white70 
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
      final unreadNotifications = data.where((n) => n['read'] == false).toList();
      
      setState(() {
        _notifications = unreadNotifications;
        _isLoading = false;
      });
    });
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final unreadNotifications = response.where((n) => n['read'] == false).toList();

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(unreadNotifications);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);
      _loadNotifications();
    } catch (e) {
      print('❌ Erreur markAll: $e');
    }
  }

  // ✅ FONCTION CORRIGÉE AVEC GESTION DES ANNULATIONS
  Future<void> _openNotification(Map<String, dynamic> notification) async {
    print('🔔 Clic sur notification');
    
    try {
      // 1. Marquer comme lu
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', notification['id']);

      final type = notification['type'] as String?;
      final data = notification['data'] as Map<String, dynamic>?;

      print('📦 Type: $type');
      print('📦 Data: $data');

      // ✅ GESTION DU TYPE order_cancelled
      if (type == 'order_cancelled' && mounted) {
        print('📦 Redirection vers /orders pour annulation');
        // Rediriger vers les commandes
        await Navigator.pushNamed(context, '/orders');
        if (mounted) {
          _loadNotifications();
        }
        return;
      }

      // Gestion des messages
      if (type == 'message' && data != null) {
        if (data == null) {
          print('❌ Data est null');
          return;
        }

        final conversationId = data['conversationId'] as String?;
        final senderId = data['senderId'] as String?;
        final senderName = (data['senderName'] ?? data['pharmacyName'] ?? 'Patient') as String;
        
        print('📱 Conversation ID: $conversationId');
        print('📱 Sender Name: $senderName');

        if (conversationId == null || conversationId.isEmpty) {
          print('❌ conversationId est vide!');
          return;
        }

        // Naviguer vers le chat du pharmacien
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PharmacistChatScreen(
                conversationId: conversationId,
                patientName: senderName,
                patientId: senderId ?? '',
              ),
            ),
          );
        }
      } 
      // Gestion des réservations
      else if (type == 'reservation' && mounted) {
        await Navigator.pushNamed(context, '/orders');
      }

      // 3. Recharger les notifications au retour
      if (mounted) {
        _loadNotifications();
      }
    } catch (e) {
      print('❌ Erreur: $e');
      print('❌ Stack: ${StackTrace.current}');
    }
  }

  // ✅ ICÔNES MISES À JOUR AVEC order_cancelled
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'message': 
        return Icons.chat_bubble_outline;
      case 'reservation': 
        return Icons.local_pharmacy;
      case 'order_cancelled':  // ✅ NOUVEAU CAS
        return Icons.cancel;
      default: 
        return Icons.notifications_none;
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return '${date.day}/${date.month}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notifications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.any((n) => n['read'] != true))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Tout lu', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune notification', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['read'] == true;
                      final type = n['type'] as String?;
                      
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openNotification(n),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              color: isRead ? Colors.white : Colors.teal.shade50,
                            ),
                            child: Row(
                              children: [
                                if (!isRead) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                // ✅ Icône selon le type de notification
                                Icon(
                                  _getNotificationIcon(type),
                                  color: isRead ? Colors.grey : Colors.teal.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title'] ?? 'Notification',
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                      if (n['message'] != null && (n['message'] as String).isNotEmpty)
                                        Text(
                                          n['message'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(n['created_at']),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}