import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RegisterPharmacyScreen extends StatefulWidget {
  const RegisterPharmacyScreen({super.key});

  @override
  State<RegisterPharmacyScreen> createState() => _RegisterPharmacyScreenState();
}

class _RegisterPharmacyScreenState extends State<RegisterPharmacyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  // Variables
  String _selectedCountry = 'CM'; // Code ISO par défaut (Cameroun)
  bool _isLoading = false;
  bool _obscurePassword = true;
  Position? _currentPosition;
  String? _locationError;
  
  // ✅ NOUVEAU : Gestion des horaires
  Map<String, Map<String, dynamic>> _workingHours = {};
  
  // Carte
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  // Liste des pays africains (codes ISO)
  final Map<String, String> _countries = {
    'CM': '🇨🇲 Cameroun',
    'SN': '🇸🇳 Sénégal',
    'CI': '🇨🇮 Côte d\'Ivoire',
    'ML': '🇲🇱 Mali',
    'BF': '🇧🇫 Burkina Faso',
    'NE': '🇳 Niger',
    'TG': '🇹 Togo',
    'BJ': '🇧 Bénin',
    'GN': '🇬🇳 Guinée',
    'CD': '🇨🇩 RDC',
    'GA': '🇬🇦 Gabon',
    'CG': '🇨🇬 Congo',
    'TD': '🇹 Tchad',
    'MR': '🇲🇷 Mauritanie',
    'GH': '🇬🇭 Ghana',
    'NG': '🇳🇬 Nigeria',
    'KE': '🇰🇪 Kenya',
    'TZ': '🇹🇿 Tanzanie',
    'UG': '🇺🇬 Ouganda',
    'RW': '🇷 Rwanda',
    'ET': '🇪🇹 Éthiopie',
    'ZA': '🇿 Afrique du Sud',
    'MG': '🇲🇬 Madagascar',
    'MU': '🇲🇺 Maurice',
    'RE': '🇷 Réunion',
  };

  @override
  void initState() {
    super.initState();
    _initializeWorkingHours();
    _detectCurrentLocation();
  }

  // ✅ INITIALISER LES HORAIRES PAR DÉFAUT
  void _initializeWorkingHours() {
    for (int i = 0; i < 7; i++) {
      _workingHours['day_$i'] = {
        'isOpen': false,
        'openingTime': const TimeOfDay(hour: 8, minute: 0),
        'closingTime': const TimeOfDay(hour: 18, minute: 0),
      };
    }
    
    // Par défaut, ouvrir du Lundi au Vendredi 8h-18h
    for (int i = 1; i <= 5; i++) {
      _workingHours['day_$i'] = {
        'isOpen': true,
        'openingTime': const TimeOfDay(hour: 8, minute: 0),
        'closingTime': const TimeOfDay(hour: 18, minute: 0),
      };
    }
  }

  // 📍 DÉTECTION GPS AUTOMATIQUE
  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Service de localisation désactivé';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permission de localisation refusée';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _isLoading = false;
      });

      _mapController.move(_selectedLocation!, 15.0);

    } catch (e) {
      setState(() {
        _locationError = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  // 🎯 Positionnement manuel sur la carte
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
    });
  }

  // ✅ SAUVEGARDER LES HORAIRES
  Future<void> _saveWorkingHours(String pharmacyId) async {
    try {
      print('💾 Sauvegarde des horaires pour pharmacy_id: $pharmacyId');
      
      // Supprimer les anciens horaires
      await Supabase.instance.client
          .from('pharmacy_working_hours')
          .delete()
          .eq('pharmacy_id', pharmacyId);
      
      // Insérer les nouveaux horaires
      final workingHoursData = <Map<String, dynamic>>[];
      
      for (int i = 0; i < 7; i++) {
        final dayKey = 'day_$i';
        final dayData = _workingHours[dayKey];
        
        if (dayData != null && dayData['isOpen'] == true) {
          workingHoursData.add({
            'pharmacy_id': pharmacyId,
            'day_of_week': i,
            'opening_time': '${dayData['openingTime'].hour.toString().padLeft(2, '0')}:${dayData['openingTime'].minute.toString().padLeft(2, '0')}:00',
            'closing_time': '${dayData['closingTime'].hour.toString().padLeft(2, '0')}:${dayData['closingTime'].minute.toString().padLeft(2, '0')}:00',
            'is_open': true,
          });
        }
      }
      
      if (workingHoursData.isNotEmpty) {
        await Supabase.instance.client
            .from('pharmacy_working_hours')
            .insert(workingHoursData);
        
        print('✅ Horaires sauvegardés: ${workingHoursData.length} jours');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde horaires: $e');
    }
  }

  // ✅ FONCTION D'INSCRIPTION MODIFIÉE
  Future<void> _registerPharmacy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez sélectionner une position sur la carte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Créer le compte utilisateur (auth)
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = authResponse.user;
      if (user == null) throw 'Erreur création compte';

      // 2. Créer le profil pharmacie
      await Supabase.instance.client.from('pharmacies').insert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _selectedCountry,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'is_verified': false,
        'is_active': true,
      });

      // 3. Créer l'entrée dans users
      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'email': _emailController.text.trim(),
        'full_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'pharmacist',
        'country': _selectedCountry,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      // ✅ 4. SAUVEGARDER LES HORAIRES
      await _saveWorkingHours(user.id);

      // 5. Message de succès
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Inscription réussie !'),
            content: const Text(
              'Votre pharmacie a été enregistrée avec succès.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      print('❌ Erreur inscription: $e');
      
      if (mounted) {
        String errorMessage = 'Erreur lors de l\'inscription';
        
        if (e.toString().contains('already registered')) {
          errorMessage = '❌ Cet email est déjà inscrit. Utilisez un autre email.';
        } else if (e.toString().contains('rate limit') || 
                   e.toString().contains('429')) {
          errorMessage = '⚠️ Trop de tentatives. Attendez quelques secondes.';
        } else if (e.toString().contains('Weak password')) {
          errorMessage = '❌ Mot de passe trop faible. Utilisez au moins 6 caractères.';
        } else if (e.toString().contains('Invalid email')) {
          errorMessage = '❌ Adresse email invalide.';
        } else if (e.toString().contains('row-level security')) {
          errorMessage = '❌ Problème de configuration. Contactez le support.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ NOUVEAU WIDGET : Sélection des jours et horaires
// ✅ NOUVEAU WIDGET : Sélection des jours et horaires (INTERACTIF)
Widget _buildWorkingHoursSection() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.teal.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, color: Colors.teal),
            const SizedBox(width: 8),
            const Text(
              'Jours et Horaires d\'Ouverture',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Cochez les jours et cliquez sur les heures pour modifier',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        // Liste des jours
        ...List.generate(7, (index) {
          final dayName = _getDayName(index);
          final dayKey = 'day_$index';
          final dayData = _workingHours[dayKey] ?? {
            'isOpen': false,
            'openingTime': const TimeOfDay(hour: 8, minute: 0),
            'closingTime': const TimeOfDay(hour: 18, minute: 0),
          };
          final isOpen = dayData['isOpen'] ?? false;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isOpen ? Colors.teal.shade50 : Colors.grey.shade50,
            child: ListTile(
              leading: Checkbox(
                value: isOpen,
                activeColor: Colors.teal,
                onChanged: (value) {
                  setState(() {
                    _workingHours[dayKey] = {
                      ...dayData,
                      'isOpen': value ?? false,
                    };
                  });
                },
              ),
              title: Row(
                children: [
                  Icon(
                    isOpen ? Icons.store : Icons.store_outlined,
                    size: 18,
                    color: isOpen ? Colors.teal : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
              subtitle: InkWell( // ✅ REND LES HEURES CLIQUABLES
                onTap: isOpen ? () => _showTimePicker(index, dayKey, true) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (isOpen) ...[
                        const Icon(Icons.access_time, size: 16, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(dayData['openingTime'])} - ${_formatTime(dayData['closingTime'])}',
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.edit, size: 14, color: Colors.teal), // Icône de crayon
                      ] else
                        const Text('Fermé', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.teal),
                iconSize: 20,
                onPressed: isOpen ? () => _showTimePicker(index, dayKey, true) : null,
              ),
            ),
          );
        }),
      ],
    ),
  );
}

