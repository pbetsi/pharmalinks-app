import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPharmaciesScreen extends StatefulWidget {
  const AdminPharmaciesScreen({super.key});

  @override
  State<AdminPharmaciesScreen> createState() => _AdminPharmaciesScreenState();
}

class _AdminPharmaciesScreenState extends State<AdminPharmaciesScreen> {
  List<Map<String, dynamic>> _pendingPharmacies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingPharmacies();
  }

  // 🔓 NOUVELLE FONCTION : Déconnexion
  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Redirection vers la page de connexion
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la déconnexion: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPendingPharmacies() async {
    try {
      final response = await Supabase.instance.client
          .from('pharmacies')
          .select('*')
          .eq('is_verified', false)
          .order('created_at', ascending: false);

      setState(() {
        _pendingPharmacies = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPharmacy(String pharmacyId, bool verified) async {
    try {
      await Supabase.instance.client
          .from('pharmacies')
          .update({
            'is_verified': verified,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pharmacyId);

      setState(() {
        _pendingPharmacies.removeWhere((p) => p['id'] == pharmacyId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verified ? '✅ Pharmacie validée' : '❌ Pharmacie rejetée',
            ),
            backgroundColor: verified ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur validation: $e');
    }
  }

  void _showPharmacyDetails(Map<String, dynamic> pharmacy) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Détails de la pharmacie'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('🏥 Nom', pharmacy['name']),
              _buildDetailRow('👤 Propriétaire', pharmacy['owner_name']),
              _buildDetailRow('📧 Email', pharmacy['email']),
              _buildDetailRow('📞 Téléphone', pharmacy['phone']),
              _buildDetailRow('📍 Ville', pharmacy['city']),
              _buildDetailRow('🏠 Adresse', pharmacy['address']),
              _buildDetailRow('🌍 Pays', pharmacy['country']),
              const SizedBox(height: 12),
              Text(
                '📍 Coordonnées GPS:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Lat: ${pharmacy['latitude']}'),
              Text('Lng: ${pharmacy['longitude']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Validation des Pharmacies'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // ✅ BOUTON DÉCONNEXION
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingPharmacies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 72,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune pharmacie en attente',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingPharmacies.length,
                  itemBuilder: (context, index) {
                    final pharmacy = _pendingPharmacies[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.local_pharmacy, color: Colors.white),
                        ),
                        title: Text(pharmacy['name'] ?? 'Sans nom'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pharmacy['owner_name'] ?? ''),
                            Text(pharmacy['city'] ?? ''),
                            Text(
                              'Inscrit le: ${DateTime.parse(pharmacy['created_at']).toString().substring(0, 10)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        onTap: () => _showPharmacyDetails(pharmacy),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _verifyPharmacy(pharmacy['id'], true),
                              tooltip: 'Valider',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _verifyPharmacy(pharmacy['id'], false),
                              tooltip: 'Rejeter',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadPendingPharmacies,
        tooltip: 'Rafraîchir',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}