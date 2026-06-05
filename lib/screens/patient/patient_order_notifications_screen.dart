import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientOrderNotificationsScreen extends StatefulWidget {
  const PatientOrderNotificationsScreen({super.key});

  @override
  State<PatientOrderNotificationsScreen> createState() => _PatientOrderNotificationsScreenState();
}

class _PatientOrderNotificationsScreenState extends State<PatientOrderNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
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
          .inFilter('type', ['order_accepted', 'order_rejected'])
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
      // Filtrer uniquement les notifications de commandes
      final orderNotifications = data.where((n) {
        final type = n['type'] as String?;
        return type == 'order_accepted' || type == 'order_rejected';
      }).toList();

      setState(() {
        _notifications = orderNotifications;
        _isLoading = false;
      });
    });
  }

  // ✅ FONCTION DE SUPPRESSION AVEC CONFIRMATION
  Future<void> _deleteNotification(String notificationId, int index) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer la notification ?'),
        content: const Text(
          'Cette action supprimera définitivement cette notification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('id', notificationId);

        if (mounted) {
          setState(() {
            _notifications.removeAt(index);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Notification supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erreur lors de la suppression'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('❌ Erreur mark as read: $e');
    }
  }

  Color _getNotificationColor(String type) {
    if (type == 'order_accepted') {
      return Colors.green;
    } else if (type == 'order_rejected') {
      return Colors.red;
    }
    return Colors.grey;
  }

  IconData _getNotificationIcon(String type) {
    if (type == 'order_accepted') {
      return Icons.check_circle;
    } else if (type == 'order_rejected') {
      return Icons.cancel;
    }
    return Icons.notifications;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return 'Il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Il y a ${diff.inHours}h';
      } else {
        return '${date.day}/${date.month} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications de commandes'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final data = notif['data'] as Map<String, dynamic>?;
                      final type = notif['type'] as String;
                      final isRead = notif['read'] == true;
                      
                      final isAccepted = type == 'order_accepted';
                      final isRejected = type == 'order_rejected';
                      final medicineName = data?['medicineName'] ?? data?['medicine'] ?? 'Médicament';
                      final quantity = data?['quantity'] ?? '';
                      final totalPrice = data?['totalPrice'] ?? data?['total_price'] ?? '';

                      return Dismissible(
                        key: Key(notif['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('🗑️ Supprimer ?'),
                              content: const Text(
                                'Voulez-vous supprimer cette notification ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await _deleteNotification(notif['id'], index);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isRead ? 1 : 3,
                          color: isRead 
                              ? Colors.white 
                              : (isAccepted 
                                  ? Colors.green.shade50 
                                  : isRejected 
                                      ? Colors.red.shade50 
                                      : Colors.teal.shade50),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icône statut
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _getNotificationColor(type),
                                      child: Icon(
                                        _getNotificationIcon(type),
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Contenu
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Titre
                                          Row(
                                            children: [
                                              Text(
                                                isAccepted 
                                                    ? '✅ Commande acceptée' 
                                                    : isRejected 
                                                        ? '❌ Commande refusée' 
                                                        : '⏳ En attente',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (!isRead) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          // Description
                                          Text(
                                            isAccepted 
                                                ? 'Votre commande de $medicineName a été acceptée par la pharmacie.'
                                                : isRejected
                                                    ? 'Votre commande de $medicineName a été refusée par la pharmacie.'
                                                    : 'Votre commande de $medicineName est en attente.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 8),
                                          
                                          // Détails
                                          Row(
                                            children: [
                                              Icon(Icons.local_offer, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$medicineName - Quantité: $quantity',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          Row(
                                            children: [
                                              Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$totalPrice FCFA',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          // Temps
                                          Text(
                                            _formatDate(notif['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // ✅ BOUTON SUPPRIMER
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Supprimer',
                                        onPressed: () => _deleteNotification(notif['id'], index),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}