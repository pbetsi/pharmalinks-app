import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';

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
  final _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _pharmacyName = 'Pharmacie';
  String _patientEmail = '';
  bool _isLoadingPatientInfo = true;

  @override
  void initState() {
    super.initState();
    print('🔍 Patient ID reçu: ${widget.patientId}');
    print('🔍 Conversation ID reçu: ${widget.conversationId}');
    _loadPharmacyName();
    _loadPatientInfo();
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
        
        if (mounted) {
          setState(() {
            _pharmacyName = pharmacy['name'] ?? 'Pharmacie';
          });
        }
      }
    } catch (e) {
      print('⚠️ Erreur chargement nom pharmacie: $e');
    }
  }

  // ✅ FONCTION CORRIGÉE : Utiliser la table 'users' au lieu de 'auth.users'
  Future<void> _loadPatientInfo() async {
    try {
      print('📧 Chargement infos patient: ${widget.patientId}');
      
      // ✅ Utiliser la table 'users' au lieu de 'auth.users'
      final userData = await Supabase.instance.client
          .from('users')
          .select('full_name, email')
          .eq('id', widget.patientId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _patientEmail = userData?['email'] ?? '';
          _isLoadingPatientInfo = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement infos patient: $e');
      if (mounted) {
        setState(() {
          _patientEmail = '';
          _isLoadingPatientInfo = false;
        });
      }
    }
  }

  void _setupRealtimeListener() {
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .listen((data) {
      print('🔄 Stream messages: ${data.length} messages');
      _loadMessages();
    });
  }

  Future<void> _markNotificationsAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('type', 'message')
          .eq('read', false)
          .select();
      
      final count = response == null ? 0 : response.length;
      print('✅ Notifications mises à jour: $count');
    } catch (e) {
      print('❌ Erreur marquage notifications: $e');
    }
  }

  // ✅ FONCTION CORRIGÉE : Rafraîchissement total
