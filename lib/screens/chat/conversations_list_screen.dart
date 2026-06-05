import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pharmacist/pharmacist_chat_screen.dart';
import 'chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isPharmacist = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    if (!mounted) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final pharmacyData = await Supabase.instance.client
          .from('pharmacies')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (!mounted) return;
      
      setState(() {
        _isPharmacist = pharmacyData != null;
        _isLoading = false;
      });
      
      if (mounted) {
        _loadConversations();
      }
    } catch (e) {
      print('❌ Erreur vérification rôle: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('🔍 Chargement des conversations pour ${_isPharmacist ? 'pharmacie' : 'patient'}: ${user.id}');

      final response = await (_isPharmacist
          ? Supabase.instance.client
              .from('conversations')
              .select('''
                id,
                patient_id,
                pharmacy_id,
                created_at,
                updated_at,
                pharmacies (
                  name
                ),
                users!conversations_patient_id_fkey (
                  id,
                  email
                ),
                messages (
                  content,
                  created_at,
                  read,
                  sender_id
                )
              ''')
              .eq('pharmacy_id', user.id)
              .order('updated_at', ascending: false)
          : Supabase.instance.client
              .from('conversations')
              .select('''
                id,
                patient_id,
                pharmacy_id,
                created_at,
                updated_at,
                pharmacies (
                  name
                ),
                users!conversations_patient_id_fkey (
                  id,
                  email
                ),
                messages (
                  content,
                  created_at,
                  read,
                  sender_id
                )
              ''')
              .eq('patient_id', user.id)
              .order('updated_at', ascending: false));

      print('✅ Conversations trouvées: ${response.length}');

      if (!mounted) return;

      setState(() {
        _conversations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement conversations: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ✅ FONCTION CORRIGÉE - Navigation avec .then() pour recharger
  void _openConversation(Map<String, dynamic> conversation) {
    if (!mounted) return;
    
    final pharmacy = conversation['pharmacies'] as Map<String, dynamic>?;
    final patientId = conversation['patient_id'] as String?;
    
    print('🔓 Ouverture conversation: ${conversation['id']}');
    print('👤 Patient ID: $patientId');

    // ✅ Utiliser .then() pour recharger la liste dès qu'on revient du chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _isPharmacist
            ? PharmacistChatScreen(
                conversationId: conversation['id'],
                patientName: 'Patient',
                patientId: patientId ?? '',
              )
            : ChatScreen(
                conversationId: conversation['id'],
                pharmacyName: pharmacy?['name'] ?? 'Pharmacie',
                medicineName: 'Discussion',
              ),
      ),
    ).then((_) {
      // ✅ Recharger les conversations pour mettre à jour le badge
      print('🔄 Retour du chat, rechargement des conversations...');
      if (mounted) {
        _loadConversations();
      }
    });
  }

  Future<void> _deleteConversation(String conversationId) async {
    print('🗑️ Début suppression conversation: $conversationId');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer la conversation ?'),
        content: const Text(
          'Cette action est irréversible. Tous les messages seront supprimés.',
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
        print('📦 Suppression des messages...');
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
        
        print('🗑️ Suppression de la conversation...');
        await Supabase.instance.client
            .from('conversations')
            .delete()
            .eq('id', conversationId);

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _conversations.removeWhere((conv) => conv['id'] == conversationId);
          });

          print('✅ Conversation supprimée avec succès');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Conversation supprimée'),
              backgroundColor: Colors.green,
            ),
          );

          await _loadConversations();
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

  void _showConversationOptions(Map<String, dynamic> conversation) {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer la conversation'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteConversation(conversation['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPharmacist ? 'Messages reçus' : 'Mes conversations'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  return _buildConversationTile(conv);
                },
              ),
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
    final messages = conv['messages'] as List<dynamic>?;
    final lastMessage = messages?.isNotEmpty == true 
        ? messages!.last 
        : null;
    
    final lastMsgContent = lastMessage?['content'] as String?;
    
    final lastMsgTime = lastMessage?['created_at'] != null
        ? DateTime.parse(lastMessage!['created_at'])
        : DateTime.parse(conv['created_at']);
    
    final timeStr = _formatTime(lastMsgTime);

    final user = Supabase.instance.client.auth.currentUser;
    final hasUnread = messages?.any((m) => 
          m['read'] == false && m['sender_id'] != user?.id
        ) == true;

    String patientDisplayName = 'Patient';
    String patientEmail = '';
    
    final patientData = conv['users'] as Map<String, dynamic>?;
    if (patientData != null) {
      patientEmail = patientData['email'] ?? '';
      
      if (patientEmail.isNotEmpty) {
        patientDisplayName = patientEmail.split('@').first;
      }
    }

    final displayName = _isPharmacist
        ? patientDisplayName
        : (pharmacy?['name'] ?? 'Pharmacie');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          print('👆 Clic sur conversation: ${conv['id']}');
          _openConversation(conv);
        },
        onLongPress: () {
          _showConversationOptions(conv);
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: hasUnread ? Colors.teal : Colors.teal.shade100,
            child: Icon(
              _isPharmacist ? Icons.person : Icons.local_pharmacy,
              color: hasUnread ? Colors.white : Colors.teal.shade700,
            ),
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lastMsgContent != null)
                Text(
                  lastMsgContent.length > 50 
                    ? '${lastMsgContent.substring(0, 50)}...' 
                    : lastMsgContent,
                  style: TextStyle(
                    fontSize: 13, 
                    color: hasUnread ? Colors.teal : Colors.grey[600],
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showConversationOptions(conv);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          isThreeLine: true,
        ),
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