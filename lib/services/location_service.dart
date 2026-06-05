import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _positionController = 
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Position? get currentPosition => _currentPosition;

  // ✅ Démarrer le suivi de position en temps réel
  Future<void> startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // mètres
  }) async {
    try {
      // Vérifier les permissions
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

      if (permission == LocationPermission.deniedForever) {
        throw 'Permission de localisation refusée de façon permanente';
      }

      // Position initiale
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      );

      // Stream en temps réel
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      ).listen((Position position) {
        _currentPosition = position;
        _positionController.add(position);
        print('📍 Position mise à jour: ${position.latitude}, ${position.longitude}');
      });

      print('✅ Suivi de position démarré');
    } catch (e) {
      print('❌ Erreur démarrage suivi: $e');
      rethrow;
    }
  }

  // ✅ Obtenir la position actuelle (one-shot)
  Future<Position> getCurrentPosition() async {
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

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('❌ Erreur obtention position: $e');
      rethrow;
    }
  }

  // ✅ Arrêter le suivi
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionController.close();
    print('⏹️ Suivi de position arrêté');
  }

  // ✅ Calculer la distance entre deux points (Haversine)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }

  // ✅ Obtenir l'adresse à partir des coordonnées (Reverse Geocoding)
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Note: Sur web, utilisez un service comme Nominatim ou Google Geocoding API
      // Pour mobile, Geolocator peut le faire
      return 'Position: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      return 'Adresse non disponible';
    }
  }

  void dispose() {
    stopLocationTracking();
  }
}