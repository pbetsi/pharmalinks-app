// lib/screens/pharmacist/pharmacist_home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports des écrans existants
import 'stock_screen.dart';
import 'reservations_screen.dart';

// ✅ Imports des nouvelles fonctionnalités
import '../chat/conversations_list_screen.dart';
// ✅ MODIFICATION : Import du NOUVEAU tableau de bord intelligent
import 'advanced_analytics_screen.dart'; // ← Remplace 'analytics_screen.dart'
import '../notifications/notifications_screen.dart';
import 'orders_screen.dart';
import 'prescriptions_screen.dart';
import '../../services/notification_manager.dart';

class PharmacistHomeScreen extends StatefulWidget {
  const PharmacistHomeScreen({super.key});

  @override
  State<PharmacistHomeScreen> createState() => _PharmacistHomeScreenState();
}

class _PharmacistHomeScreenState extends State<PharmacistHomeScreen> {
  
  // 🔔 Compteur de notifications non lues (messages)
  int _unreadNotificationCount = 0;
  
  // ✅ NOUVEAU : Compteur de nouvelles commandes non lues
  int _newOrdersCount = 0;
  
  // ✅ NOUVEAU : Compteur de commandes annulées non lues
  int _cancelledOrdersCount = 0;
  
  // ✅ NOUVEAU : Compteur de commandes en attente
  int _pendingOrdersCount = 0;
  
  // ✅ NOUVEAU : Compteur de messages non lus (simplifié)
  int _unreadMessagesCount = 0;
  
  StreamSubscription? _notificationStreamSub;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _notificationsTableSubscription;
  StreamSubscription? _newOrdersSubscription;
  StreamSubscription? _cancelledOrdersSubscription;
  StreamSubscription? _pendingOrdersSubscription;
  StreamSubscription? _unreadMessagesSubscription;
  
  final _notificationManager = NotificationManager();

