import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      var query = Supabase.instance.client
          .from('medicines')
          .select('*')
          .eq('pharmacy_id', user.id);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        _medicines = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicineScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadMedicines();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Médicament ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _editMedicine(Map<String, dynamic> medicine) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(medicine: medicine),
      ),
    );

    if (result == true && mounted) {
      await _loadMedicines();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Médicament modifié avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteMedicine(Map<String, dynamic> medicine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer ce médicament ?'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${medicine['name']}" ?\n\n'
          'Cette action est irréversible.',
        ),
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

    if (confirm == true) {
      try {
        setState(() {
          _medicines.removeWhere((m) => m['id'] == medicine['id']);
        });

        await Supabase.instance.client
            .from('medicines')
            .delete()
            .eq('id', medicine['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('✅ "${medicine['name']}" supprimé avec succès'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
        _loadMedicines();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication, color: Colors.white),
            SizedBox(width: 8),
            Text('Stock de médicaments'),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_medicines.length} médicament${_medicines.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMedicines,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un médicament...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                filled: true,
                fillColor: Colors.teal.shade50,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadMedicines();
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _medicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 100,
                              color: Colors.teal.shade200,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucun médicament',
                              style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _addMedicine,
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un médicament'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _medicines.length,
                        itemBuilder: (context, index) {
                          final med = _medicines[index];
                          return MedicineCard(
                            medicine: med,
                            onEdit: () => _editMedicine(med),
                            onDelete: () => _deleteMedicine(med),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ✅ BOUTONS FLOTTANTS : Import CSV + Ajouter
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Bouton Import CSV
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportMedicinesScreen(),
                  ),
                ).then((_) => _loadMedicines());
              },
              icon: const Icon(Icons.file_download),
              label: const Text("Import CSV"),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // ✅ Bouton Ajouter
            ElevatedButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add),
              label: const Text("Ajouter"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ WIDGET : MedicineCard avec alertes stock et expiration
class MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int stock = medicine['stock'] ?? medicine['stock_quantity'] ?? 0;
    final int threshold = medicine['min_stock_threshold'] ?? 10;
    final bool isLowStock = stock < threshold;

    DateTime? expiration;
    if (medicine['expiration_date'] != null) {
      try {
        expiration = DateTime.parse(medicine['expiration_date'].toString());
      } catch (e) {
        // Si la date est invalide, on ignore
      }
    }
    
    final int daysToExpiration = expiration != null 
        ? expiration.difference(DateTime.now()).inDays 
        : 999;

    String expiryStatusText = 'Valide';
    Color expiryColor = Colors.green;
    IconData expiryIcon = Icons.check_circle;

    if (daysToExpiration < 0) {
      expiryStatusText = 'EXPIRÉ !';
      expiryColor = Colors.red.shade900;
      expiryIcon = Icons.warning;
    } else if (daysToExpiration < 90) {
      expiryStatusText = 'Expire bientôt';
      expiryColor = Colors.orange;
      expiryIcon = Icons.info;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isLowStock || daysToExpiration < 90
                  ? Colors.orange.withOpacity(0.2) 
                  : Colors.black.withOpacity(0.08),
              blurRadius: isLowStock || daysToExpiration < 90 ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isLowStock || daysToExpiration < 90
                ? Colors.orange.shade300 
                : Colors.grey.shade200,
            width: isLowStock || daysToExpiration < 90 ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onDelete != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Supprimer',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ),
              ],
            ),
            
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: medicine['image_url'] != null && medicine['image_url'].toString().isNotEmpty
                      ? Image.network(
                          medicine['image_url'],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.medication,
                                size: 50,
                                color: Colors.teal.shade300,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.medication,
                            size: 50,
                            color: Colors.teal.shade300,
                          ),
                        ),
                ),
              ),
            ),
            
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      medicine['name'] ?? 'Sans nom',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    
                    Text(
                      '${medicine['dosage'] ?? ''} ${medicine['form'] ?? ''}'.trim(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Spacer(),
                    
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLowStock ? Colors.red.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLowStock ? Icons.inventory_2_outlined : Icons.check,
                                size: 12,
                                color: isLowStock ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$stock',
                                style: TextStyle(
                                  color: isLowStock ? Colors.red.shade900 : Colors.green.shade900,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: expiryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(expiryIcon, size: 12, color: expiryColor),
                              const SizedBox(width: 2),
                              Text(
                                expiryStatusText == 'Valide' ? '' : expiryStatusText,
                                style: TextStyle(
                                  color: expiryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${medicine['price'] ?? 0} FCFA',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    if (onEdit != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit, size: 12),
                          label: const Text(
                            'Modifier',
                            style: TextStyle(fontSize: 10),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}