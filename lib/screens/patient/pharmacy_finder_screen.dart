import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/pharmacy_finder_service.dart';
import '../../services/navigation_service.dart'; // ✅ AJOUTÉ
import 'dart:async';

class PharmacyFinderScreen extends StatefulWidget {
  const PharmacyFinderScreen({super.key});

  @override
  State<PharmacyFinderScreen> createState() => _PharmacyFinderScreenState();
}

class _PharmacyFinderScreenState extends State<PharmacyFinderScreen> {
  final PharmacyFinderService _service = PharmacyFinderService();
  final NavigationService _navService = NavigationService(); // ✅ AJOUTÉ
  Position? _currentPosition;
  List<Map<String, dynamic>> _pharmacies = [];
  bool _isLoading = true;
  bool _autoRefresh = true;
  bool _onlyOpen = true;
  StreamSubscription<Position>? _positionStream;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeAutoDetection();
  }
Future<void> _initializeAutoDetection() async {
  try {
    // ✅ Vérifier et demander les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Permissions de localisation refusées');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez autoriser la localisation dans les paramètres du navigateur'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('❌ Permissions définitivement refusées');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les permissions de localisation sont désactivées. Activez-les dans les paramètres.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // ✅ Obtenir la position
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    
    print('📍 Position obtenue: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    
    await _loadPharmacies();

    if (_autoRefresh) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen((Position pos) {
        print('📍 Nouvelle position: ${pos.latitude}, ${pos.longitude}');
        setState(() => _currentPosition = pos);
        _loadPharmacies();
      });
    }
  } catch (e) {
    print('❌ Erreur géolocalisation: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de localisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _loadPharmacies() async {
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);

    try {
      final pharmacies = await _service.fetchOpenPharmaciesNearby(
        _currentPosition!,
        radiusKm: _onlyOpen ? 5.0 : 10.0,
        onlyOpen: _onlyOpen,
      );

      setState(() {
        _pharmacies = pharmacies;
        _isLoading = false;
      });

      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15.0,
      );
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ NOUVELLE FONCTION : Démarrer la navigation
  Future<void> _startNavigation(Map<String, dynamic> pharmacy) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position non disponible')),
      );
      return;
    }

    final success = await _navService.navigateToPharmacy(
      pharmacyLat: pharmacy['latitude'],
      pharmacyLon: pharmacy['longitude'],
      pharmacyName: pharmacy['name'],
      currentPosition: _currentPosition,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗺️ Ouverture de l\'itinéraire...'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Impossible d\'ouvrir la navigation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPharmacyDetails(Map<String, dynamic> pharma) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nom et statut
                Row(
                  children: [
                    Icon(
                      pharma['isOpenNow'] ? Icons.check_circle : Icons.access_time,
                      color: pharma['isOpenNow'] ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pharma['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Distance et source
                Text(
                  '${(pharma['distance'] / 1000).toStringAsFixed(1)} km • ${pharma['source'] == 'external' ? 'Donnée OpenStreetMap' : 'Partenaire vérifié'}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Divider(height: 32),
                
                // Adresse
                if (pharma['address'].isNotEmpty)
                  _buildInfoRow(Icons.location_on, pharma['address']),
                
                // Téléphone
                if (pharma['phone'].isNotEmpty)
                  _buildInfoRow(Icons.phone, pharma['phone']),
                
                // Horaires
                _buildInfoRow(
                  Icons.access_time,
                  'Horaires: ${pharma['opening_hours']}',
                ),
                
                const SizedBox(height: 24),
                
                // ✅ BOUTON ITINÉRAIRE
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _startNavigation(pharma),
                    icon: const Icon(Icons.navigation, size: 24),
                    label: const Text(
                      'Itinéraire',
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
                
                const SizedBox(height: 12),
                
                // Bouton secondaire : Contacter
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Ouvrir le chat ou appeler
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Contacter la pharmacie'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Pharmacies à proximité'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: _onlyOpen ? Colors.green : Colors.grey,
                  size: 18,
                ),
                Switch(
                  value: _onlyOpen,
                  onChanged: (val) {
                    setState(() => _onlyOpen = val);
                    _loadPharmacies();
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.refresh),
            onPressed: _isLoading ? null : _loadPharmacies,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    // Position utilisateur
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
                    // Pharmacies
                    ..._pharmacies.map((p) => Marker(
                      point: LatLng(p['latitude'], p['longitude']),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showPharmacyDetails(p),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p['isOpenNow'] ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              p['isOpenNow'] ? '🟢' : '🟠',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton Urgence
          FloatingActionButton(
            heroTag: 'urgent',
            backgroundColor: Colors.red,
            child: const Icon(Icons.local_hospital),
            onPressed: () {
              setState(() => _onlyOpen = true);
              _loadPharmacies();
            },
            tooltip: 'Mode Urgence (Ouvert 24h)',
          ),
          const SizedBox(height: 12),
          // Bouton Centrer
          FloatingActionButton(
            heroTag: 'center',
            backgroundColor: Colors.teal,
            child: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                16.0,
              );
            },
          ),
        ],
      ),
    );
  }
}