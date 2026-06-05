import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPositionScreen extends StatefulWidget {
  final Position position;

  const MapPositionScreen({
    super.key,
    required this.position,
  });

  @override
  State<MapPositionScreen> createState() => _MapPositionScreenState();
}

class _MapPositionScreenState extends State<MapPositionScreen> {
  late MapController _mapController;
  late LatLng _currentLatLng;

  @override
  void initState() {
    super.initState();
    _currentLatLng = LatLng(widget.position.latitude, widget.position.longitude);
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Position'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(
                _currentLatLng,
                16.0,
              );
            },
            tooltip: 'Recentrer',
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLatLng,
          initialZoom: 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLatLng,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 60,
                ),
              ),
            ],
          ),
        ],
      ),
 floatingActionButton: FloatingActionButton(
  onPressed: () {
    // Zoomer en avant
    _mapController.move(
      _currentLatLng,
      17, // Zoom fixe (augmentez le chiffre pour zoomer plus)
    );
  },
  child: const Icon(Icons.add),
),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}