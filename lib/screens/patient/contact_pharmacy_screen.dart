import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ContactPharmacyScreen extends StatefulWidget {
  const ContactPharmacyScreen({super.key});

  @override
  State<ContactPharmacyScreen> createState() => _ContactPharmacyScreenState();
}

class _ContactPharmacyScreenState extends State<ContactPharmacyScreen> {
  List<Map<String, dynamic>> _pharmacies = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadPharmacies();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (e) {
      print('❌ Erreur localisation: $e');
    }
  }

  Future<void> _loadPharmacies() async {
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client
          .from('pharmacies')
          .select('''
            *,
            medicines (
              id,
              name,
              dosage,
              form,
              price,
              stock_quantity
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true);

      if (_searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$_searchQuery%,city.ilike.%$_searchQuery%');
      }

      final response = await query;

      setState(() {
        _pharmacies = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement pharmacies: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startConversation(Map<String, dynamic> pharmacy) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Vérifier si une conversation existe déjà
      final existingConv = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('patient_id', user.id)
          .eq('pharmacy_id', pharmacy['id'])
          .maybeSingle();

      String conversationId;

      if (existingConv != null) {
        conversationId = existingConv['id'];
      } else {
        // Créer une nouvelle conversation
        final newConv = await Supabase.instance.client
            .from('conversations')
            .insert({
              'patient_id': user.id,
              'pharmacy_id': pharmacy['id'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        conversationId = newConv['id'];
      }

      // Naviguer vers l'écran de chat
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'pharmacyName': pharmacy['name'],
            'medicineName': 'Discussion générale',
          },
        );
      }
    } catch (e) {
      print('❌ Erreur création conversation: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 Contacter une Pharmacie'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une pharmacie...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadPharmacies();
              },
            ),
          ),

          // Liste des pharmacies
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pharmacies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_pharmacy, size: 100, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucune pharmacie trouvée',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pharmacies.length,
                        itemBuilder: (context, index) {
                          final pharmacy = _pharmacies[index];
                          final medicines = pharmacy['medicines'] as List? ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: const Icon(
                                  Icons.local_pharmacy,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                pharmacy['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pharmacy['address'] ?? ''),
                                  Text(pharmacy['city'] ?? ''),
                                  if (pharmacy['phone'] != null)
                                    Text('📞 ${pharmacy['phone']}'),
                                ],
                              ),
                              children: [
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '💊 Médicaments disponibles (${medicines.length})',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      if (medicines.isEmpty)
                                        const Text(
                                          'Aucun médicament enregistré',
                                          style: TextStyle(color: Colors.grey),
                                        )
                                      else
                                        ...medicines.take(5).map((med) => ListTile(
                                              leading: const Icon(Icons.medication),
                                              title: Text(med['name']),
                                              subtitle: Text('${med['dosage']} - ${med['form']}'),
                                              trailing: Text('${med['price']} FCFA'),
                                            )),
                                      if (medicines.length > 5)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            'Et ${medicines.length - 5} autres médicaments...',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _startConversation(pharmacy),
                                          icon: const Icon(Icons.chat),
                                          label: const Text('Contacter cette pharmacie'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}