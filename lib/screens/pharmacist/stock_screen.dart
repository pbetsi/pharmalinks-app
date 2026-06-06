import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

import 'add_medicine_screen.dart';
import 'import_medicines_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // ✅ Filtres avancés
  bool _showOnlyLowStock = false;
  bool _showOnlyExpiring = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      var query = Supabase.instance.client
          .from('medicines')
          .select('*')
          .eq('pharmacy_id', user.id);

      // Filtre de recherche
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);
      List<Map<String, dynamic>> medicines = List<Map<String, dynamic>>.from(response);

      // ✅ Filtre local : Stock bas
      if (_showOnlyLowStock) {
        medicines = medicines.where((m) {
          final stock = m['stock_quantity'] ?? m['stock'] ?? 0;
          final threshold = m['min_stock_threshold'] ?? 10;
          return stock < threshold;
        }).toList();
      }

      // ✅ Filtre local : Expiration proche (< 90 jours)
      if (_showOnlyExpiring) {
        medicines = medicines.where((m) {
          final expDate = m['expiration_date'];
          if (expDate == null) return false;
          final daysLeft = DateTime.parse(expDate).difference(DateTime.now()).inDays;
          return daysLeft < 90 && daysLeft >= 0;
        }).toList();
      }

      setState(() {
        _medicines = medicines;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ MÉTHODE D'EXPORT CSV AMÉLIORÉE
  Future<void> _exportStockToCsv() async {
    if (_medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Aucun médicament à exporter'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // Créer les en-têtes
      final List<List<dynamic>> rows = [
        [
          'Nom', 'Dosage', 'Forme', 'Prix (FCFA)', 'Stock', 
          'Seuil alerte', 'Date expiration', 'Lot', 'Fabricant', 
          'Catégorie', 'Ordonnance'
        ],
      ];

      // Ajouter les données
      for (var med in _medicines) {
        final expDate = med['expiration_date'];
        final formattedDate = expDate != null 
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(expDate)) 
            : 'Non définie';
        
        rows.add([
          med['name'] ?? '',
          med['dosage'] ?? '',
          med['form'] ?? '',
          med['price'] ?? 0,
          med['stock_quantity'] ?? med['stock'] ?? 0,
          med['min_stock_threshold'] ?? 10,
          formattedDate,
          med['batch_number'] ?? '',
          med['manufacturer'] ?? '',
          med['category'] ?? '',
          med['requires_prescription'] == true ? 'Oui' : 'Non',
        ]);
      }

      // Convertir en CSV
      final csv = const ListToCsvConverter().convert(rows);
      final filename = 'stock_pharmacie_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      // Partager le fichier
      await Share.shareXFiles(
        [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: filename)],
        subject: 'Export Stock - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        text: 'Voici votre export de stock en pièce jointe.',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Export réussi : $filename'), backgroundColor: Colors.green),
      );
    } catch (e) {
      print('❌ Erreur export: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur export: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ AFFICHER LES DÉTAILS D'UN MÉDICAMENT (Bottom Sheet)
  void _showMedicineDetails(Map<String, dynamic> medicine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
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
              const SizedBox(height: 16),
              Text(medicine['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              _buildDetailRow('Dosage', medicine['dosage'] ?? ''),
              _buildDetailRow('Forme', medicine['form'] ?? ''),
              _buildDetailRow('Prix', '${medicine['price']} FCFA'),
              _buildDetailRow('Stock', '${medicine['stock_quantity'] ?? medicine['stock'] ?? 0} unités'),
              _buildDetailRow('Seuil alerte', '${medicine['min_stock_threshold'] ?? 10} unités'),
              _buildDetailRow('Lot', medicine['batch_number'] ?? 'Non renseigné'),
              _buildDetailRow('Fabricant', medicine['manufacturer'] ?? 'Non renseigné'),
              _buildDetailRow('Catégorie', medicine['category'] ?? 'Non renseigné'),
              
              const SizedBox(height: 12),
              if (medicine['expiration_date'] != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isExpiringSoon(medicine['expiration_date']) ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isExpiringSoon(medicine['expiration_date']) ? Icons.warning : Icons.check_circle,
                        color: _isExpiringSoon(medicine['expiration_date']) ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Expiration: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(medicine['expiration_date']))}',
                          style: TextStyle(
                            color: _isExpiringSoon(medicine['expiration_date']) ? Colors.red.shade900 : Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (medicine['requires_prescription'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text('Ordonnance requise', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editMedicine(medicine);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(medicine);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  bool _isExpiringSoon(String? expDate) {
    if (expDate == null) return false;
    final daysLeft = DateTime.parse(expDate).difference(DateTime.now()).inDays;
    return daysLeft < 90 && daysLeft >= 0;
  }

  void _confirmDelete(Map<String, dynamic> medicine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer ce médicament ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${medicine['name']}" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteMedicine(medicine);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMedicine() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicineScreen()));
    if (result == true && mounted) {
      await _loadMedicines();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Médicament ajouté'), backgroundColor: Colors.green));
    }
  }

  void _editMedicine(Map<String, dynamic> medicine) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddMedicineScreen(medicine: medicine)));
    if (result == true && mounted) {
      await _loadMedicines();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Médicament modifié'), backgroundColor: Colors.green));
    }
  }

  Future<void> _deleteMedicine(Map<String, dynamic> medicine) async {
    try {
      setState(() => _medicines.removeWhere((m) => m['id'] == medicine['id']));
      await Supabase.instance.client.from('medicines').delete().eq('id', medicine['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "${medicine['name']}" supprimé'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('❌ Erreur suppression: $e');
      _loadMedicines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.medication, color: Colors.white), SizedBox(width: 8), Text('Stock de médicaments')]),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Bouton Export CSV
          IconButton(icon: const Icon(Icons.file_download, color: Colors.white), onPressed: _exportStockToCsv, tooltip: 'Exporter en CSV'),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('${_medicines.length} médicament${_medicines.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMedicines, tooltip: 'Actualiser'),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Recherche + Filtres
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un médicament...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() => _searchQuery = ''); _loadMedicines(); }) : null,
                    filled: true,
                    fillColor: Colors.teal.shade50,
                  ),
                  onChanged: (val) { setState(() => _searchQuery = val); _loadMedicines(); },
                ),
                const SizedBox(height: 12),
                // ✅ Filtres rapides (Chips)
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('🔴 Stock bas'),
                      selected: _showOnlyLowStock,
                      onSelected: (val) { setState(() => _showOnlyLowStock = val); _loadMedicines(); },
                    ),
                    FilterChip(
                      label: const Text('⏰ Expiration proche'),
                      selected: _showOnlyExpiring,
                      onSelected: (val) { setState(() => _showOnlyExpiring = val); _loadMedicines(); },
                    ),
                    if (_showOnlyLowStock || _showOnlyExpiring)
                      FilterChip(
                        label: const Text('✕ Effacer'),
                        selected: false,
                        onSelected: (_) { setState(() { _showOnlyLowStock = false; _showOnlyExpiring = false; }); _loadMedicines(); },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 📋 Liste/Grid des médicaments
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _medicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medication_outlined, size: 100, color: Colors.teal.shade200),
                            const SizedBox(height: 16),
                            const Text('Aucun médicament', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(onPressed: _addMedicine, icon: const Icon(Icons.add), label: const Text('Ajouter un médicament'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
                        itemCount: _medicines.length,
                        itemBuilder: (context, index) {
                          final med = _medicines[index];
                          return MedicineCard(
                            medicine: med,
                            onTap: () => _showMedicineDetails(med),
                            onEdit: () => _editMedicine(med),
                            onDelete: () => _confirmDelete(med),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ✅ Boutons flottants : Import + Ajouter
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportMedicinesScreen())).then((_) => _loadMedicines()),
              icon: const Icon(Icons.file_upload),
              label: const Text("Import CSV"),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add),
              label: const Text("Ajouter"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ WIDGET : MedicineCard avec alertes visuelles et interactions
class MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MedicineCard({super.key, required this.medicine, this.onTap, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final int stock = medicine['stock'] ?? medicine['stock_quantity'] ?? 0;
    final int threshold = medicine['min_stock_threshold'] ?? 10;
    final bool isLowStock = stock < threshold;

    DateTime? expiration;
    if (medicine['expiration_date'] != null) {
      try { expiration = DateTime.parse(medicine['expiration_date'].toString()); } catch (e) {}
    }
    final int daysToExpiration = expiration != null ? expiration.difference(DateTime.now()).inDays : 999;

    String expiryStatusText = 'Valide';
    Color expiryColor = Colors.green;
    IconData expiryIcon = Icons.check_circle;

    if (daysToExpiration < 0) { expiryStatusText = 'EXPIRÉ'; expiryColor = Colors.red.shade900; expiryIcon = Icons.warning; }
    else if (daysToExpiration < 90) { expiryStatusText = 'Expire bientôt'; expiryColor = Colors.orange; expiryIcon = Icons.info; }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: (isLowStock || daysToExpiration < 90) ? Colors.orange.withOpacity(0.2) : Colors.black.withOpacity(0.08), blurRadius: (isLowStock || daysToExpiration < 90) ? 12 : 8, offset: const Offset(0, 4))],
            border: Border.all(color: (isLowStock || daysToExpiration < 90) ? Colors.orange.shade300 : Colors.grey.shade200, width: (isLowStock || daysToExpiration < 90) ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bouton supprimer (en haut à droite)
              if (onDelete != null)
                Align(alignment: Alignment.topRight, child: Container(margin: const EdgeInsets.all(4), child: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: onDelete, padding: const EdgeInsets.all(4), style: IconButton.styleFrom(backgroundColor: Colors.red.shade50)))),
              
              // Image du médicament
              Expanded(flex: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: medicine['image_url'] != null && medicine['image_url'].toString().isNotEmpty ? Image.network(medicine['image_url'], width: double.infinity, height: double.infinity, fit: BoxFit.contain, loadingBuilder: (c, child, progress) => progress == null ? child : Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorBuilder: (c, e, s) => Container(color: Colors.grey[100], child: Icon(Icons.medication, size: 50, color: Colors.teal.shade300))) : Container(color: Colors.grey[100], child: Icon(Icons.medication, size: 50, color: Colors.teal.shade300))))),
              
              // Infos du médicament
              Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(medicine['name'] ?? 'Sans nom', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${medicine['dosage'] ?? ''} ${medicine['form'] ?? ''}'.trim(), style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
                const Spacer(),
                
                // Badges Stock & Expiration
                Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isLowStock ? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isLowStock ? Icons.inventory_2_outlined : Icons.check, size: 12, color: isLowStock ? Colors.red : Colors.green), const SizedBox(width: 2), Text('$stock', style: TextStyle(color: isLowStock ? Colors.red.shade900 : Colors.green.shade900, fontSize: 10, fontWeight: FontWeight.bold))])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: expiryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(expiryIcon, size: 12, color: expiryColor), const SizedBox(width: 2), Text(expiryStatusText == 'Valide' ? '' : expiryStatusText, style: TextStyle(color: expiryColor, fontSize: 9, fontWeight: FontWeight.bold))])),
                ]),
                
                const SizedBox(height: 4),
                Text('${medicine['price'] ?? 0} FCFA', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 6),
                
                // Bouton Modifier
                if (onEdit != null) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 12), label: const Text('Modifier', style: TextStyle(fontSize: 10)), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))))),
              ]))),
            ],
          ),
        ),
      ),
    );
  }
}