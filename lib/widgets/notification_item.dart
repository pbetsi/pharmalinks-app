import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap ?? () {
        // Navigation par défaut si onTap non fourni
        _handleNotificationTap(context);
      },
      leading: CircleAvatar(
        backgroundColor: notification['read'] == true 
            ? Colors.grey.shade200 
            : Colors.teal.shade100,
        child: Icon(
          _getNotificationIcon(notification['type']),
          color: notification['read'] == true 
              ? Colors.grey 
              : Colors.teal.shade700,
        ),
      ),
      title: Text(
        notification['title'] ?? 'Notification',
        style: TextStyle(
          fontWeight: notification['read'] == true 
              ? FontWeight.normal 
              : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification['message'] != null)
            Text(
              notification['message'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            _formatTime(notification['created_at']),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: notification['read'] != true
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'reservation':
        return Icons.local_pharmacy;
      case 'order':
        return Icons.shopping_bag;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return '${date.day}/${date.month} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  void _handleNotificationTap(BuildContext context) async {
    try {
      final type = notification['type'];
      final data = notification['data'] as Map<String, dynamic>?;

      if (type == 'message' && data != null) {
        // Navigation vers le chat
        await Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': data['conversationId'],
            'pharmacyName': data['pharmacyName'] ?? 'Pharmacie',
            'medicineName': data['medicineName'] ?? 'Discussion',
          },
        );

        // Marquer comme lu
        if (notification['id'] != null) {
          await Supabase.instance.client
              .from('notifications')
              .update({'read': true})
              .eq('id', notification['id']);
        }
      } else if (type == 'reservation' && data != null) {
        // Navigation vers les commandes
        await Navigator.pushNamed(context, '/orders');
        
        // Marquer comme lu
        if (notification['id'] != null) {
          await Supabase.instance.client
              .from('notifications')
              .update({'read': true})
              .eq('id', notification['id']);
        }
      }
    } catch (e) {
      print('❌ Erreur navigation notification: $e');
    }
  }
}