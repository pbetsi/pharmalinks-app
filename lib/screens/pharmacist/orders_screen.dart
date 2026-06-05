import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/whatsapp_service.dart'; // ✅ Import du service WhatsApp

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _notifications = [];
  int _cancelledOrdersCount = 0;
  bool _isLoading = true;
  String _selectedFilter = 'all';
  late TabController _tabController;

  final List<Map<String, dynamic>> _filters = [
    {'key': 'all', 'label': 'Toutes', 'icon': Icons.list},
    {'key': 'pending', 'label': 'En attente', 'icon': Icons.pending},
    {'key': 'accepted', 'label': 'Acceptées', 'icon': Icons.check_circle},
    {'key': 'completed', 'label': 'Terminées', 'icon': Icons.done_all},
    {'key': 'rejected', 'label': 'Refusées', 'icon': Icons.cancel},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _loadOrders();
    _loadNewOrderNotifications();
    _markOrderNotificationsAsRead();
    _setupRealtimeListeners();
    _setupCancellationNotificationListener();
  }

  // ✅ NOUVELLE FONCTION : Marquer automatiquement les notifications de commandes comme lues
  Future<void> _markOrderNotificationsAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      print('🔄 Auto-mark: Marquage des notifications de commandes comme lues');
      
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('read', false)
          .or('type.eq.order,type.eq.new_order,type.eq.order_update');

      print('✅ Notifications de commandes marquées comme lues');
      _loadNewOrderNotifications();
    } catch (e) {
      print('❌ Erreur auto-mark notifications: $e');
    }
  }

  // ✅ ÉCOUTER LES NOTIFICATIONS D'ANNULATION
  void _setupCancellationNotificationListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final cancelledNotifications = data.where((notification) {
            return notification['type'] == 'order_cancelled' &&
                   notification['read'] == false;
          }).toList();

          print('🔔 Notifications d\'annulation: ${cancelledNotifications.length}');
          
          setState(() {
            _cancelledOrdersCount = cancelledNotifications.length;
          });
          
          if (cancelledNotifications.isNotEmpty && mounted) {
            final latestNotification = cancelledNotifications.first;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📦 ${latestNotification['message']}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Voir',
                  textColor: Colors.white,
                  onPressed: () => _loadOrders(),
                ),
              ),
            );
          }
        });
  }

  // ✅ Charger les notifications de nouvelles commandes
  Future<void> _loadNewOrderNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .eq('type', 'new_order')
          .eq('read', false)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('❌ Erreur chargement notifications: $e');
    }
  }

  // ✅ Marquer la notification comme lue
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
      
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });
    } catch (e) {
      print('❌ Erreur mark as read: $e');
    }
  }

  // ✅ Écouter les changements en temps réel
  void _setupRealtimeListeners() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final newOrderNotifications = data.where((notification) {
            return notification['type'] == 'new_order' &&
                   notification['read'] == false;
          }).toList();

          setState(() {
            _notifications = List<Map<String, dynamic>>.from(newOrderNotifications);
          });
        });

    Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('pharmacy_id', user.id)
        .listen((data) {
          _loadOrders();
        });
  }

  // ✅ FONCTION CORRIGÉE - Utiliser reservations au lieu de orders
  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ Utilisateur non connecté');
        setState(() => _isLoading = false);
        return;
      }

      print('🔍 Pharmacy ID: ${user.id}');

      var query = Supabase.instance.client
          .from('reservations')
          .select('''
            id,
            status,
            quantity,
            unit_price,
            total_price,
            created_at,
            patient_name,
            patient_phone,
            patient_address,
            notes,
            pharmacy_id,
            medicine_id,
            medicines (
              id,
              name,
              dosage,
              form
            )
          ''')
          .eq('pharmacy_id', user.id);

      if (_selectedFilter != 'all') {
        query = query.eq('status', _selectedFilter);
      }

      final response = await query.order('created_at', ascending: false);

      print('📦 Réservations trouvées: ${response.length}');

      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ FONCTION POUR DIMINUER LE STOCK
  Future<void> _decreaseStock(String medicineId, int quantity) async {
    try {
      final medicine = await Supabase.instance.client
          .from('medicines')
          .select('stock_quantity')
          .eq('id', medicineId)
          .single();

      final currentStock = medicine['stock_quantity'] as int;
      final newStock = currentStock - quantity;

      if (newStock < 0) {
        throw Exception('Stock insuffisant. Stock actuel: $currentStock');
      }

      await Supabase.instance.client
          .from('medicines')
          .update({
            'stock_quantity': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', medicineId);

      print('✅ Stock diminué: $currentStock -> $newStock (-$quantity)');
    } catch (e) {
      print('❌ Erreur mise à jour stock: $e');
      rethrow;
    }
  }

  // ✅ FONCTION POUR AUGMENTER LE STOCK
  Future<void> _increaseStock(String medicineId, int quantity) async {
    try {
      final medicine = await Supabase.instance.client
          .from('medicines')
          .select('stock_quantity')
          .eq('id', medicineId)
          .single();

      final currentStock = medicine['stock_quantity'] as int;
      final newStock = currentStock + quantity;

      await Supabase.instance.client
          .from('medicines')
          .update({
            'stock_quantity': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', medicineId);

      print('✅ Stock augmenté: $currentStock -> $newStock (+$quantity)');
    } catch (e) {
      print('❌ Erreur mise à jour stock: $e');
    }
  }

  // ✅ FONCTION MISE À JOUR AVEC NOTIFICATION WHATSAPP
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      // Récupérer les infos de la commande avec jointures
      final orderData = await Supabase.instance.client
          .from('reservations')
          .select('''
            *,
            medicines (name),
            pharmacies (name)
          ''')
          .eq('id', orderId)
          .single();

      final patientPhone = orderData['patient_phone'];
      final patientName = orderData['patient_name'] ?? 'Cher patient';
      final medicineName = orderData['medicines']?['name'] ?? 'Médicament';
      final pharmacyName = orderData['pharmacies']?['name'] ?? 'Notre pharmacie';

      // Mettre à jour le statut
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'accepted') {
        updates['confirmed_at'] = DateTime.now().toIso8601String();
      } else if (status == 'completed') {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await Supabase.instance.client
          .from('reservations')
          .update(updates)
          .eq('id', orderId);

      // ✅ CRÉER NOTIFICATION IN-APP
      await Supabase.instance.client.from('notifications').insert({
        'user_id': orderData['patient_id'],
        'type': 'order',
        'title': status == 'accepted' 
            ? '✅ Commande acceptée par $pharmacyName'
            : status == 'rejected'
                ? '❌ Commande refusée par $pharmacyName'
                : '✅ Commande terminée par $pharmacyName',
        'message': 'Votre commande de $medicineName a été ${status == 'accepted' ? 'acceptée' : status == 'rejected' ? 'refusée' : 'terminée'} par $pharmacyName',
        'data': {
          'orderId': orderId,
          'pharmacyName': pharmacyName,
          'medicineName': medicineName,
          'status': status,
          'type': 'order_update',
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 📱 SI COMMANDE ACCEPTÉE -> PROPOSER WHATSAPP
      if (status == 'accepted' && mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Commande Acceptée'),
            content: const Text('Voulez-vous notifier le patient par WhatsApp ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'no'),
                child: const Text('Non'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'yes'),
                icon: const Icon(Icons.chat),
                label: const Text('Oui, WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (action == 'yes' && patientPhone != null) {
          // Envoyer le message WhatsApp via le service
          WhatsAppService.sendMessage(
            phoneNumber: patientPhone,
            message: 'Bonjour $patientName ! 👋\n\n'
                'Votre commande de *$medicineName* chez *$pharmacyName* est acceptée. ✅\n\n'
                'Elle sera prête dans 30 minutes.\n'
                'Merci de votre confiance ! 🙏',
          );
        }
      }

      // Rafraîchir la liste
      _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? '✅ Commande acceptée'
                  : status == 'rejected'
                      ? '❌ Commande refusée'
                      : '✅ Commande terminée',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur mise à jour: $e');
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

  // ✅ NOUVELLE FONCTION : Supprimer une commande
  Future<void> _deleteOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer la commande ?'),
        content: const Text(
          'Cette action est irréversible. La commande sera supprimée définitivement.',
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
        print('🗑️ Suppression de la commande: $orderId');
        
        final response = await Supabase.instance.client
            .from('reservations')
            .delete()
            .eq('id', orderId)
            .select();

        print('✅ Réponse suppression: ${response.length} ligne(s) supprimée(s)');

        if (mounted) {
          await _loadOrders();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {});
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Commande supprimée'),
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
    } else {
      print('⚠️ Suppression annulée');
    }
  }

  // ✅ FONCTION CORRIGÉE - Avec notification marquée comme lue à l'ouverture
  void _showOrderDetails(Map<String, dynamic> order) {
    final notificationId = order['notification_id'];
    if (notificationId != null) {
      _markNotificationAsRead(notificationId);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getStatusColor(order['status']),
                      child: Icon(_getStatusIcon(order['status']), color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order['id'].toString().substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(order['created_at']),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(order['status']),
                  ],
                ),
                const Divider(height: 32),
                const Text(
                  'Médicament',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.medication,
                  order['medicines']?['name'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.science,
                  '${order['medicines']?['dosage']} - ${order['medicines']?['form']}',
                ),
                _buildDetailRow(
                  Icons.shopping_basket,
                  'Quantité: ${order['quantity']}',
                ),
                _buildDetailRow(
                  Icons.attach_money,
                  'Prix total: ${order['total_price']} FCFA',
                ),
                const Divider(height: 32),
                const Text(
                  'Informations Patient',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.person,
                  order['patient_name'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.phone,
                  order['patient_phone'] ?? 'N/A',
                ),
                if (order['patient_address'] != null && order['patient_address'].isNotEmpty)
                  _buildDetailRow(
                    Icons.location_on,
                    order['patient_address'],
                  ),
                if (order['notes'] != null && order['notes'].isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text(
                    'Notes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(order['notes']),
                  ),
                ],
                const SizedBox(height: 32),
                
                if (order['status'] == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateOrderStatus(order['id'], 'rejected');
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Refuser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateOrderStatus(order['id'], 'accepted');
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Accepter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteOrder(order['id']);
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text('Supprimer définitivement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(_getStatusText(status)),
      backgroundColor: _getStatusColor(status),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'completed':
        return 'Terminée';
      case 'rejected':
        return 'Refusée';
      default:
        return 'Inconnu';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📦 Commandes'),
            if (_cancelledOrdersCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  _cancelledOrdersCount > 9 ? '9+' : '$_cancelledOrdersCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _filters.map((filter) {
            return Tab(
              icon: Icon(filter['icon'] as IconData, size: 20),
              text: filter['label'] as String,
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_notifications.isNotEmpty)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _notifications.map((notification) {
                  final data = notification['data'] as Map<String, dynamic>?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🔔 Nouvelle commande',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              Text(
                                data?['patientName'] ?? 'Un patient',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _markNotificationAsRead(notification['id']),
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _filters.map((filter) {
                      return _buildOrderList(filter['key'] as String);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(String filterKey) {
    final filteredOrders = filterKey == 'all'
        ? _orders
        : _orders.where((order) => order['status'] == filterKey).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune commande',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        final medicine = order['medicines'] as Map<String, dynamic>?;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(order['status']),
              child: Icon(
                _getStatusIcon(order['status']),
                color: Colors.white,
              ),
            ),
            title: Text(
              medicine?['name'] ?? 'Médicament',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient: ${order['patient_name'] ?? 'N/A'}'),
                Text('Quantité: ${order['quantity']}'),
                Text('Prix: ${order['total_price']} FCFA'),
                Text(
                  _formatDate(order['created_at']),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _showOrderDetails(order),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}