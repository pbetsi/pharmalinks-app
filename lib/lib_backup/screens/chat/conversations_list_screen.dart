import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _chatService = ChatService();
  bool _isPharmacist = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isPharm = await _chatService.isUserPharmacist();
    setState(() {
      _isPharmacist = isPharm;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPharmacist ? 'Messages reçus' : 'Mes conversations'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getConversations(isPharmacist: _isPharmacist).asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final conversations = snapshot.data ?? [];
          
          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _buildConversationTile(conv);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _isPharmacist 
              ? 'Aucune conversation pour le moment'
              : 'Commencez une conversation depuis une recherche de médicament',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final pharmacy = conv['pharmacies'] as Map<String, dynamic>?;
    final medicine = conv['medicines'] as Map<String, dynamic>?;
    final lastMessage = conv['messages'] as List?;
    final lastMsgContent = lastMessage?.isNotEmpty == true 
        ? lastMessage![0]['content'] as String?
        : null;
    
    final lastMsgTime = conv['last_message_at'] != null
        ? DateTime.parse(conv['last_message_at']).toLocal()
        : DateTime.parse(conv['created_at']).toLocal();
    
    final timeStr = _formatTime(lastMsgTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Icon(Icons.local_pharmacy, color: Colors.teal.shade700),
        ),
        title: Text(
          pharmacy?['name'] ?? 'Pharmacie',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medicine != null)
              Text('💊 ${medicine['name']}', 
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            if (lastMsgContent != null)
              Text(
                lastMsgContent.length > 50 
                  ? '${lastMsgContent.substring(0, 50)}...' 
                  : lastMsgContent,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 4),
            // Badge non-lus (optionnel)
            // if (unreadCount > 0)
            //   CircleAvatar(
            //     radius: 9,
            //     backgroundColor: Colors.red,
            //     child: Text('$unreadCount', 
            //       style: const TextStyle(fontSize: 10, color: Colors.white)),
            //   ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conv['id'],
                pharmacyName: pharmacy?['name'] ?? 'Pharmacie',
                medicineName: medicine?['name'] ?? 'Médicament',
              ),
            ),
          );
        },
        isThreeLine: true,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays == 1) {
      return 'Hier';
    } else if (now.difference(time).inDays < 7) {
      return ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][time.weekday - 1];
    } else {
      return '${time.day}/${time.month}';
    }
  }
}