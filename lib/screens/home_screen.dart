import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math'; // ✅ Import pour les fonctions mathématiques

// ✅ Import corrigé : fichier dans le même dossier screens/
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineController = TextEditingController();
  final _cityController = TextEditingController();
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  double _searchRadius = 10.0; // km par défaut
  List<Map<String, dynamic>> _nearbyPharmacies = [];
  
  // Carte controller
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation();
  }

  // 🔍 DÉTECTION POSITION ACTUELLE (GPS)
  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Demander permission
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

      // Récupérer position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Sauvegarder dans Supabase
      await _saveUserLocation(position);

      // Charger pharmacies proches
      await _loadNearbyPharmacies();

    } catch (e) {
      setState(() {
        _locationError = 'Erreur: $e';
        _isLoadingLocation = false;
      });
    }
  }

  // 💾 Sauvegarder position utilisateur
  Future<void> _saveUserLocation(Position position) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // ✅ Utiliser upsert avec onConflict pour éviter les erreurs
      await Supabase.instance.client
          .from('users')
          .upsert({
            'id': user.id,
            'last_latitude': position.latitude,
            'last_longitude': position.longitude,
            'updated_at': DateTime.now().toIso8601String(),
            // ✅ Ne pas toucher à 'role' ici, laisser la valeur existante
          }, onConflict: 'id');
    }
  } catch (e) {
    print('⚠️ Erreur sauvegarde position: $e');
  }
}
  

  // 🏥 Charger pharmacies dans un rayon
  Future<void> _loadNearbyPharmacies() async {
    if (_currentPosition == null) return;

    try {
      // Calculer bounding box pour recherche rapide
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      final radiusInDegrees = _searchRadius / 111.0; // ~111km par degré

      final response = await Supabase.instance.client
          .from('pharmacies')
          .select('*')
          .gte('latitude', lat - radiusInDegrees)
          .lte('latitude', lat + radiusInDegrees)
          .gte('longitude', lng - radiusInDegrees)
          .lte('longitude', lng + radiusInDegrees);

      // Filtrer par distance exacte (formule Haversine côté client)
      final pharmacies = response.where((pharmacy) {
        final pharmacyLat = (pharmacy['latitude'] as num).toDouble();
        final pharmacyLng = (pharmacy['longitude'] as num).toDouble();
        
        final distance = _calculateDistance(
          lat, lng,
          pharmacyLat, pharmacyLng,
        );

        return distance <= _searchRadius;
      }).toList();

      // Trier par distance
      pharmacies.sort((a, b) {
        final distA = _calculateDistance(
          lat, lng,
          (a['latitude'] as num).toDouble(),
          (a['longitude'] as num).toDouble(),
        );
        final distB = _calculateDistance(
          lat, lng,
          (b['latitude'] as num).toDouble(),
          (b['longitude'] as num).toDouble(),
        );
        return distA.compareTo(distB);
      });

      setState(() {
        _nearbyPharmacies = pharmacies;
      });

    } catch (e) {
      print('❌ Erreur chargement pharmacies: $e');
    }
  }

  // 📏 Calcul distance entre 2 points (Haversine) - ✅ CORRIGÉ
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    // ✅ Correction: utilisation des fonctions de dart:math
    final a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180.0);

  // 🔎 Lancer recherche médicament
  void _searchMedicine() {
    if (_formKey.currentState!.validate() && _currentPosition != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(
            medicineName: _medicineController.text,
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radius: _searchRadius,
            nearbyPharmacies: _nearbyPharmacies,
          ),
        ),
      );
    } else if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez activer votre localisation'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_pharmacy, color: Colors.white),
            SizedBox(width: 8),
            Text('Pharmalink Africa'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _detectCurrentLocation,
            tooltip: 'Actualiser position',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout logic
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📍 Section Localisation
            _buildLocationSection(),
            
            const SizedBox(height: 24),
            
            // 🔍 Formulaire de recherche
            _buildSearchForm(),
            
            const SizedBox(height: 32),
            
            // 🗺️ Carte des pharmacies proches
            _buildMapSection(),
          ],
        ),
      ),
    );
  }

  // 📍 Widget Section Localisation
  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.teal.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.teal),
              const SizedBox(width: 8),
              const Text(
                'Ma localisation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const Spacer(),
              if (_isLoadingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_currentPosition != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Position détectée',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('📍 Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                  Text('📍 Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                  Text('🎯 Précision: ${_currentPosition!.accuracy.toStringAsFixed(0)}m'),
                ],
              ),
            ),
          ] else if (_locationError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
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
            const Text(
              'Localisation en cours...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Rayon de recherche
          const Text(
            'Rayon de recherche',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _searchRadius,
            min: 5,
            max: 50,
            divisions: 4,
            label: '${_searchRadius.toInt()} km',
            onChanged: (value) {
              setState(() => _searchRadius = value);
              _loadNearbyPharmacies();
            },
          ),
          Text(
            '${_searchRadius.toInt()} km autour de vous',
            style: TextStyle(color: Colors.teal.shade700),
          ),
        ],
      ),
    );
  }

  // 🔍 Widget Formulaire de Recherche
  Widget _buildSearchForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _medicineController,
              decoration: InputDecoration(
                labelText: 'Nom du médicament *',
                hintText: 'Ex: Paracétamol, Amoxicilline...',
                prefixIcon: const Icon(Icons.medication),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un médicament';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _searchMedicine,
                icon: const Icon(Icons.search),
                label: const Text(
                  'Rechercher',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🗺️ Widget Carte - ✅ CORRIGÉ
  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pharmacies à proximité',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 400,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
  initialCenter: _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : const LatLng(3.8480, 11.5021),
  initialZoom: _currentPosition != null ? 13.0 : 10.0,
),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                // Marqueur position utilisateur
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                      // Marqueurs pharmacies
                      ..._nearbyPharmacies.map((pharmacy) {
                        final lat = (pharmacy['latitude'] as num).toDouble();
                        final lng = (pharmacy['longitude'] as num).toDouble();
                        
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.local_pharmacy,
                            color: Colors.red,
                            size: 35,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_nearbyPharmacies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_nearbyPharmacies.length} pharmacie(s) trouvée(s)',
              style: TextStyle(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}