// ✅ FONCTION POUR OUVRIR LE SÉLECTEUR D'HEURE
Future<void> _showTimePicker(int index, String dayKey, bool isOpening) async {
  final currentData = _workingHours[dayKey] ?? {};
  
  // Détermine l'heure initiale (ouverture ou fermeture)
  final initialTime = currentData[isOpening ? 'openingTime' : 'closingTime'] ??
      const TimeOfDay(hour: 8, minute: 0);

  final picked = await showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: 'Choisissez l\'heure d\'${isOpening ? 'ouverture' : 'fermeture'}',
  );

  if (picked != null && mounted) {
    setState(() {
      // Met à jour l'heure spécifique tout en gardant l'état 'isOpen'
      if (!_workingHours.containsKey(dayKey)) {
        _workingHours[dayKey] = {'isOpen': true};
      }
      _workingHours[dayKey]![isOpening ? 'openingTime' : 'closingTime'] = picked;
    });
  }
}

String _formatTime(TimeOfDay? time) {
  if (time == null) return '--:--';
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _getDayName(int dayIndex) {
  const days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  return days[dayIndex];
}

 

  Future<void> _selectTime(BuildContext context, int dayIndex, bool isOpening) async {
    final dayKey = 'day_$dayIndex';
    final currentTime = _workingHours[dayKey]?[isOpening ? 'openingTime' : 'closingTime'] 
        ?? const TimeOfDay(hour: 8, minute: 0);
    
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    
    if (picked != null && mounted) {
      setState(() {
        _workingHours[dayKey] = {
          ..._workingHours[dayKey]!,
          if (isOpening) 'openingTime': picked else 'closingTime': picked,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 Inscription Pharmacie'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 📍 Section Localisation
                _buildLocationSection(),
                const SizedBox(height: 24),
                
                // 🏥 Informations Pharmacie
                const Text(
                  'Informations de la pharmacie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nom de la pharmacie *',
                    hintText: 'Ex: Pharmacie Centrale',
                    prefixIcon: const Icon(Icons.local_pharmacy),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _ownerNameController,
                  decoration: InputDecoration(
                    labelText: 'Nom du propriétaire *',
                    hintText: 'Nom complet',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                // 📧 Email & Téléphone
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    hintText: 'pharmacie@example.com',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone *',
                    hintText: '+237 6XX XXX XXX',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                // 🔐 Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe *',
                    hintText: 'Minimum 6 caractères',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.length < 6 ? '6 caractères min' : null,
                ),
                const SizedBox(height: 24),
                
                // 🌍 Pays & Ville
                const Text(
                  'Localisation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: InputDecoration(
                    labelText: 'Pays *',
                    prefixIcon: const Icon(Icons.flag),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _countries.entries.map((entry) {
                    return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCountry = val!),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'Ville *',
                    hintText: 'Ex: Yaoundé, Dakar...',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Adresse complète',
                    hintText: 'Quartier, rue, repères...',
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Coordonnées GPS (lecture seule)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: const Icon(Icons.location_searching),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // ✅ NOUVELLE SECTION : Jours et Horaires
                _buildWorkingHoursSection(),
                const SizedBox(height: 24),
                
                // ✅ Bouton Inscription
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerPharmacy,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 24),
                    label: Text(
                      _isLoading ? 'Inscription en cours...' : 'S\'inscrire',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ℹ️ Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre pharmacie sera activée après validation.',
                          style: TextStyle(fontSize: 13, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📍 Widget Section Localisation avec Carte
  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.teal),
              const SizedBox(width: 8),
              const Text(
                'Position de la pharmacie',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (_isLoading && _currentPosition == null)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_locationError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_locationError!)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _detectCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ] else ...[
            if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Position détectée', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            
            // 🗺️ Carte interactive
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? const LatLng(3.8480, 11.5021),
                    initialZoom: _selectedLocation != null ? 15.0 : 10.0,
                    onTap: (tapPosition, point) {
                      _onMapTap(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.local_pharmacy,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Cliquez sur la carte pour positionner précisément votre pharmacie',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}