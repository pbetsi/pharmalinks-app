import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  
  // ✅ NOUVEAU : Informations du patient
  String _patientDisplayName = 'Patient';
  String _patientEmail = '';

  @override
  void initState() {
    super.initState();
    _loadPatientInfo();
    _loadMessages();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .listen((data) {
      print('🔄 Stream détecté: ${data.length} messages');
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('📦 Messages chargés: ${response.length}');

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'content': content,
        'message_type': 'text',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();

      await Supabase.instance.client
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
    } catch (e) {
      print('❌ Erreur envoi message: $e');
    }
  }

  // ✅ NOUVELLE FONCTION : Charger les informations du patient
  Future<void> _loadPatientInfo() async {
    if (widget.patientId.isEmpty) return;

    try {
      print('🔍 Chargement infos patient: ${widget.patientId}');
      
      var userData = await Supabase.instance.client
          .from('users')
          .select('full_name, email')
          .eq('id', widget.patientId)
          .maybeSingle();

      if (userData == null || userData.isEmpty) {
        final authData = await Supabase.instance.client
            .from('auth.users')
            .select('email, raw_user_meta_data')
            .eq('id', widget.patientId)
            .single();
        
        setState(() {
          _patientEmail = authData['email'] ?? '';
          final fullName = authData['raw_user_meta_data']?['full_name'];
          _patientDisplayName = fullName ?? _patientEmail.split('@').first ?? 'Patient';
        });
      } else {
        setState(() {
          _patientDisplayName = userData['full_name'] ?? userData['email']?.split('@').first ?? 'Patient';
          _patientEmail = userData['email'] ?? '';
        });
      }
      
      print('✅ Patient: $_patientDisplayName ($_patientEmail)');
    } catch (e) {
      print('⚠️ Erreur chargement infos patient: $e');
      setState(() {
        _patientDisplayName = 'Patient';
      });
    }
  }

  // ✅ NOUVELLE FONCTION : Modifier un message
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
          TextButton(
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
        
        await Supabase.instance.client
            .from('messages')
            .update({
              'content': editedContent.trim(),
              'edited': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', messageId);

        await _loadMessages();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Message modifié'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur modification: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erreur lors de la modification'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    editController.dispose();
  }

  // ✅ FONCTION : Supprimer un message
  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer le message ?'),
        content: const Text(
          'Cette action est irréversible. Le message sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        print('🗑️ Suppression du message: $messageId');
        
        final response = await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('id', messageId)
            .select();

        print('✅ Message supprimé: ${response.length} ligne(s)');

        if (mounted) {
          await _loadMessages();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {});
          }
          
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

  // ✅ Menu contextuel pour les messages
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
              const Divider(height: 1),
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
              leading: const Icon(Icons.info, color: Colors.grey),
              title: const Text('Détails du message'),
              subtitle: Text('Envoyé le ${_formatDate(message['created_at'])}'),
            ),
          ],
        ),
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
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ AFFICHER LE NOM DU PATIENT
            Text(
              _patientDisplayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            // ✅ AFFICHER L'EMAIL SI DISPONIBLE
            if (_patientEmail.isNotEmpty)
              Text(
                _patientEmail,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              )
            else
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

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showMessageOptions(msg),
                              onLongPress: () => _showMessageOptions(msg),
                              onSecondaryTap: () => _showMessageOptions(msg),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: isMe 
                                      ? MainAxisAlignment.end 
                                      : MainAxisAlignment.start,
                                  children: [
                                    // ✅ BOUTON MENU pour mes messages
                                    if (isMe) ...[
                                      MouseRegion(
                                        child: GestureDetector(
                                          onTap: () => _showMessageOptions(msg),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.more_vert,
                                              size: 18,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    
                                    // ✅ BULLE DE MESSAGE
                                    Flexible(
                                      child: Container(
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
                                                // ✅ Indicateur "modifié"
                                                if (msg['edited'] == true)
                                                  Text(
                                                    ' (modifié)',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isMe ? Colors.white70 : Colors.grey[600],
                                                    ),
                                                  ),
                                                if (isMe && msg['read'] == true) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.done_all,
                                                    size: 12,
                                                    color: Colors.blue[300],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    if (!isMe) const SizedBox(width: 40),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Zone de saisie
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}