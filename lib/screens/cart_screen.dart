import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _pastOrders = [];
  bool _isLoadingOrders = false;
  String _orderFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPastOrders();
  }

  Future<void> _loadPastOrders() async {
    setState(() => _isLoadingOrders = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      var queryBuilder = Supabase.instance.client
          .from('reservations')
          .select('''
            id,
            status,
            quantity,
            unit_price,
            total_price,
            created_at,
            patient_id,
            pharmacy_id,
            patient_name,
            medicines (
              name,
              dosage,
              form
            ),
            pharmacies (
              name,
              address,
              phone
            )
          ''')
          .eq('patient_id', user.id);

      if (_orderFilter != 'all') {
        queryBuilder = queryBuilder.eq('status', _orderFilter);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      setState(() {
        _pastOrders = List<Map<String, dynamic>>.from(response);
        _isLoadingOrders = false;
      });
    } catch (e) {
      print('❌ Erreur chargement commandes: $e');
      setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _confirmOrder() async {
    final cartService = context.read<CartService>();
    if (cartService.cart.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la commande'),
        content: Text(
          'Voulez-vous vraiment confirmer cette commande de ${cartService.totalPrice.toStringAsFixed(0)} FCFA ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessing = true);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Utilisateur non connecté');

        for (final item in cartService.cart) {
          await Supabase.instance.client.from('reservations').insert({
            'patient_id': user.id,
            'pharmacy_id': item.pharmacyId,
            'medicine_id': item.medicineId,
            'quantity': item.quantity,
            'unit_price': item.price,
            'total_price': item.totalPrice,
            'status': 'pending',
            'patient_name': user.email?.split('@').first ?? 'Patient',
            'created_at': DateTime.now().toIso8601String(),
          });

          await _notifyPharmacy(item);
        }

        cartService.clearCart();
        _loadPastOrders();

        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Commande confirmée ! Le pharmacien a été notifié.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: () {
                  _tabController.animateTo(1);
                },
              ),
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur confirmation commande: $e');
        if (mounted) {
          setState(() => _isProcessing = false);
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

  Future<void> _notifyPharmacy(CartItem item) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': item.pharmacyId,
        'type': 'reservation',
        'title': 'Nouvelle commande',
        'message': '${item.quantity} x ${item.medicineName} - ${item.totalPrice.toStringAsFixed(0)} FCFA',
        'data': {
          'medicineName': item.medicineName,
          'quantity': item.quantity,
          'totalPrice': item.totalPrice,
          'pharmacyName': item.pharmacyName,
          'type': 'new_order',
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erreur notification pharmacie: $e');
    }
  }

  Future<void> _cancelOrder() async {
    final cartService = context.read<CartService>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text('Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      cartService.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Commande annulée'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ✅ FONCTION D'ANNULATION DE COMMANDE DE L'HISTORIQUE
  Future<void> _cancelPastOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Annuler la commande'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette commande ?\n\n'
          'La pharmacie sera notifiée de cette annulation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Utilisateur non connecté')),
          );
          return;
        }

        // 1. Mettre à jour le statut de la commande
        await Supabase.instance.client
            .from('reservations')
            .update({
              'status': 'cancelled',
              'cancelled_by': 'patient',
              'cancelled_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', order['id']);

        // 2. ✅ CRÉER UNE NOTIFICATION POUR LA PHARMACIE
        final pharmacyId = order['pharmacy_id'];
        if (pharmacyId != null) {
          final medicine = order['medicines'] as Map<String, dynamic>?;
          
          await Supabase.instance.client.from('notifications').insert({
            'user_id': pharmacyId,
            'type': 'order_cancelled',
            'title': 'Commande annulée par un patient',
            'message': 'La commande #${order['id'].toString().substring(0, 8)} a été annulée par le patient.',
            'data': {
              'orderId': order['id'],
              'medicineName': medicine?['name'],
              'patientId': user.id,
              'cancelledBy': 'patient',
              'type': 'order_cancellation',
            },
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
          
          print('✅ Notification d\'annulation envoyée à la pharmacie: $pharmacyId');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Commande annulée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Rafraîchir la liste
          _loadPastOrders();
        }
      } catch (e) {
        print('❌ Erreur annulation: $e');
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

  Future<void> _deletePastOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la commande'),
        content: const Text('Voulez-vous vraiment supprimer cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Supabase.instance.client
            .from('reservations')
            .delete()
            .eq('id', orderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Commande supprimée'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPastOrders();
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'accepted': return 'Acceptée';
      case 'completed': return 'Terminée';
      case 'rejected': return 'Refusée';
      case 'cancelled': return 'Annulée';
      default: return 'Inconnu';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.pending_actions;
      case 'accepted': return Icons.check_circle_outline;
      case 'completed': return Icons.done_all;
      case 'rejected': return Icons.cancel_outlined;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 8),
            Text('Mon Panier'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Panier actuel'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentCartTab(),
          _buildOrderHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCurrentCartTab() {
    return Consumer<CartService>(
      builder: (context, cartService, _) {
        if (cartService.cart.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 100,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Votre panier est vide',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/search'),
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher un médicament'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartService.cart.length,
                itemBuilder: (context, index) {
                  final item = cartService.cart[index];
                  return _buildCartItem(item, index, cartService);
                },
              ),
            ),
            _buildCheckoutSection(cartService),
          ],
        );
      },
    );
  }

  Widget _buildOrderHistoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('all', 'Toutes'),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'En attente'),
              const SizedBox(width: 8),
              _buildFilterChip('accepted', 'Acceptées'),
              const SizedBox(width: 8),
              _buildFilterChip('completed', 'Terminées'),
              const SizedBox(width: 8),
              _buildFilterChip('rejected', 'Refusées'),
              const SizedBox(width: 8),
              _buildFilterChip('cancelled', 'Annulées'),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: _isLoadingOrders
              ? const Center(child: CircularProgressIndicator())
              : _pastOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune commande',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPastOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pastOrders.length,
                        itemBuilder: (context, index) {
                          return _buildPastOrderCard(_pastOrders[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _orderFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() => _orderFilter = key);
        _loadPastOrders();
      },
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal,
    );
  }

  Widget _buildCartItem(CartItem item, int index, CartService cartService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: const Icon(Icons.medication, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicineName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        item.pharmacyName,
                        style: TextStyle(color: Colors.teal.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer'),
                        content: const Text('Supprimer cet article ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () {
                              cartService.removeFromCart(index);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildInfoChip(Icons.science, '${item.dosage} - ${item.form}'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.attach_money, '${item.price.toStringAsFixed(0)} FCFA'),
                const Spacer(),
                Text(
                  'x${item.quantity}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${item.totalPrice.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NOUVELLE MÉTHODE AVEC BOUTON ANNULER
  Widget _buildPastOrderCard(Map<String, dynamic> order) {
    final medicine = order['medicines'] as Map<String, dynamic>?;
    final pharmacy = order['pharmacies'] as Map<String, dynamic>?;
    final status = order['status'] as String? ?? 'pending';
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0;
    final isPending = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${order['id'].toString().substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _formatDate(order['created_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_getStatusText(status), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: _getStatusColor(status),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') _deletePastOrder(order['id']);
                    if (value == 'cancel' && isPending) _cancelPastOrder(order);
                  },
                  itemBuilder: (context) => [
                    if (isPending)
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(children: const [
                          Icon(Icons.cancel, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Annuler'),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: const [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Supprimer'),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Icon(Icons.medication, color: Colors.teal.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine?['name'] ?? 'Médicament',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${medicine?['dosage']} - ${medicine?['form']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.local_pharmacy, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pharmacie: ${pharmacy?['name'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (pharmacy?['address'] != null)
                            Text(pharmacy!['address'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_basket, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Quantité: ${order['quantity']}'),
                      ],
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
                
                // ✅ BOUTON ANNULER (uniquement pour les commandes en attente)
                if (isPending) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _cancelPastOrder(order),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Annuler la commande'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(CartService cartService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${cartService.totalPrice.toStringAsFixed(0)} FCFA',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cancelOrder,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Annuler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _confirmOrder,
                  icon: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle, size: 24),
                  label: Text(_isProcessing ? 'Traitement...' : 'Confirmer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}