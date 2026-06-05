import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_screen.dart';

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

  // ✅ LISTENER - Écoute les nouvelles notifications en temps réel
  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
      // Filtrer pour n'afficher que les notifications non lues
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

      // Filtrer uniquement les notifications non lues
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

  // ✅ FONCTION CORRIGÉE - OUVRIR LA CONVERSATION DEPUIS LA NOTIFICATION
  Future<void> _openNotification(Map<String, dynamic> notification) async {
    print('🔔 Clic sur notification');
    
    try {
      // 1. Marquer comme lu
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', notification['id']);

      final type = notification['type'];
      final data = notification['data'] as Map<String, dynamic>?;

      if (type == 'message' && data != null) {
        final conversationId = data['conversationId'];
        final pharmacyName = data['pharmacyName'] ?? 'Pharmacie';

        print('📱 Navigation vers conversation: $conversationId');

        if (conversationId != null && conversationId.isNotEmpty) {
          // 2. Naviguer vers l'écran de chat
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversationId,
                pharmacyName: pharmacyName,
                medicineName: 'Discussion',
              ),
            ),
          );
          
          // 3. Recharger la liste des notifications au retour du chat
          if (mounted) {
            _loadNotifications();
          }
        } else {
          print('⚠️ Erreur: conversationId manquant dans les données de notification');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'ouvrir la conversation (données manquantes)'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      // ✅ GESTION DES ANNULATIONS DE COMMANDE
      else if (type == 'order_cancelled' && data != null) {
        print('📦 Notification annulation commande');
        if (mounted) {
          await Navigator.pushNamed(context, '/orders');
          _loadNotifications();
        }
      }
      else if (type == 'reservation' && mounted) {
        await Navigator.pushNamed(context, '/orders');
        _loadNotifications();
      }
    } catch (e) {
      print('❌ Erreur ouverture notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'reservation': return Icons.local_pharmacy;
      case 'order_cancelled': return Icons.cancel;
      default: return Icons.notifications_none;
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
                                Icon(
                                  _getNotificationIcon(n['type']),
                                  color: isRead ? Colors.grey : Colors.teal,
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
                                      if (n['message'] != null && n['message'].isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            n['message'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _formatTime(n['created_at']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
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