  // ============================================
  // 🚪 Dialog de confirmation de déconnexion
  // ============================================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Déconnexion'),
            ],
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?\n\nVous devrez vous reconnecter pour accéder à votre tableau de bord.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/auth',
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // 🔔 Initialisation des notifications
  // ============================================
  Future<void> _initializeNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await _notificationManager.initialize();
    _notificationManager.listenForNewMessages(user.id);
    _notificationManager.listenForNewReservations(user.id);
    
    await _loadUnreadCount();
    
    Timer.periodic(const Duration(seconds: 10), (_) => _loadUnreadCount());
  }

  // ✅ Charger le nombre de nouvelles commandes non lues
  Future<void> _loadNewOrdersCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('type', 'new_order')
          .eq('read', false);

      setState(() {
        _newOrdersCount = response.length;
      });
    } catch (e) {
      print('❌ Erreur chargement nouvelles commandes: $e');
    }
  }

  // ✅ Charger le nombre de commandes annulées non lues
  Future<void> _loadCancelledOrdersCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('type', 'order_cancelled')
          .eq('read', false);

      setState(() {
        _cancelledOrdersCount = response.length;
      });
    } catch (e) {
      print('❌ Erreur chargement commandes annulées: $e');
    }
  }

  // ✅ Écouter les changements de notifications en temps réel
  void _setupNotificationsReadListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final newOrdersUnread = data.where((n) => 
            n['type'] == 'new_order' && n['read'] == false
          ).length;
          
          final cancelledUnread = data.where((n) => 
            n['type'] == 'order_cancelled' && n['read'] == false
          ).length;
          
          setState(() {
            _newOrdersCount = newOrdersUnread;
            _cancelledOrdersCount = cancelledUnread;
          });
          
          print('🔔 Notifications mises à jour - Nouvelles: $_newOrdersCount, Annulées: $_cancelledOrdersCount');
        });
  }

  // ✅ Écouter les commandes annulées en temps réel
  void _setupCancelledOrdersListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _cancelledOrdersSubscription?.cancel();

    _cancelledOrdersSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          final cancelledCount = data.where((notif) {
            return notif['type'] == 'order_cancelled' && 
                   (notif['read'] == false || notif['read'] == 'false');
          }).length;

          setState(() {
            _cancelledOrdersCount = cancelledCount;
          });
          
          print('🔔 Commandes annulées non lues: $_cancelledOrdersCount');
          
          if (cancelledCount > 0 && data.isNotEmpty) {
            final latestCancelled = data
                .where((n) => n['type'] == 'order_cancelled' && n['read'] == false)
                .firstOrNull;
            
            if (latestCancelled != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📦 ${latestCancelled['message']}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Voir',
                    textColor: Colors.white,
                    onPressed: () {
                      DefaultTabController.of(context)?.animateTo(1);
                    },
                  ),
                ),
              );
            }
          }
        }, onError: (error) {
          print('❌ Erreur stream commandes annulées: $error');
        });
  }

  // ✅ Écouter les nouvelles commandes en temps réel
  void _setupNewOrdersListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _newOrdersSubscription?.cancel();

    _newOrdersSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          final newOrderCount = data.where((notif) {
            return notif['type'] == 'new_order' && 
                   (notif['read'] == false || notif['read'] == 'false');
          }).length;

          setState(() {
            _newOrdersCount = newOrderCount;
          });
          
          print('🔔 Nouvelles commandes non lues: $_newOrdersCount');
        }, onError: (error) {
          print('❌ Erreur stream nouvelles commandes: $error');
        });
  }

  // ✅ Charger les commandes en attente (pour badge sur icon Commandes)
  Future<void> _loadPendingOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('pharmacy_id', user.id)
          .eq('status', 'pending');

      setState(() {
        _pendingOrdersCount = response.length;
      });
      
      print('📦 Commandes en attente: $_pendingOrdersCount');
    } catch (e) {
      print('❌ Erreur chargement commandes: $e');
    }
  }

  // ✅ Charger les messages non lus (pour badge sur icon Messages)
  Future<void> _loadUnreadMessages() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('read', false)
          .eq('type', 'message');

      setState(() {
        _unreadMessagesCount = response.length;
      });
      
      print('💬 Messages non lus: $_unreadMessagesCount');
    } catch (e) {
      print('❌ Erreur chargement messages: $e');
    }
  }

  // ✅ Écouter les commandes en attente en temps réel - CORRIGÉ
  void _setupOrdersListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _pendingOrdersSubscription?.cancel();

    _pendingOrdersSubscription = Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .listen((data) {
          final pendingOrders = data.where((order) {
            return order['pharmacy_id'] == user.id && 
                   order['status'] == 'pending';
          }).toList();
          
          setState(() {
            _pendingOrdersCount = pendingOrders.length;
          });
          
          print('📦 Stream commandes - Total: ${pendingOrders.length}');
        }, onError: (error) {
          print('❌ Erreur stream commandes: $error');
        });
  }

  // ✅ Écouter les messages non lus en temps réel - CORRIGÉ
  void _setupMessagesListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _unreadMessagesSubscription?.cancel();

    _unreadMessagesSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          final unreadMessages = data.where((notif) {
            return notif['user_id'] == user.id && 
                   notif['read'] == false &&
                   notif['type'] == 'message';
          }).toList();
          
          setState(() {
            _unreadMessagesCount = unreadMessages.length;
          });
          
          print('💬 Stream messages - Non lus: ${unreadMessages.length}');
        }, onError: (error) {
          print('❌ Erreur stream messages: $error');
        });
  }

  // ✅ FONCTION CORRIGÉE - Chargement du nombre de messages non lus
  Future<void> _loadUnreadCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final conversationsResponse = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('pharmacy_id', user.id);

      final List<String> conversationIds = conversationsResponse
          .where((c) => c['id'] != null)
          .map((c) => c['id'].toString())
          .toList();

      if (conversationIds.isEmpty) {
        if (mounted) setState(() => _unreadNotificationCount = 0);
        return;
      }

      final messagesResponse = await Supabase.instance.client
          .from('messages')
          .select('''
            id,
            content,
            created_at,
            sender_id,
            conversation_id,
            read
          ''')
          .eq('read', false)
          .order('created_at', ascending: false)
          .limit(100);

      final count = messagesResponse.where((msg) {
        final convId = msg['conversation_id']?.toString();
        final senderId = msg['sender_id']?.toString();
        
        final isInConversation = convId != null && conversationIds.contains(convId);
        final isNotFromPharmacy = senderId != null && senderId != user.id;
        
        return isInConversation && isNotFromPharmacy;
      }).length;

      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }

      print('🔔 Messages non lus: $count');
    } catch (e) {
      print('❌ Erreur chargement messages non lus: $e');
      if (mounted) setState(() => _unreadNotificationCount = 0);
    }
  }

  // ✅ FONCTION CORRIGÉE - Listener pour les messages non lus
  void _setupNotificationsListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _notificationsTableSubscription?.cancel();

    _notificationsTableSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) {
      _loadUnreadCount();
      print('🔔 Stream messages déclenché - Rechargement compteur...');
    }, onError: (error) {
      print('❌ Erreur stream messages: $error');
    });
  }

  // ✅ FONCTION CORRIGÉE - Marquer tous les messages comme lus
  Future<void> _markAllAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('📖 Marquage de tous les messages comme lus...');

      final conversationsResponse = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('pharmacy_id', user.id);

      final List<String> conversationIds = conversationsResponse
          .where((c) => c['id'] != null)
          .map((c) => c['id'].toString())
          .toList();

      if (conversationIds.isEmpty) {
        if (mounted) setState(() => _unreadNotificationCount = 0);
        return;
      }

      for (final convId in conversationIds) {
        await Supabase.instance.client
            .from('messages')
            .update({'read': true})
            .eq('conversation_id', convId)
            .eq('read', false)
            .neq('sender_id', user.id);
      }

      if (mounted) {
        setState(() {
          _unreadNotificationCount = 0;
        });
      }
      
      print('✅ Tous les messages marqués comme lus');
    } catch (e) {
      print('❌ Erreur marquage comme lu: $e');
    }
  }

  // ✅ NOUVELLE FONCTION - Marquer les messages d'une conversation comme lus
  Future<void> _markConversationAsRead(String conversationId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('messages')
          .update({'read': true})
          .eq('conversation_id', conversationId)
          .eq('read', false)
          .neq('sender_id', user.id);

      await _loadUnreadCount();
      
      print('✅ Conversation $conversationId marquée comme lue');
    } catch (e) {
      print('❌ Erreur mark conversation as read: $e');
    }
  }

  // ✅ FONCTION CORRIGÉE - Récupération des messages non lus
  Future<List<Map<String, dynamic>>> _getUnreadMessages() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final conversationsResponse = await Supabase.instance.client
          .from('conversations')
          .select('id, patient_id')
          .eq('pharmacy_id', user.id);

      if (conversationsResponse.isEmpty) return [];

      final conversationIds = conversationsResponse
          .map((c) => c['id'] as String)
          .toList();

      final messagesResponse = await Supabase.instance.client
          .from('messages')
          .select('''
            id,
            content,
            created_at,
            sender_id,
            conversation_id,
            read
          ''')
          .eq('read', false)
          .neq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      final unreadMessages = messagesResponse.where((msg) {
        final convId = msg['conversation_id']?.toString();
        final senderId = msg['sender_id']?.toString();
        
        final isInConversation = convId != null && conversationIds.contains(convId);
        final isNotFromPharmacy = senderId != null && senderId != user.id;
        
        return isInConversation && isNotFromPharmacy;
      }).take(20).toList();

      return List<Map<String, dynamic>>.from(unreadMessages);
    } catch (e) {
      print('❌ Erreur récupération messages: $e');
      return [];
    }
  }

  // ✅ NOUVELLE FONCTION - Marquer un message spécifique comme lu
  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'read': true})
          .eq('id', messageId);
      
      print('✅ Message marqué comme lu: $messageId');
    } catch (e) {
      print('❌ Erreur mark message as read: $e');
    }
  }

  // ============================================
  // 🔄 Écoute en temps réel des nouveaux messages
  // ============================================
  void _startNotificationListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _messagesSubscription?.cancel();
    
    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) {
      _loadUnreadCount();
      print('🔄 Listener messages déclenché, rechargement du compteur...');
    });
  }

  // ============================================
  // 🔄 Fonction de rafraîchissement
  // ============================================
  void _refreshData() {
    setState(() {
      _startNotificationListener();
      _setupNotificationsListener();
      _setupNewOrdersListener();
      _setupCancelledOrdersListener();
      _setupOrdersListener();
      _setupMessagesListener();
      _loadUnreadCount();
      _loadNewOrdersCount();
      _loadCancelledOrdersCount();
      _loadPendingOrders();
      _loadUnreadMessages();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('🔄 Données actualisées'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // 🔔 Afficher les notifications (Bottom Sheet)
  // ============================================
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_unreadNotificationCount > 0)
                    TextButton(
                      onPressed: () async {
                        await _markAllAsRead();
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Tout lu',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: _unreadNotificationCount == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Les nouvelles notifications apparaîtront ici',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getUnreadMessages(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Aucun nouveau message', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data!;
                        
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Icon(
                                  Icons.message,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              title: const Text(
                                'Nouveau message',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['content']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              onTap: () async {
                                await _markMessageAsRead(msg['id']);
                                Navigator.pop(ctx);
                                Navigator.pushNamed(context, '/conversations');
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FONCTION UTILITAIRE - Formatage du temps
  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return '${date.day}/${date.month} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  // ✅ Widget pour afficher le badge de notification
  Widget _buildBadge({
    required IconData icon,
    required int count,
    required Color color,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24),
        if (count > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _startNotificationListener();
    _setupNotificationsListener();
    _setupNewOrdersListener();
    _setupCancelledOrdersListener();
    _setupNotificationsReadListener();
    _setupOrdersListener();
    _setupMessagesListener();
    _initializeNotifications();
    _loadNewOrdersCount();
    _loadCancelledOrdersCount();
    _loadPendingOrders();
    _loadUnreadMessages();
  }

  @override
  void dispose() {
    _notificationStreamSub?.cancel();
    _messagesSubscription?.cancel();
    _notificationsTableSubscription?.cancel();
    _newOrdersSubscription?.cancel();
    _cancelledOrdersSubscription?.cancel();
    _pendingOrdersSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    _notificationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalOrdersNotifications = _newOrdersCount + _cancelledOrdersCount + _pendingOrdersCount;
    
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pharmalink Pro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Rafraîchir les données',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
              tooltip: 'Se déconnecter',
              color: Colors.white,
            ),
            const SizedBox(width: 8),
          ],
        ),
        
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            onTap: (index) {
              if (index == 1) {
                _markAllOrdersAsRead();
              }
              if (index == 2) {
                _markAllAsRead();
              }
              if (index == 3) {
                // Ordonnances
              }
            },
            tabs: [
              const Tab(icon: Icon(Icons.inventory), text: 'Stock'),
              Tab(
                icon: _buildBadge(
                  icon: Icons.receipt_long,
                  count: totalOrdersNotifications,
                  color: Colors.orange,
                ),
                text: 'Commandes',
              ),
              Tab(
                icon: _buildBadge(
                  icon: Icons.chat,
                  count: _unreadMessagesCount + _unreadNotificationCount,
                  color: Colors.red,
                ),
                text: 'Messages',
              ),
              const Tab(
                icon: Icon(Icons.assignment),
                text: 'Ordonnances',
              ),
              const Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            ],
          ),
        ),
        
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const StockScreen(),
            const OrdersScreen(),
            const ConversationsListScreen(),
            const PharmacistPrescriptionsScreen(),
            // ✅ MODIFICATION PRINCIPALE ICI :
            const AdvancedAnalyticsScreen(), // ← Remplace AnalyticsScreen()
          ],
        ),
      ),
    );
  }

  // ✅ FONCTION POUR EFFACER LA NOTIFICATION DE COMMANDE
  Future<void> _markAllOrdersAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('🧹 Nettoyage des notifications de commandes...');

      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('type', 'new_order')
          .eq('read', false);

      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('type', 'order_cancelled')
          .eq('read', false);

      setState(() {
        _newOrdersCount = 0;
        _cancelledOrdersCount = 0;
      });

      print('✅ Badge de notification de commandes effacé !');
    } catch (e) {
      print('❌ Erreur lors du nettoyage des commandes: $e');
    }
  }

  // ✅ NOUVELLE FONCTION - Marquer les commandes annulées comme lues
  Future<void> _markCancelledOrdersAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('type', 'order_cancelled')
          .eq('read', false);

      setState(() {
        _cancelledOrdersCount = 0;
      });
      
      print('✅ Commandes annulées marquées comme lues');
    } catch (e) {
      print('❌ Erreur mark cancelled orders as read: $e');
    }
  }
}