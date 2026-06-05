import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

class AddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic>? medicine;
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _dosageController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lotController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _categoryController = TextEditingController();

  String _selectedForm = 'comprimé';
  DateTime? _expiryDate;
  bool _requiresPrescription = false;
  int _minStockThreshold = 10;
  bool _isLoading = false;
  bool _isEditing = false;
  
  XFile? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;

  final List<String> _forms = [
    'comprimé', 'gélule', 'sirop', 'crème', 'pommade',
    'injectable', 'collyre', 'solution', 'poudre',
    'suppositoire', 'gouttes', 'spray',
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.medicine != null;
    
    if (_isEditing) {
      _nameController.text = widget.medicine?['name'] ?? '';
      _descController.text = widget.medicine?['description'] ?? '';
      _dosageController.text = widget.medicine?['dosage'] ?? '';
      _priceController.text = widget.medicine?['price']?.toString() ?? '';
      _stockController.text = (widget.medicine?['stock_quantity'] ?? widget.medicine?['stock'] ?? 0).toString();
      _lotController.text = widget.medicine?['lot_number'] ?? widget.medicine?['batch_number'] ?? '';
      _manufacturerController.text = widget.medicine?['manufacturer'] ?? '';
      _categoryController.text = widget.medicine?['category'] ?? '';
      _selectedForm = widget.medicine?['form'] ?? 'comprimé';
      _requiresPrescription = widget.medicine?['requires_prescription'] ?? false;
      _minStockThreshold = widget.medicine?['min_stock_threshold'] ?? 10;
      
      final expDate = widget.medicine?['expiry_date'] ?? widget.medicine?['expiration_date'];
      if (expDate != null) {
        try {
          _expiryDate = DateTime.parse(expDate.toString());
        } catch (e) {
          print('⚠️ Erreur parsing date: $e');
        }
      }
      _uploadedImageUrl = widget.medicine?['image_url'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dosageController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _lotController.dispose();
    _manufacturerController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final image = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) setState(() => _selectedImage = image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.pop(ctx);
                final image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (image != null) setState(() => _selectedImage = image);
              },
            ),
            if (_selectedImage != null || _uploadedImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer l\'image'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedImage = null;
                    _uploadedImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    setState(() => _isUploadingImage = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final bytes = await _selectedImage!.readAsBytes();
      final fileName = 'med_${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImage!.path)}';

      await Supabase.instance.client.storage
          .from('medicines-images')
          .uploadBinary('medicines/$fileName', bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('medicines-images')
          .getPublicUrl('medicines/$fileName');

      print('✅ Image uploadée: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Erreur upload image: $e');
      return null;
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  bool _isExpiringSoon() {
    if (_expiryDate == null) return false;
    final daysLeft = _expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft < 90;
  }

  String _getExpirationWarning() {
    if (_expiryDate == null) return '';
    final daysLeft = _expiryDate!.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return '⚠️ EXPIRÉ depuis ${-daysLeft} jours';
    if (daysLeft < 30) return '🔴 Expire dans $daysLeft jours - URGENT';
    if (daysLeft < 90) return '🟡 Expire dans $daysLeft jours - Bientôt';
    return '✅ Valide pendant $daysLeft jours';
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      String? finalImageUrl = _uploadedImageUrl;
      if (_selectedImage != null) {
        final uploadedUrl = await _uploadImage();
        if (uploadedUrl != null) finalImageUrl = uploadedUrl;
      }

      final medicineData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'form': _selectedForm,
        'price': double.parse(_priceController.text),
        'stock_quantity': int.parse(_stockController.text),
        'batch_number': _lotController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'category': _categoryController.text.trim(),
        'min_stock_threshold': _minStockThreshold,
        'expiration_date': _expiryDate?.toIso8601String(),
        'requires_prescription': _requiresPrescription,
        'image_url': finalImageUrl,
        'pharmacy_id': user.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (!_isEditing) {
        medicineData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('medicines').insert(medicineData);
      } else {
        await Supabase.instance.client.from('medicines').update(medicineData).eq('id', widget.medicine!['id']);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: ${e.toString()}'), backgroundColor: Colors.red),
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
        title: Text(_isEditing ? 'Modifier le médicament' : 'Ajouter un médicament'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // SECTION IMAGE
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_selectedImage != null || _uploadedImageUrl != null) ? Colors.teal : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: _isUploadingImage
                            ? const Center(child: CircularProgressIndicator())
                            : (_selectedImage != null || _uploadedImageUrl != null)
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: _selectedImage != null
                                            ? (kIsWeb
                                                ? Image.network(_selectedImage!.path, fit: BoxFit.cover, width: double.infinity, height: 200)
                                                : Image.file(File(_selectedImage!.path), fit: BoxFit.cover, width: double.infinity, height: 200))
                                            : (_uploadedImageUrl != null
                                                ? Image.network(_uploadedImageUrl!, fit: BoxFit.cover, width: double.infinity, height: 200,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return const Center(child: CircularProgressIndicator());
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey));
                                                    })
                                                : Container(color: Colors.grey[200], child: const Icon(Icons.medication, color: Colors.grey))),
                                      ),
                                      Positioned(
                                        top: 8, right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(20)),
                                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text('Ajouter une photo du médicament', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                      Text('(Optionnel mais recommandé)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.medication)), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)), maxLines: 3),
                    const SizedBox(height: 12),
                    
                    Row(children: [
                      Expanded(child: TextFormField(controller: _dosageController, decoration: const InputDecoration(labelText: 'Dosage *', prefixIcon: Icon(Icons.science)), validator: (v) => v!.isEmpty ? 'Requis' : null)),
                      const SizedBox(width: 12),
                     Expanded(
  child: DropdownButtonFormField<String>(
    value: _forms.contains(_selectedForm) ? _selectedForm : null,
    decoration: const InputDecoration(
      labelText: 'Forme',
      prefixIcon: Icon(Icons.category),
    ),
    items: _forms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
    onChanged: (v) => setState(() => _selectedForm = v!),
  ),
),
                    ]),
                    const SizedBox(height: 12),
                    
                    Row(children: [
                      Expanded(child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix FCFA', prefixIcon: Icon(Icons.attach_money)), validator: (v) => v!.isEmpty ? 'Requis' : null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(Icons.inventory)), validator: (v) => v!.isEmpty ? 'Requis' : null)),
                    ]),
                    const SizedBox(height: 16),

                    // Seuil d'alerte
                    Card(color: Colors.orange.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('Seuil alerte stock', style: TextStyle(fontWeight: FontWeight.bold))]), Slider(value: _minStockThreshold.toDouble(), min: 0, max: 100, divisions: 20, label: '$_minStockThreshold', onChanged: (v) => setState(() => _minStockThreshold = v.toInt()))]))),
                    const SizedBox(height: 12),

                    // Date expiration
                    Card(
                      color: _isExpiringSoon() ? Colors.red.shade50 : Colors.green.shade50,
                      child: ListTile(
                        leading: Icon(
                          _expiryDate == null ? Icons.calendar_today : _isExpiringSoon() ? Icons.warning : Icons.check_circle,
                          color: _expiryDate == null ? Colors.grey : _isExpiringSoon() ? Colors.red : Colors.green,
                        ),
                        title: const Text('Date expiration'),
                        subtitle: Text(_expiryDate == null ? 'Non définie' : DateFormat('dd/MM/yyyy').format(_expiryDate!)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _selectExpiryDate,
                      ),
                    ),
                    
                    // Widget conditionnel pour warning expiration
                    _expiryDate != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 56, bottom: 12),
                            child: Text(
                              _getExpirationWarning(),
                              style: TextStyle(
                                color: _isExpiringSoon() ? Colors.red.shade700 : Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),

                    SwitchListTile(title: const Text('Ordonnance requise'), value: _requiresPrescription, onChanged: (v) => setState(() => _requiresPrescription = v)),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveMedicine,
                      icon: Icon(_isEditing ? Icons.save : Icons.add),
                      label: Text(_isEditing ? 'Mettre à jour' : 'Ajouter'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}