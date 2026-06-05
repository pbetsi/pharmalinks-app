import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientOrdersScreen extends StatefulWidget {
  const PatientOrdersScreen({super.key});

  @override
  State<PatientOrdersScreen> createState() => _PatientOrdersScreenState();
}

class _PatientOrdersScreenState extends State<PatientOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _setupRealtimeListener();
  }

  // ✅ LISTENER EN TEMPS RÉEL POUR SUPPRESSION AUTO
  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('patient_id', user.id)
        .listen((data) {
      print('🔄 Commandes mises à jour en temps réel: ${data.length}');
      _loadOrders(); // Recharger automatiquement
    });
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Déclarer query comme dynamic
      dynamic query = Supabase.instance.client
          .from('reservations')
          .select('''
            id,
            status,
            total_price,
            quantity,
            created_at,
            updated_at,
            pharmacy_id,
            medicines (
              name,
              dosage,
              form
            ),
            pharmacies (
              name,
              address
            )
          ''')
          .eq('patient_id', user.id);

      // Appliquer le filtre
      if (_selectedFilter != 'all') {
        query = query.eq('status', _selectedFilter);
      }

      // Exécuter la requête
      final response = await query.order('created_at', ascending: false);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement commandes: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ FONCTION POUR ANNULER UNE COMMANDE
  Future<void> _cancelOrder(String orderId, String pharmacyId, Map<String, dynamic> order) async {
    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Annuler la commande ?'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette commande ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non, garder'),
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

    if (confirm != true) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('🗑️ Annulation de la commande: $orderId');

      // 1. Mettre à jour le statut de la commande
      await Supabase.instance.client
          .from('reservations')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancelled_by': 'patient',
          })
          .eq('id', orderId);

      print('✅ Commande annulée avec succès');

      // 2. ✅ NOTIFIER LA PHARMACIE DE L'ANNULATION
      await _notifyPharmacyOfCancellation(
        pharmacyId,
        orderId,
        order['pharmacies']?['name'] ?? 'Pharmacie',
      );

      // 3. Recharger la liste (le temps réel le fera aussi)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Commande annulée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
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

  // ✅ NOTIFIER LA PHARMACIE DE L'ANNULATION
  Future<void> _notifyPharmacyOfCancellation(String pharmacyId, String orderId, String pharmacyName) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Récupérer le nom du patient
      final patientData = await Supabase.instance.client
          .from('users')
          .select('full_name, email')
          .eq('id', user.id)
          .single();

      final patientName = patientData['full_name'] ?? patientData['email'] ?? 'Un patient';

      // Créer la notification pour la pharmacie
      await Supabase.instance.client.from('notifications').insert({
        'user_id': pharmacyId,
        'type': 'order_cancelled',
        'title': 'Commande annulée par $patientName',
        'message': 'Le patient $patientName a annulé sa commande #${orderId.substring(0, 8)}',
        'data': {
          'orderId': orderId,
          'pharmacyName': pharmacyName,
          'patientName': patientName,
          'patientId': user.id,
          'medicineName': 'Médicament',
          'type': 'order_cancellation',
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Notification envoyée à la pharmacie: $pharmacyName');
    } catch (e) {
      print('❌ Erreur notification pharmacie: $e');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return 'Il y a ${difference.inDays}j';
      }
    } catch (e) {
      return '';
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
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Mes Commandes'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ✅ FILTRES AVEC CHIPS
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Toutes', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('En attente', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Acceptées', 'accepted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Terminées', 'completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Annulées', 'cancelled'),
                ],
              ),
            ),
          ),
          
          // Liste des commandes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucune commande',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final medicine = order['medicines'] as Map<String, dynamic>?;
                          final pharmacy = order['pharmacies'] as Map<String, dynamic>?;
                          final status = order['status'] as String;
                          final isCancelled = status == 'cancelled';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // En-tête avec ID et statut
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Commande #${order['id'].toString().substring(0, 8)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(status),
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Date
                                  Text(
                                    _formatDate(order['created_at']),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // Médicament
                                  if (medicine != null) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.medication, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                medicine['name'] ?? 'Médicament',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '${medicine['dosage']} - ${medicine['form']}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  
                                  // Pharmacie
                                  if (pharmacy != null) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.local_pharmacy, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            pharmacy['name'] ?? 'Pharmacie',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (pharmacy['address'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              pharmacy['address'],
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Quantité et prix
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Quantité: ${order['quantity'] ?? 0}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                      Text(
                                        '${order['total_price'] ?? 0} FCFA',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // ✅ BOUTON ANNULER (seulement si en attente)
                                  if (!isCancelled && status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _cancelOrder(
                                          order['id'],
                                          order['pharmacy_id'] ?? '',
                                          order,
                                        ),
                                        icon: const Icon(Icons.cancel, size: 18),
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _loadOrders();
      },
      backgroundColor: isSelected ? Colors.teal : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }
}