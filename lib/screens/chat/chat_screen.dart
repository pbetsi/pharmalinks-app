import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String pharmacyName;
  final String medicineName;
  final String? patientId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.pharmacyName,
    required this.medicineName,
    this.patientId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final ImagePicker _picker = ImagePicker();
  
  String _patientDisplayName = 'Patient';
  String _patientEmail = '';

  @override
  void initState() {
    super.initState();
    
    // ✅ VALIDATION AU DÉMARRAGE - Logs pour débogage
    print('🔍 Initialisation du chat...');
    print('   - Conversation ID: ${widget.conversationId}');
    print('   - Pharmacy Name: ${widget.pharmacyName}');
    print('   - Medicine Name: ${widget.medicineName}');
    print('   - Patient ID: ${widget.patientId}');
    
    if (widget.conversationId.isEmpty) {
      print('⚠️ WARNING: Conversation ID est vide!');
    }
    
    _loadPatientInfo();
    _loadMessages();
    _setupRealtimeListener();
  }

  Future<void> _loadPatientInfo() async {
    final patientId = widget.patientId;
    if (patientId == null) return;

    try {
      print('🔍 Chargement infos patient: $patientId');
      
      var userData = await Supabase.instance.client
          .from('users')
          .select('full_name, email')
          .eq('id', patientId)
          .maybeSingle();

      if (userData == null || (userData is Map && userData.isEmpty)) {
        final authData = await Supabase.instance.client
            .from('auth.users')
            .select('email, raw_user_meta_data')
            .eq('id', patientId)
            .single();
        
        if (mounted) {
          setState(() {
            _patientEmail = authData['email'] ?? '';
            final fullName = authData['raw_user_meta_data']?['full_name'];
            _patientDisplayName = fullName ?? _patientEmail.split('@').first ?? 'Patient';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _patientDisplayName = userData['full_name'] ?? 
                                 userData['email']?.split('@').first ?? 
                                 'Patient';
            _patientEmail = userData['email'] ?? '';
          });
        }
      }
      
      print('✅ Patient: $_patientDisplayName ($_patientEmail)');
    } catch (e) {
      print('⚠️ Erreur chargement infos patient: $e');
      if (mounted) {
        setState(() {
          _patientDisplayName = widget.pharmacyName;
        });
      }
    }
  }

  void _setupRealtimeListener() {
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true)
        .listen((data) {
      print('🔄 Stream messages: ${data.length} messages');
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
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
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      print('📦 Chargement messages pour conversation: ${widget.conversationId}');
      
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('✅ Messages chargés: ${response.length}');
      
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ FONCTION CORRIGÉE - Avec Optimistic UI pour affichage instantané
  Future<void> _sendMessage({String? content, String? messageType, String? attachmentUrl}) async {
    if (_isSending) return;
    
    final messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && attachmentUrl == null) return;

    setState(() => _isSending = true);

    // 1. ✅ OPTIMISTIC UI : Afficher le message localement TOUT DE SUITE
    // Cela évite d'attendre la réponse du serveur pour l'afficher
    final tempMessage = {
      'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
      'content': messageContent,
      'created_at': DateTime.now().toIso8601String(),
      'sender_id': Supabase.instance.client.auth.currentUser?.id,
      'message_type': messageType ?? 'text',
      'attachment_url': attachmentUrl,
      'read': false,
    };

    // Ajout temporaire à la liste pour affichage immédiat
    setState(() {
      _messages.add(tempMessage);
    });
    
    // Scroll vers le bas immédiatement
    _scrollToBottom();
    _messageController.clear();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // ✅ VALIDER L'UTILISATEUR
      if (user == null) {
        print('❌ Utilisateur non connecté');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Veuillez vous connecter'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // ✅ VALIDER LE CONVERSATION ID
      if (widget.conversationId.isEmpty) {
        print('❌ Conversation ID est vide!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Conversation invalide'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('📤 Envoi du message...');
      print('   - Conversation ID: ${widget.conversationId}');
      print('   - Sender ID: ${user.id}');
      print('   - Contenu: $messageContent');

      // ✅ INSÉRER LE MESSAGE dans Supabase
      final response = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': widget.conversationId,
            'sender_id': user.id,
            'content': messageContent,
            'message_type': messageType ?? 'text',
            'attachment_url': attachmentUrl,
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select(); // Important : pour récupérer l'ID réel créé par la DB

      print('✅ Message envoyé: ${response.length} ligne(s)');

      // 2. ✅ REMPLACER le message temporaire par le message réel de la DB
      if (response.isNotEmpty && mounted) {
        setState(() {
          // On retire le message temporaire
          _messages.removeWhere((m) => m['id'] == tempMessage['id']);
          // On ajoute le message confirmé avec son vrai ID
          _messages.addAll(List<Map<String, dynamic>>.from(response));
        });
        _scrollToBottom();
      }

      // Mettre à jour la conversation
      await Supabase.instance.client
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);
        
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      print('❌ Type: ${e.runtimeType}');
      
      // En cas d'erreur, on retire le message temporaire pour ne pas perdre la cohérence
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempMessage['id']);
        });
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

  // ✅ FONCTION HELPER : Scroll vers le bas
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

      if (recipientId == null) return;

      print('🔔 Création notification pour: $recipientId');

      String senderName;
      if (isPharmacist) {
        final pharmacy = await Supabase.instance.client
            .from('pharmacies')
            .select('name')
            .eq('id', user.id)
            .single();
        senderName = pharmacy['name'] ?? 'Pharmacie';
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
        'message': message['content']?.length > 50 
            ? '${message['content'].toString().substring(0, 50)}...' 
            : message['content'],
        'data': {
          'conversationId': widget.conversationId,
          'messageId': message['id'],
          'senderId': user.id,
          'senderName': senderName,
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Notification créée');
    } catch (e) {
      print('❌ Erreur création notification: $e');
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
        await Supabase.instance.client
            .from('messages')
            .update({
              'content': editedContent.trim(),
              'edited': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', messageId);
        
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('id', messageId)
            .select();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Message supprimé'),
              backgroundColor: Colors.green,
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
            if (message['attachment_url'] != null)
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.teal),
                title: const Text('Voir l\'image'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    _viewImage(message['attachment_url']);
                  }
                },
              ),
            if (message['attachment_url'] != null)
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('Télécharger l\'image'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    _downloadImage(message['attachment_url']);
                  }
                },
              ),
            if (isMyMessage) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.teal),
                title: const Text('Modifier le message'),
                subtitle: const Text('Appuyez longuement pour modifier'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted && message['content'] != null && message['content'].isNotEmpty) {
                    _editMessage(message['id'], message['content']);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer le message'),
                subtitle: const Text('Appuyez longuement pour supprimer'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    _deleteMessage(message['id']);
                  }
                },
              ),
            ],
            if (!isMyMessage)
              ListTile(
                leading: const Icon(Icons.info, color: Colors.grey),
                title: const Text('Message reçu'),
                subtitle: Text('Envoyé le ${_formatDate(message['created_at'])}'),
              ),
          ],
        ),
      ),
    );
  }

  void _viewImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Image'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadImage(imageUrl),
              ),
            ],
          ),
          body: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 100, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Image non disponible'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _downloadImage(String imageUrl) {
    try {
      showDialog(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Image'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📥 Sur mobile: appui long sur l\'image pour télécharger'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Image non disponible'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur téléchargement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors du téléchargement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Envoi en cours...'),
              ],
            ),
          ),
        );
      }

      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      
      await Supabase.instance.client.storage
          .from('prescriptions')
          .uploadBinary('chat_${widget.conversationId}/$fileName', bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('prescriptions')
          .getPublicUrl('chat_${widget.conversationId}/$fileName');

      await _sendMessage(
        content: source == ImageSource.camera ? '📸 Photo' : '📎 Image',
        messageType: 'image',
        attachmentUrl: publicUrl,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Erreur envoi image: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _patientDisplayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun message encore\nCommencez la conversation !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAttachmentOptions,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Envoyer une image'),
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

                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(msg),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.teal : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isMe ? Colors.teal.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (msg['message_type'] == 'image' && msg['attachment_url'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          msg['attachment_url'],
                                          width: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 200,
                                              height: 150,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image),
                                            );
                                          },
                                        ),
                                      ),
                                    if (msg['message_type'] == 'image' && msg['attachment_url'] != null)
                                      const SizedBox(height: 8),
                                    if (msg['content'] != null && msg['content'].isNotEmpty)
                                      Text(
                                        msg['content'],
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(msg['created_at']),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe ? Colors.white70 : Colors.grey.shade600,
                                          ),
                                        ),
                                        if (msg['edited'] == true)
                                          Text(
                                            ' (modifié)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe ? Colors.white70 : Colors.grey.shade600,
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
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.teal),
                  onPressed: _isSending ? null : _showAttachmentOptions,
                  tooltip: 'Envoyer une image',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
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