Future<void> _loadMessages() async {
  try {
    final response = await Supabase.instance.client
        .from('messages')
        .select('*')
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true);

    print('📦 Messages chargés: ${response.length}');

    if (mounted) {
      setState(() {
        // ✅ Remplacer entièrement la liste au lieu d'ajouter seulement les nouveaux
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Scroll vers le bas
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
    }
  } catch (e) {
    print('❌ Erreur chargement messages: $e');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  Future<void> _markMessagesAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final unreadMessages = _messages.where((m) => 
      m['read'] == false && m['sender_id'] != user.id
    ).toList();

    if (unreadMessages.isEmpty) return;

    try {
      print('📖 Marquage de ${unreadMessages.length} messages comme lus...');

      for (final msg in unreadMessages) {
        await Supabase.instance.client
            .from('messages')
            .update({'read': true})
            .eq('id', msg['id']);
      }

      await Supabase.instance.client
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
        
      print('✅ Messages marqués comme lus et conversation mise à jour');
      
    } catch (e) {
      print('❌ Erreur marquage comme lu: $e');
    }
  }

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

  // ✅ FONCTION CORRIGÉE : Envoi instantané avec rafraîchissement
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('📤 Envoi message: $content');

      // 1. Insérer le message
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'content': content,
        'message_type': 'text',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Message inséré en BDD');

      // 2. Créer notification pour le patient
      try {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': widget.patientId,
          'type': 'message',
          'title': 'Nouveau message de $_pharmacyName',
          'message': content.length > 50 
              ? '${content.substring(0, 50)}...' 
              : content,
          'data': {
            'conversationId': widget.conversationId,
            'pharmacyName': _pharmacyName,
            'pharmacyId': user.id,
            'senderId': user.id,
            'senderName': _pharmacyName,
            'type': 'pharmacist_reply',
          },
          'read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ Notification créée');
      } catch (notifError) {
        print('⚠️ Erreur notification: $notifError');
      }

      // 3. Mettre à jour conversation
      await Supabase.instance.client
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);

      // 4. Vider le champ
      _messageController.clear();
      
      // 5. ✅ RAFRAÎCHIR IMMÉDIATEMENT les messages
      await _loadMessages();
      
      print('✅ Message envoyé et affiché!');
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _editMessage(String messageId, String currentContent) async {
  final editController = TextEditingController(text: currentContent);
  
  final editedContent = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('✏️ Modifier le message'),
      content: TextField(
        controller: editController,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Votre message modifié',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            editController.dispose();
          },
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final newContent = editController.text.trim();
            if (newContent.isNotEmpty) {
              Navigator.pop(ctx, newContent);
            }
          },
          child: const Text('Modifier'),
        ),
      ],
    ),
  );

  if (editedContent != null && editedContent.trim().isNotEmpty && editedContent != currentContent) {
    try {
      print('✏️ Modification message: $messageId');
      
      final response = await Supabase.instance.client
          .from('messages')
          .update({
            'content': editedContent.trim(),
            'edited': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .select();

      print('✅ Message modifié: ${response.length} ligne(s) affectée(s)');
      
      // ✅ RAFRAÎCHIR IMMÉDIATEMENT
      if (mounted) {
        await _loadMessages();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Message modifié'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur modification: $e');
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
  
  editController.dispose();
}

  Future<void> _deleteMessage(String messageId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('🗑️ Supprimer le message ?'),
      content: const Text('Cette action est irréversible.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );

  if (confirm == true && mounted) {
    try {
      print('🗑️ Suppression message: $messageId');
      
      final response = await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .select();

      print('✅ Message supprimé: ${response.length} ligne(s) affectée(s)');

      // ✅ RAFRAÎCHIR IMMÉDIATEMENT
      if (mounted) {
        await _loadMessages();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Message supprimé'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur suppression: $e');
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
}
  void _showMessageOptions(Map<String, dynamic> message) {
    final user = Supabase.instance.client.auth.currentUser;
    final isMyMessage = message['sender_id'] == user?.id;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (isMyMessage) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.teal),
                title: const Text('Modifier le message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(message['id'], message['content']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer le message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message['id']);
                },
              ),
            ],
            ListTile(
              leading: Icon(
                message['read'] == true ? Icons.done_all : Icons.done,
                color: Colors.grey,
              ),
              title: Text(message['read'] == true ? 'Lu' : 'Non lu'),
              subtitle: Text('Envoyé le ${_formatDate(message['created_at'])}'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Patient',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_isLoadingPatientInfo)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_patientEmail.isNotEmpty)
              Text(
                _patientEmail,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              )
            else if (!_isLoadingPatientInfo)
              const Text(
                'Discussion',
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
                            const SizedBox(height: 8),
                            const Text(
                              'Commencez la conversation !',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    :ListView.builder(
  controller: _scrollController,
  padding: const EdgeInsets.all(16),
  itemCount: _messages.length,
  itemBuilder: (context, index) {
    final msg = _messages[index];
    final user = Supabase.instance.client.auth.currentUser;
    final isMe = msg['sender_id'] == user?.id;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            // ✅ CORRECTION : Vérifier si c'est une image
            if (msg['message_type'] == 'image' && msg['attachment_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  msg['attachment_url'],
                  width: 200, // Largeur de l'image
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Erreur chargement image"),
                    );
                  },
                ),
              ),
            
            // Affiche le texte s'il y en a un (ou le nom du fichier si c'est une image sans texte)
            if (msg['content'] != null && msg['content'].isNotEmpty) ...[
              if (msg['message_type'] == 'image') const SizedBox(height: 8),
              Text(
                msg['content'],
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ],
            
            // Heure et status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg['created_at']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe && msg['read'] == true) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 12, color: Colors.blue[300]),
                ],
              ],
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
                      hintText: _isSending ? 'Envoi en cours...' : 'Écrivez un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isSending ? Colors.grey[50] : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _isSending ? null : _sendMessage(),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isSending ? Colors.grey : Colors.teal,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _isSending ? null : _sendMessage,
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute}';
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