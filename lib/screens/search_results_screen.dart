import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SearchResultsScreen extends StatelessWidget {
  final String medicineName;
  final double latitude;
  final double longitude;
  final double radius;
  final List<Map<String, dynamic>> nearbyPharmacies;

  const SearchResultsScreen({
    super.key,
    required this.medicineName,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.nearbyPharmacies,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Résultats : $medicineName'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Carte
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(latitude, longitude),
                initialZoom: 13.0,
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
                      point: LatLng(latitude, longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    // Pharmacies
                    ...nearbyPharmacies.map((pharmacy) {
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
          
          // Liste des pharmacies
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${nearbyPharmacies.length} pharmacie(s) trouvée(s)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: nearbyPharmacies.length,
                    itemBuilder: (context, index) {
                      final pharmacy = nearbyPharmacies[index];
                      return ListTile(
                        leading: const Icon(Icons.local_pharmacy, color: Colors.teal),
                        title: Text(pharmacy['name'] ?? 'Pharmacie'),
                        subtitle: Text(pharmacy['address'] ?? ''),
                        trailing: Text(
                          '${(pharmacy['distance'] ?? 0).toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}