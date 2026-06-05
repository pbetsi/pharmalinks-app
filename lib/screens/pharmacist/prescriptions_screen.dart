import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class PharmacistPrescriptionsScreen extends StatefulWidget {
  const PharmacistPrescriptionsScreen({super.key});

  @override
  State<PharmacistPrescriptionsScreen> createState() => _PharmacistPrescriptionsScreenState();
}

class _PharmacistPrescriptionsScreenState extends State<PharmacistPrescriptionsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _selectedStatus = 'pending'; // pending, accepted, rejected

  final List<Map<String, dynamic>> _tabs = [
    {'label': '📥 En attente', 'value': 'pending'},
    {'label': '✅ Validées', 'value': 'accepted'},
    {'label': '❌ Refusées', 'value': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadPrescriptions();
    _setupRealtimeListener();
  }

  // 🔥 Écouter les nouvelles ordonnances en temps réel
  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('prescriptions')
        .stream(primaryKey: ['id'])
        .eq('pharmacy_id', user.id)
        .order('created_at', ascending: false)
        .listen((data) {
          setState(() {
            _prescriptions = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        });
  }

  // 📦 Charger les ordonnances
  Future<void> _loadPrescriptions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('prescriptions')
          .select('''
            id,
            status,
            image_url,
            extracted_text,
            medicines,
            created_at,
            auth.users!prescriptions_patient_id_fkey (
              email,
              raw_user_meta_data
            )
          ''')
          .eq('pharmacy_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _prescriptions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement prescriptions: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Mettre à jour le statut
  Future<void> _updateStatus(String prescriptionId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('prescriptions')
          .update({'status': newStatus})
          .eq('id', prescriptionId);

      // TODO: Envoyer une notification au patient ici

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'accepted' ? '✅ Ordonnance validée' : '❌ Ordonnance refusée'),
          backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      print(' Erreur mise à jour: $e');
    }
  }

  // 📋 Afficher les détails de l'ordonnance
  void _showPrescriptionDetails(Map<String, dynamic> prescription) {
    List<dynamic> medicines = [];
    try {
      if (prescription['medicines'] is String) {
        medicines = jsonDecode(prescription['medicines']);
      } else if (prescription['medicines'] is List) {
        medicines = prescription['medicines'];
      }
    } catch (e) {
      // Fallback si erreur JSON
    }

    final patientData = prescription['auth.users'] as Map<String, dynamic>?;
    final patientName = patientData?['raw_user_meta_data']?['full_name'] 
                     ?? patientData?['email'] 
                     ?? 'Patient inconnu';

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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // En-tête Patient
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.person, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('Nouvelle ordonnance', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    _buildStatusChip(prescription['status']),
                  ],
                ),
                
                const Divider(height: 30),
                
                // Image de l'ordonnance
                if (prescription['image_url'] != null) ...[
                  const Text(' Ordonnance originale', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      prescription['image_url'],
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[200], child: const Center(child: Text('Image indisponible'))),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Liste des médicaments détectés (IA)
                const Text('💊 Médicaments détectés (IA)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...medicines.map((med) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.medication_liquid, color: Colors.orange),
                      title: Text(med['name'] ?? 'Médicament'),
                      subtitle: Text('Quantité: ${med['quantity'] ?? 1}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // TODO: Éditer le médicament manuellement
                        },
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),

                // Boutons d'action
                if (prescription['status'] == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(prescription['id'], 'rejected');
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Refuser'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(prescription['id'], 'accepted');
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Valider le stock'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String text;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        text = 'Validée';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Refusée';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        text = 'En attente';
    }
    return Chip(
      label: Text(text),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPrescriptions = _prescriptions.where((p) => 
      _selectedStatus == 'all' ? true : p['status'] == _selectedStatus
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(' Ordonnances'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: _tabs.map((tab) => Tab(text: tab['label'] as String)).toList(),
          onTap: (index) {
            setState(() {
              _selectedStatus = _tabs[index]['value'] as String;
            });
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredPrescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucune ordonnance ${_selectedStatus == 'pending' ? 'en attente' : ''}', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredPrescriptions.length,
                  itemBuilder: (context, index) {
                    final presc = filteredPrescriptions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showPrescriptionDetails(presc),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: const Icon(Icons.camera_alt, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Text('Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _buildStatusChip(presc['status']),
                          ],
                        ),
                        subtitle: Text('Reçue le ${_formatDate(presc['created_at'])}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month} ${date.hour}h${date.minute}';
  }
}