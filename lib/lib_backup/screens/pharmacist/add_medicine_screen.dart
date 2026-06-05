import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMedicineScreen extends StatefulWidget {
  final String pharmacyId;
  const AddMedicineScreen({super.key, required this.pharmacyId});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _client = Supabase.instance.client;
  
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _batchController = TextEditingController();
  
  String? _selectedForm;
  String? _selectedMedicineId;
  List<Map<String, dynamic>> _existingMedicines = [];
  bool _isLoading = false;
  bool _isNewMedicine = true;

  final List<String> _forms = [
    'comprimé',
    'gélule',
    'sirop',
    'injectable',
    'pommade',
    'sachet',
    'autre'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingMedicines();
  }

  Future<void> _loadExistingMedicines() async {
    final response = await _client
        .from('medicines')
        .select('id, name, dci, dosage, form')
        .order('name');
    
    setState(() {
      _existingMedicines = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _addMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String medicineId = _selectedMedicineId ?? '';

      // Si nouveau médicament, le créer d'abord
      if (_isNewMedicine) {
        final medResponse = await _client.from('medicines').insert({
          'name': _medicineNameController.text.trim(),
          'dci': _medicineNameController.text.trim(),
          'dosage': _dosageController.text.trim(),
          'form': _selectedForm,
        }).select('id').single();

        medicineId = medResponse['id'];
      }

      // Créer le stock
      await _client.from('stocks').insert({
        'pharmacy_id': widget.pharmacyId,
        'medicine_id': medicineId,
        'quantity': int.parse(_quantityController.text),
        'price': double.parse(_priceController.text),
        'batch_number': _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Médicament ajouté au stock avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retour avec succès
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un médicament'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Choisir entre nouveau ou existant
            Card(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Nouveau médicament'),
                    value: true,
                    groupValue: _isNewMedicine,
                    onChanged: (val) => setState(() => _isNewMedicine = val!),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Médicament existant'),
                    value: false,
                    groupValue: _isNewMedicine,
                    onChanged: (val) => setState(() => _isNewMedicine = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

           // Si médicament existant
if (!_isNewMedicine)
  DropdownButtonFormField<String>(
    decoration: const InputDecoration(
      labelText: 'Sélectionner un médicament',
      border: OutlineInputBorder(),
    ),
    items: _existingMedicines.map((med) {
      return DropdownMenuItem<String>(
        value: med['id'] as String,
        child: Text('${med['name']} ${med['dosage'] ?? ''}'),
      );
    }).toList(),
    onChanged: (val) => setState(() => _selectedMedicineId = val),
    validator: (val) => _isNewMedicine ? null : (val == null ? 'Sélectionnez un médicament' : null),
  ),
            const SizedBox(height: 16),

            // Nom du médicament (si nouveau)
            if (_isNewMedicine)
              TextFormField(
                controller: _medicineNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du médicament *',
                  hintText: 'Ex: Paracétamol',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Requis' : null,
              ),

            const SizedBox(height: 16),

            // Dosage
            TextFormField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage *',
                hintText: 'Ex: 500mg',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Requis' : null,
            ),

            const SizedBox(height: 16),

            // Forme
            if (_isNewMedicine)
              DropdownButtonFormField<String>(
                value: _selectedForm,
                decoration: const InputDecoration(
                  labelText: 'Forme *',
                  border: OutlineInputBorder(),
                ),
                items: _forms.map((form) => DropdownMenuItem(value: form, child: Text(form))).toList(),
                onChanged: (val) => setState(() => _selectedForm = val),
                validator: (val) => _isNewMedicine && val == null ? 'Requis' : null,
              ),

            const SizedBox(height: 16),

            // Prix
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix (FCFA) *',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Requis' : null,
            ),

            const SizedBox(height: 16),

            // Quantité
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité *',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Requis' : null,
            ),

            const SizedBox(height: 16),

            // Numéro de lot (optionnel)
            TextFormField(
              controller: _batchController,
              decoration: const InputDecoration(
                labelText: 'Numéro de lot (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            // Bouton Ajouter
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addMedicine,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add),
              label: Text(_isLoading ? 'Ajout...' : 'Ajouter au stock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _batchController.dispose();
    super.dispose();
  }
}