import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _confirmOrder() async {
    final cartService = context.read<CartService>();
    if (cartService.cart.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la commande'),
        content: Text(
          'Voulez-vous vraiment confirmer cette commande de ${cartService.totalPrice.toStringAsFixed(0)} FCFA ?\n\nLe pharmacien recevra une notification.',
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

        // Récupérer les infos du patient
        final patientData = await Supabase.instance.client
            .from('users')
            .select('full_name, phone')
            .eq('id', user.id)
            .single();

        // Créer les réservations et notifier les pharmacies
        final pharmacyNotifications = <String, List<Map<String, dynamic>>>{};

        for (final item in cartService.cart) {
          // Créer la réservation
          final reservation = await Supabase.instance.client
              .from('reservations')
              .insert({
                'patient_id': user.id,
                'pharmacy_id': item.pharmacyId,
                'medicine_id': item.medicineId,
                'quantity': item.quantity,
                'unit_price': item.price,
                'total_price': item.totalPrice,
                'status': 'pending',
                'patient_name': patientData['full_name'] ?? 'Patient',
                'patient_phone': patientData['phone'] ?? '',
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          print('✅ Réservation créée: ${reservation['id']}');

          // Préparer la notification pour cette pharmacie
          if (!pharmacyNotifications.containsKey(item.pharmacyId)) {
            pharmacyNotifications[item.pharmacyId] = [];
          }
          
          pharmacyNotifications[item.pharmacyId]!.add({
            'user_id': item.pharmacyId,
            'type': 'reservation',
            'title': 'Nouvelle commande',
            'message': '${patientData['full_name'] ?? 'Un patient'} a commandé ${item.medicineName} (x${item.quantity})',
            'data': {
              'reservationId': reservation['id'],
              'medicineName': item.medicineName,
              'quantity': item.quantity,
              'totalPrice': item.totalPrice,
              'patientId': user.id,
              'patientName': patientData['full_name'] ?? 'Patient',
            },
            'read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // Envoyer toutes les notifications aux pharmacies
        for (final notifications in pharmacyNotifications.values) {
          await Supabase.instance.client
              .from('notifications')
              .insert(notifications);
        }

        print('✅ ${pharmacyNotifications.length} pharmacie(s) notifiée(s)');

        // Vider le panier
        cartService.clearCart();

        if (mounted) {
          setState(() => _isProcessing = false);
          
          // Afficher succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Commande confirmée ! Le pharmacien a été notifié.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Retourner à l'accueil
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/patient-home',
              (route) => false,
            );
          }
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

  void _cancelOrder() async {
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
      final cartService = context.read<CartService>();
      cartService.clearCart();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Commande annulée'),
          backgroundColor: Colors.orange,
        ),
      );
      
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/patient-home',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, color: Colors.white),
            SizedBox(width: 8),
            Text('Détails de la commande'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, _) {
          if (cartService.cart.isEmpty) {
            return const Center(
              child: Text(
                'Aucun article dans le panier',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              // Liste des articles
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartService.cart.length,
                  itemBuilder: (context, index) {
                    final item = cartService.cart[index];
                    return _buildOrderItem(item);
                  },
                ),
              ),

              // Résumé et boutons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Total
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total à payer:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            '${cartService.totalPrice.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        // Bouton Annuler
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _cancelOrder,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Annuler'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bouton Confirmer
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _confirmOrder,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(_isProcessing ? 'Traitement...' : 'Confirmer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.pharmacyName,
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Détails
            Row(
              children: [
                _buildDetailChip(Icons.science, '${item.dosage} - ${item.form}'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.attach_money, '${item.price.toStringAsFixed(0)} FCFA'),
              ],
            ),
            const SizedBox(height: 8),
            
            // Quantité et total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Quantité: ${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  '${item.totalPrice.toStringAsFixed(0)} FCFA',
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

  Widget _buildDetailChip(IconData icon, String label) {
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
        style: TextStyle(fontSize: 12, color: Colors.grey[700] ?? Colors.grey),
          ),
        ],
      ),
    );
  }
}