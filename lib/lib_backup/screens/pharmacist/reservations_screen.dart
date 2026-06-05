import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PharmacistReservationsScreen extends StatefulWidget {
  const PharmacistReservationsScreen({super.key});

  @override
  State<PharmacistReservationsScreen> createState() => _PharmacistReservationsScreenState();
}

class _PharmacistReservationsScreenState extends State<PharmacistReservationsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String? _pharmacyId;
  String? _errorMessage;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadPharmacyAndReservations();
  }

  Future<void> _loadPharmacyAndReservations() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() { _isLoading = false; _errorMessage = "Utilisateur non connecté."; });
        return;
      }

      final pharmacyRes = await _client
          .from('pharmacies')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle(); 

      if (pharmacyRes == null || pharmacyRes['id'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Ce compte n'est lié à aucune pharmacie. Contactez l'admin.";
        });
        return;
      }

      _pharmacyId = pharmacyRes['id'];

      final queryBuilder = _client
          .from('reservations')
          .select('id, quantity, status, created_at, medicines(name), users(full_name, phone)')
          .eq('pharmacy_id', _pharmacyId!);

      if (_showArchived) {
        queryBuilder.eq('status', 'completed');
      } else {
        queryBuilder.inFilter('status', ['pending', 'confirmed', 'ready']);
      }

      final resRes = await queryBuilder.order('created_at', ascending: false);

      setState(() {
        _reservations = List<Map<String, dynamic>>.from(resRes);
        _isLoading = false;
      });

    } catch (e) {
      print("Erreur chargement: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Erreur réseau: $e";
      });
    }
  }

  Future<void> _confirmOrder(String resId) async {
    await _client.from('reservations').update({'status': 'confirmed'}).eq('id', resId);
    _loadPharmacyAndReservations();
  }

  Future<void> _archiveOrder(String resId) async {
    await _client.from('reservations').update({'status': 'completed'}).eq('id', resId);
    _loadPharmacyAndReservations();
  }

  Future<void> _deleteReservation(String resId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la commande'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _client.from('reservations').delete().eq('id', resId);
      _loadPharmacyAndReservations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Commande supprimée'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ✅ FONCTION DE NOTIFICATION WHATSAPP/SMS
  Future<void> _notifyPatient(Map<String, dynamic> res, String type) async {
    final patientPhone = res['users']['phone'];
    final medName = res['medicines']['name'];
    
    if (patientPhone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Numéro de téléphone non disponible'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    String message = "Bonjour, votre commande de $medName est confirmée chez Pharmalink. Passez la récupérer !";
    String url = "";
    
    // Nettoyer le numéro (enlever espaces, +, tirets)
    String cleanPhone = patientPhone.replaceAll(RegExp(r'[\s\+\-]'), '');

    if (type == 'whatsapp') {
      url = "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}";
    } else {
      url = "sms:$cleanPhone?body=${Uri.encodeComponent(message)}";
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible d'ouvrir l'application"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔀 BARRE DE FILTRE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.teal.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showArchived ? '📦 Archives (Livrées)' : '📋 Commandes en cours',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Switch(
                value: _showArchived,
                onChanged: (val) {
                  setState(() => _showArchived = val);
                  _loadPharmacyAndReservations();
                },
                activeColor: Colors.teal,
              ),
            ],
          ),
        ),

        // ✅ GESTION DES ÉTATS D'AFFICHAGE
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 50, color: Colors.red),
                            const SizedBox(height: 10),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadPharmacyAndReservations,
                              child: const Text("Réessayer"),
                            )
                          ],
                        ),
                      ),
                    )
                  : _reservations.isEmpty
                      ? Center(
                          child: Text(
                            _showArchived ? 'Aucune commande archivée.' : 'Aucune commande en attente.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reservations.length,
                          itemBuilder: (context, index) {
                            final res = _reservations[index];
                            final status = res['status'];
                            final patientPhone = res['users']['phone'];
                            final isPending = status == 'pending';
                            final isConfirmed = status == 'confirmed';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPending 
                                      ? Colors.orange.shade100 
                                      : (isConfirmed ? Colors.blue.shade100 : Colors.green.shade100),
                                  child: Icon(
                                    isPending ? Icons.pending_actions : (isConfirmed ? Icons.check_circle : Icons.archive),
                                    color: isPending ? Colors.orange : (isConfirmed ? Colors.blue : Colors.green),
                                  ),
                                ),
                                title: Text(res['medicines']['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('👤 ${res['users']['full_name'] ?? 'Patient'}'),
                                    Text('📦 Qté: ${res['quantity']}'),
                                    Text('📅 ${DateTime.parse(res['created_at']).toLocal().toString().split(' ')[0]}'),
                                    if (patientPhone != null)
                                      Text('📞 $patientPhone', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                                  ],
                                ),
                                // ✅ TRAILING AVEC BOUTONS DE NOTIFICATION
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✅ BOUTONS WHATSAPP ET SMS (seulement si pending)
                                    if (isPending) ...[
                                      IconButton(
                                        icon: const Icon(Icons.message, color: Colors.green, size: 26),
                                        onPressed: () => _notifyPatient(res, 'whatsapp'),
                                        tooltip: 'WhatsApp',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.sms, color: Colors.orange, size: 26),
                                        onPressed: () => _notifyPatient(res, 'sms'),
                                        tooltip: 'SMS',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // BOUTON CONFIRMER
                                    if (isPending)
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                        onPressed: () => _confirmOrder(res['id']),
                                        tooltip: 'Confirmer',
                                      ),
                                    // BOUTON LIVRER
                                    if (isConfirmed)
                                      IconButton(
                                        icon: const Icon(Icons.local_shipping, color: Colors.teal, size: 30),
                                        onPressed: () => _archiveOrder(res['id']),
                                        tooltip: 'Livrer',
                                      ),
                                    // ICÔNE ARCHIVE
                                    if (status == 'completed')
                                      const Icon(Icons.archive_outlined, color: Colors.grey, size: 28),
                                    // BOUTON SUPPRIMER
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteReservation(res['id']),
                                      tooltip: 'Supprimer',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}