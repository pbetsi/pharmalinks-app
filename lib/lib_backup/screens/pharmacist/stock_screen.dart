import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_medicine_screen.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _stocks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _pharmacyId;

  final List<String> _forms = [
    'comprimé', 'gélule', 'sirop', 'injectable', 'pommade', 'sachet', 'autre'
  ];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Non connecté');

      final pharmacyRes = await _client
          .from('pharmacies')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (pharmacyRes == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucune pharmacie liée à votre compte.';
        });
        return;
      }

      _pharmacyId = pharmacyRes['id'];
      final stocksRes = await _client
          .from('stocks')
          .select('id, quantity, price, batch_number, expiry_date, medicines(id, name, dci, dosage, form)')
          .eq('pharmacy_id', _pharmacyId!);

      setState(() {
        _stocks = List<Map<String, dynamic>>.from(stocksRes);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  /// 📝 Dialogue de modification complète
  void _showEditDialog(Map<String, dynamic> stock) {
    final med = stock['medicines'] as Map<String, dynamic>;
    final medicineId = med['id'] as String;
    final stockId = stock['id'] as String;

    final nameCtrl = TextEditingController(text: med['name']);
    final dciCtrl = TextEditingController(text: med['dci'] ?? '');
    final dosageCtrl = TextEditingController(text: med['dosage'] ?? '');
    final priceCtrl = TextEditingController(text: stock['price'].toString());
    final qtyCtrl = TextEditingController(text: stock['quantity'].toString());
    final batchCtrl = TextEditingController(text: stock['batch_number'] ?? '');
    
    String selectedForm = med['form'] ?? 'comprimé';
    DateTime? selectedExpiry = stock['expiry_date'] != null 
        ? DateTime.parse(stock['expiry_date']) 
        : null;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('✏️ Modifier le médicament'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom *')),
                const SizedBox(height: 8),
                TextField(controller: dciCtrl, decoration: const InputDecoration(labelText: 'DCI (optionnel)')),
                const SizedBox(height: 8),
                TextField(controller: dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedForm,
                  decoration: const InputDecoration(labelText: 'Forme *'),
                  items: _forms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) => setStateDialog(() => selectedForm = val!),
                ),
                const SizedBox(height: 8),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix (FCFA) *')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité *')),
                const SizedBox(height: 8),
                TextField(controller: batchCtrl, decoration: const InputDecoration(labelText: 'N° de Lot')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(selectedExpiry != null ? 'Expiry: ${selectedExpiry!.toLocal().toString().split(' ')[0]}' : 'Date d\'expiry'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedExpiry ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setStateDialog(() => selectedExpiry = picked);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setStateDialog(() => isSaving = true);
                      try {
                        // 1. Mettre à jour le catalogue médicaments
                        await _client.from('medicines').update({
                          'name': nameCtrl.text.trim(),
                          'dci': dciCtrl.text.trim().isEmpty ? null : dciCtrl.text.trim(),
                          'dosage': dosageCtrl.text.trim(),
                          'form': selectedForm,
                          'updated_at': DateTime.now().toIso8601String(), // ✅ Correction ajoutée
                        }).eq('id', medicineId);

                        // 2. Mettre à jour le stock
                        await _client.from('stocks').update({
                          'price': double.parse(priceCtrl.text),
                          'quantity': int.parse(qtyCtrl.text),
                          'batch_number': batchCtrl.text.trim().isEmpty ? null : batchCtrl.text.trim(),
                          'expiry_date': selectedExpiry?.toIso8601String().split('T')[0],
                          'updated_at': DateTime.now().toIso8601String(), // ✅ Ajouté aussi pour stocks
                        }).eq('id', stockId);

                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadStocks();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Modifié avec succès'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// 🗑️ Dialogue de suppression
  void _showDeleteDialog(String stockId, String medicineName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Supprimer ?')]),
        content: Text('Retirer "$medicineName" du stock ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              try {
                await _client.from('stocks').delete().eq('id', stockId);
                Navigator.pop(ctx);
                _loadStocks();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🗑️ Supprimé du stock'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
    }

    if (_stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucun médicament en stock', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _stocks.length,
          itemBuilder: (context, index) {
            final item = _stocks[index];
            final med = item['medicines'] as Map<String, dynamic>;
            final qty = item['quantity'] as int;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: qty > 10 ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Icon(qty > 10 ? Icons.check_circle : Icons.warning_amber, color: qty > 10 ? Colors.green : Colors.orange),
                ),
                title: Text('${med['name']} ${med['dosage'] ?? ''} ${med['form'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Prix: ${item['price']} FCFA • Lot: ${item['batch_number'] ?? '-'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.teal),
                      onPressed: () => _showEditDialog(item),
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteDialog(item['id'], med['name']),
                      tooltip: 'Supprimer',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Bouton Flottant pour Ajouter
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddMedicineScreen(pharmacyId: _pharmacyId!)),
              );
              if (result == true) _loadStocks();
            },
            backgroundColor: Colors.teal.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
      ],
    );
  }
}