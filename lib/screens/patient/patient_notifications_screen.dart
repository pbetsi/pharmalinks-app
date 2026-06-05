import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ CORRECTION ICI : On importe le bon fichier ChatScreen
import '../chat/chat_screen.dart'; 

class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startNotificationListener();
  }

  // 🔔 Écoute en temps réel des nouveaux messages
  void _startNotificationListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (!mounted) return;
      
      // Filtrer manuellement les messages non lus et pas envoyés par l'utilisateur
      final unreadFromOthers = data.where((msg) {
        final isUnread = msg['read'] == false;
        final isFromOther = msg['sender_id'] != user.id;
        return isUnread && isFromOther;
      }).toList();

      setState(() {
        _unreadCount = unreadFromOthers.length;
      });
      
      // Recharger la liste pour afficher les nouveaux messages
      _loadNotifications();
    });
  }

   // 🔹 Charger les notifications
  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final conversations = await Supabase.instance.client
          .from('conversations')
          .select('id, pharmacy_id')
          .eq('patient_id', user.id);

      final conversationIds = conversations
          .map((c) => c['id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (conversationIds.isEmpty) {
        if (mounted) {
          setState(() {
            _notifications = [];
            _unreadCount = 0;
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ CORRECTION ICI : Utilisation de .filter() au lieu de .in_()
      final response = await Supabase.instance.client
          .from('messages')
          .select('''
            id,
            content,
            created_at,
            read,
            sender_id,
            conversation_id,
            users!messages_sender_id_fkey (full_name),
            conversations (
              pharmacies (name, city)
            )
          ''')
          .filter('conversation_id', 'in', conversationIds)
          .eq('read', false)
          .neq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _unreadCount = _notifications.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement notifications patient: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

    // 🔹 Marquer tout comme lu
  Future<void> _markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final conversations = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('patient_id', user.id);

      final conversationIds = conversations
          .map((c) => c['id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (conversationIds.isNotEmpty) {
        // ✅ CORRECTION ICI : Utilisation de .filter()
        await Supabase.instance.client
            .from('messages')
            .update({'read': true})
           .filter('conversation_id', 'in', '(${conversationIds.join(',')})')
            .eq('read', false)
            .neq('sender_id', user.id);
      }

      _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tout marqué comme lu')),
        );
      }
    } catch (e) {
      print('❌ Erreur markAll: $e');
    }
  }
  // 🗑️ Supprimer une notification
  Future<void> _deleteNotification(String messageId, int index) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: const Text("Voulez-vous vraiment supprimer ce message ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('id', messageId);

        if (mounted) {
          setState(() {
            _notifications.removeAt(index);
            _unreadCount = _notifications.length;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Notification supprimée"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        print("❌ Erreur suppression : $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur lors de la suppression"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

   // 🔹 Ouvrir conversation
  Future<void> _openConversation(Map<String, dynamic> msg) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'read': true})
          .eq('id', msg['id']);

      if (mounted) {
        setState(() {
          _unreadCount = _notifications.where((n) => n['read'] == false).length;
        });
      }
    } catch (e) {
      print('⚠️ Mark read error: $e');
    }

    if (mounted) {
      final conversation = msg['conversations'] as Map<String, dynamic>?;
      final pharmacy = conversation?['pharmacies'] as Map<String, dynamic>?;

      // ✅ CORRECTION ICI : Utilisation de ChatScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: msg['conversation_id']?.toString() ?? '',
            pharmacyName: pharmacy?['name']?.toString() ?? 'Pharmacie',
            medicineName: '',
          ),
        ),
      ).then((_) {
        if (mounted) _loadNotifications();
      });
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
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _notifications.isNotEmpty ? _markAllAsRead : null,
            tooltip: 'Tout marquer comme lu',
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
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final msg = _notifications[index];
                    final conversation = msg['conversations'] as Map<String, dynamic>?;
                    final pharmacy = conversation?['pharmacies'] as Map<String, dynamic>?;
                    final time = DateTime.parse(msg['created_at']).toLocal();
                    final isRead = msg['read'] == true;

                    final pharmacyName = pharmacy?['name']?.toString() ?? 'Pharmacie';
                    final pharmacyCity = pharmacy?['city']?.toString() ?? '';

                    return ListTile(
                      onTap: () => _openConversation(msg),
                      leading: CircleAvatar(
                        backgroundColor: isRead ? Colors.grey[300] : Colors.teal,
                        child: Icon(
                          isRead ? Icons.store_outlined : Icons.store,
                          color: isRead ? Colors.grey : Colors.white,
                        ),
                      ),
                      title: Text(
                        pharmacyName,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pharmacyCity.isNotEmpty)
                            Text(
                              '📍 $pharmacyCity',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            msg['content']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: "Supprimer",
                            onPressed: () => _deleteNotification(msg['id']?.toString() ?? '', index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}