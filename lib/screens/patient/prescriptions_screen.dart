import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _pharmacies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Charger les ordonnances
      final prescriptionsResponse = await Supabase.instance.client
          .from('prescriptions')
          .select('*')
          .eq('patient_id', user.id)
          .order('created_at', ascending: false);

      // Charger les pharmacies
      final pharmaciesResponse = await Supabase.instance.client
          .from('pharmacies')
          .select('*')
          .eq('is_active', true)
          .eq('is_verified', true)
          .order('name', ascending: true);

      setState(() {
        _prescriptions = List<Map<String, dynamic>>.from(prescriptionsResponse);
        _pharmacies = List<Map<String, dynamic>>.from(pharmaciesResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPrescription() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Upload en cours...'),
              ],
            ),
          ),
        );
      }

      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';
      
      await Supabase.instance.client.storage
          .from('prescriptions')
          .uploadBinary('patient_${user.id}/$fileName', bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('prescriptions')
          .getPublicUrl('patient_${user.id}/$fileName');

      await Supabase.instance.client.from('prescriptions').insert({
        'patient_id': user.id,
        'image_url': publicUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ordonnance uploadée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      print('❌ Erreur upload: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null) return;
    await _uploadImage(image);
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Upload en cours...'),
              ],
            ),
          ),
        );
      }

      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';
      
      await Supabase.instance.client.storage
          .from('prescriptions')
          .uploadBinary('patient_${user.id}/$fileName', bytes);

      final publicUrl = Supabase.instance.client.storage
          .from('prescriptions')
          .getPublicUrl('patient_${user.id}/$fileName');

      await Supabase.instance.client.from('prescriptions').insert({
        'patient_id': user.id,
        'image_url': publicUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ordonnance uploadée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      print('❌ Erreur upload: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePrescription(Map<String, dynamic> prescription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer cette ordonnance ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Supprimer l'image du storage
        final imageUrl = prescription['image_url'];
        if (imageUrl != null) {
          final urlParts = imageUrl.split('/patient_');
          if (urlParts.length > 1) {
            final filePath = 'patient_${urlParts[1]}';
            try {
              await Supabase.instance.client.storage
                  .from('prescriptions')
                  .remove([filePath]);
            } catch (e) {
              print('⚠️ Erreur suppression fichier: $e');
            }
          }
        }

        // Supprimer de la base
        await Supabase.instance.client
            .from('prescriptions')
            .delete()
            .eq('id', prescription['id']);

        _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Ordonnance supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erreur lors de la suppression'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadPrescription(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      
      if (kIsWeb) {
        // Ouvrir dans un nouvel onglet pour le web
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Pour mobile, ouvrir avec l'application appropriée
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('❌ Erreur téléchargement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors du téléchargement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _transferToPharmacy(Map<String, dynamic> prescription) async {
    if (_pharmacies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Aucune pharmacie disponible'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selectedPharmacy = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏥 Transférer à une pharmacie'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pharmacies.length,
            itemBuilder: (context, index) {
              final pharmacy = _pharmacies[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: const Icon(Icons.local_pharmacy, color: Colors.white),
                ),
                title: Text(pharmacy['name']),
                subtitle: Text(pharmacy['address'] ?? ''),
                onTap: () => Navigator.pop(ctx, pharmacy),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selectedPharmacy != null) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        // Créer une conversation avec la pharmacie
        final existingConv = await Supabase.instance.client
            .from('conversations')
            .select('id')
            .eq('patient_id', user.id)
            .eq('pharmacy_id', selectedPharmacy['id'])
            .maybeSingle();

        String conversationId;

        if (existingConv != null) {
          conversationId = existingConv['id'];
        } else {
          final newConv = await Supabase.instance.client
              .from('conversations')
              .insert({
                'patient_id': user.id,
                'pharmacy_id': selectedPharmacy['id'],
                'created_at': DateTime.now().toIso8601String(),
              })
              .select('id')
              .single();
          
          conversationId = newConv['id'];
        }

        // Envoyer l'ordonnance dans la conversation
      await Supabase.instance.client.from('messages').insert({
  'conversation_id': conversationId,
  'sender_id': user.id,
  'content': '📋 Voici mon ordonnance',
  'message_type': 'image',  // ✅ Utilisez 'image' au lieu de 'prescription'
  'attachment_url': prescription['image_url'],
  'read': false,
  'created_at': DateTime.now().toIso8601String(),
});

        // Mettre à jour le statut de l'ordonnance
        await Supabase.instance.client
            .from('prescriptions')
            .update({
              'status': 'transferred',
              'transferred_to': selectedPharmacy['id'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', prescription['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ordonnance transférée à ${selectedPharmacy['name']}'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Ouvrir la conversation
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: {
              'conversationId': conversationId,
              'pharmacyName': selectedPharmacy['name'],
              'medicineName': 'Ordonnance',
            },
          );
        }
      } catch (e) {
        print('❌ Erreur transfert: $e');
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
  }

  void _viewPrescription(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ordonnance'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadPrescription(prescription['image_url']),
                tooltip: 'Télécharger',
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  Navigator.pop(ctx);
                  _transferToPharmacy(prescription);
                },
                tooltip: 'Transférer',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deletePrescription(prescription);
                },
                tooltip: 'Supprimer',
              ),
            ],
          ),
          body: Center(
            child: Image.network(
              prescription['image_url'],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Image non disponible'),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Date: ${DateTime.parse(prescription['created_at']).toString().substring(0, 10)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatusChip(prescription['status']),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _downloadPrescription(prescription['image_url']);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Télécharger'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _transferToPharmacy(prescription);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Transférer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'En attente de validation';
        icon = Icons.pending;
        break;
      case 'validated':
        color = Colors.green;
        label = 'Validée';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejetée';
        icon = Icons.cancel;
        break;
      case 'transferred':
        color = Colors.blue;
        label = 'Transférée à la pharmacie';
        icon = Icons.send;
        break;
      default:
        color = Colors.grey;
        label = 'Inconnu';
        icon = Icons.info;
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  void _showPrescriptionOptions(Map<String, dynamic> prescription) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.teal),
              title: const Text('Voir l\'ordonnance'),
              onTap: () {
                Navigator.pop(ctx);
                _viewPrescription(prescription);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.blue),
              title: const Text('Télécharger'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadPrescription(prescription['image_url']);
              },
            ),
            if (_pharmacies.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.send, color: Colors.teal),
                title: const Text('Transférer à une pharmacie'),
                onTap: () {
                  Navigator.pop(ctx);
                  _transferToPharmacy(prescription);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.pop(ctx);
                _deletePrescription(prescription);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Mes Ordonnances'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 100, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune ordonnance',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uploadez votre ordonnance pour la partager avec les pharmaciens',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _prescriptions.length,
                  itemBuilder: (context, index) {
                    final prescription = _prescriptions[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: const Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(
                          'Ordonnance du ${DateTime.parse(prescription['created_at']).toString().substring(0, 10)}',
                        ),
                        subtitle: _buildStatusChip(prescription['status']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download, color: Colors.blue),
                              onPressed: () => _downloadPrescription(prescription['image_url']),
                              tooltip: 'Télécharger',
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showPrescriptionOptions(prescription),
                              tooltip: 'Options',
                            ),
                          ],
                        ),
                        onTap: () => _viewPrescription(prescription),
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'gallery',
            backgroundColor: Colors.teal.shade100,
            child: const Icon(Icons.photo_library, color: Colors.teal),
            onPressed: _uploadFromGallery,
            tooltip: 'Depuis la galerie',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'camera',
            backgroundColor: Colors.teal,
            child: const Icon(Icons.add_a_photo, color: Colors.white),
            onPressed: _uploadPrescription,
            tooltip: 'Prendre une photo',
          ),
        ],
      ),
    );
  }
}