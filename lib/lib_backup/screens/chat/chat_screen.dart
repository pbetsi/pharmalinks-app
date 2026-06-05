import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String pharmacyName;
  final String medicineName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.pharmacyName,
    required this.medicineName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isPharmacist = false;
  
  // 👇 Informations du patient (affichées dans l'en-tête)
  String _patientEmail = 'Chargement...';
  String _patientPhone = '';
  String _patientName = '';

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadPatientInfo(); // Charger les infos du patient au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _checkRole() async {
    final isPharm = await _chatService.isUserPharmacist();
    setState(() => _isPharmacist = isPharm);
  }

  // 👇 Charger les informations du patient depuis la table users
  Future<void> _loadPatientInfo() async {
    try {
      // 1. Récupérer le patient_id depuis la conversation
      final conversation = await Supabase.instance.client
          .from('conversations')
          .select('patient_id')
          .eq('id', widget.conversationId)
          .single();

      final patientId = conversation['patient_id'];
      if (patientId == null) return;

      // 2. Récupérer les infos du patient depuis la table users
      final userData = await Supabase.instance.client
          .from('users')
          .select('full_name, email, phone')
          .eq('id', patientId)
          .single();

      if (mounted) {
        setState(() {
          _patientName = userData['full_name'] ?? '';
          _patientEmail = userData['email'] ?? 'Email non disponible';
          _patientPhone = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      print('❌ Erreur chargement infos patient: $e');
      if (mounted) {
        setState(() {
          _patientEmail = 'Erreur chargement';
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      _messageController.clear();
      _scrollToBottom();
      await _chatService.markMessagesAsRead(widget.conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // 📸 ENVOI D'IMAGES
  // ============================================

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📤 Envoi en cours...'),
            backgroundColor: Colors.teal,
          ),
        );
      }

      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      
      await Supabase.instance.client.storage
          .from('chat_attachments')
          .uploadBinary(
            'conversations/${widget.conversationId}/$fileName',
            bytes,
            fileOptions: FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('chat_attachments')
          .getPublicUrl('conversations/${widget.conversationId}/$fileName');

      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        content: source == ImageSource.camera ? '📸 Photo prise' : '📎 Image partagée',
        messageType: 'image',
        attachmentUrl: publicUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image envoyée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur envoi image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================
  // AFFICHAGE DES MESSAGES (avec support images)
  // ============================================

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final time = DateTime.parse(msg['created_at']).toLocal();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final messageType = msg['message_type'] ?? 'text';
    final attachmentUrl = msg['attachment_url'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Afficher l'image si c'est un message image
            if (messageType == 'image' && attachmentUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => _showImageFullscreen(attachmentUrl),
                  child: Image.network(
                    attachmentUrl,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isMe ? Colors.white70 : Colors.teal,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.red),
                      );
                    },
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            if (messageType == 'image') const SizedBox(height: 8),
            
            // Texte du message
            if (msg['content'] != null && msg['content'].isNotEmpty)
              Text(
                msg['content'],
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            
            const SizedBox(height: 4),
            
            // Timestamp et statut
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe && msg['read'] == true) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 14, color: Colors.blue[300]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Afficher l'image en plein écran
  void _showImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black54,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📥 Téléchargement...')),
                  );
                },
              ),
            ],
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // BUILD PRINCIPAL
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 AppBar MODIFIÉE : Email + Nom + Téléphone du patient
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email du patient (en gras, principal)
            Text(
              _patientEmail,
              style: const TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Nom et téléphone (plus petit, secondaire)
            if (_patientName.isNotEmpty || _patientPhone.isNotEmpty)
              Text(
                '${_patientName.isNotEmpty ? _patientName : ""}${_patientPhone.isNotEmpty ? " • 📞 " + _patientPhone : ""}',
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.white.withOpacity(0.9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConversationInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.streamMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}', 
                      style: const TextStyle(color: Colors.red)),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == Supabase.instance.client.auth.currentUser?.id;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Zone de saisie
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun message encore\nCommencez la conversation !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Bouton pièce jointe
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () => _showAttachmentOptions(),
            tooltip: 'Joindre un fichier',
          ),
          
          // Champ de texte
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Bouton envoyer
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _messageController.text.trim().isEmpty ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showConversationInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏥 ${widget.pharmacyName}'),
            const SizedBox(height: 8),
            Text('💊 ${widget.medicineName}'),
            const SizedBox(height: 16),
            const Text(
              'Conseils:\n• Soyez poli et précis\n• Les pharmaciens répondent sous 24h\n• En cas d\'urgence, appelez directement',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
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