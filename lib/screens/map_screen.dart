import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SupabaseService _service = SupabaseService();
  List<Map<String, dynamic>> _pharmacies = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies() async {
    try {
      // Récupère les pharmacies depuis le service
      final data = await _service.getPharmacies();
      setState(() {
        _pharmacies = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur chargement pharmacies: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Centre initial : Douala (par exemple)
    const centerPoint = LatLng(4.05, 9.7); 

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 13.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all, // Zoom, Pan, Tilt
                ),
              ),
              children: [
                // 1. Tuiles de la carte (OpenStreetMap)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pharmalink.africa',
                ),
                // 2. Marqueurs
                MarkerLayer(
                  markers: _pharmacies.map((pharma) {
                    final lat = pharma['lat'] as double;
                    final lng = pharma['lng'] as double;
                    
                    return Marker(
                      point: LatLng(lat, lng),
                      child: GestureDetector(
                        onTap: () => _showPharmacyDetails(context, pharma),
                        child: Icon(
                          Icons.local_pharmacy,
                          color: Colors.teal.shade700,
                          size: 40,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          // Recentrer sur Douala
          _mapController.move(centerPoint, 13.0);
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  void _showPharmacyDetails(BuildContext context, Map<String, dynamic> pharma) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pharma['name'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("📍 ${pharma['address']}"),
            const SizedBox(height: 5),
            Text("📞 ${pharma['phone']}"),
            const SizedBox(height: 15),
            if (pharma['opening_hours'] != null)
              Text("🕒 ${pharma['opening_hours']}"),
          ],
        ),
      ),
    );
  }
}