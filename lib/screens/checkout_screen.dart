import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      final cart = context.read<CartService>();
      
      // Récupérer les infos utilisateur
      final userData = await Supabase.instance.client
          .from('users')
          .select('full_name, phone')
          .eq('id', user.id)
          .single();

      // Créer une réservation par pharmacie
     final pharmacies = cart.cart.map((item) => item.pharmacyId).toSet();
      
      for (final pharmacyId in pharmacies) {
        final pharmacyItems = cart.cart.where((item) => item.pharmacyId == pharmacyId).toList();
        
        final totalPharmacy = pharmacyItems.fold(0.0, (sum, item) => sum + item.totalPrice);

        await Supabase.instance.client.from('reservations').insert({
          'patient_id': user.id,
          'pharmacy_id': pharmacyId,
          'medicine_id': pharmacyItems.first.medicineId, // Premier médicament
          'quantity': pharmacyItems.fold(0, (sum, item) => sum + item.quantity),
          'unit_price': pharmacyItems.first.price,
          'total_price': totalPharmacy,
          'status': 'pending',
          'notes': _notesController.text.trim(),
          'patient_name': userData['full_name'],
          'patient_phone': userData['phone'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Vider le panier
      cart.clearCart();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Réservation réussie !'),
            content: const Text(
              'Votre réservation a été envoyée aux pharmacies. Vous recevrez une confirmation bientôt.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur réservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Récapitulatif de la commande',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ...cart.cart.map((item) => Card(
              child: ListTile(
                title: Text(item.medicineName),
                subtitle: Text('${item.pharmacyName}\nQuantité: ${item.quantity}'),
                trailing: Text(
                  '${item.totalPrice.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )),

            const Divider(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${cart.totalPrice.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Informations complémentaires',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optionnel)',
                hintText: 'Ex: Préférence de livraison...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submitOrder,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirmer la réservation',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}