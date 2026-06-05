import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  /// Ouvre l'itinéraire vers la pharmacie
  /// Utilise Google Maps sur Android/Web, Apple Maps sur iOS
  Future<bool> navigateToPharmacy({
    required double pharmacyLat,
    required double pharmacyLon,
    required String pharmacyName,
    Position? currentPosition,
  }) async {
    try {
      // Position actuelle si non fournie
      if (currentPosition == null) {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      final startLat = currentPosition.latitude;
      final startLon = currentPosition.longitude;

      // URL Google Maps avec itinéraire
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$startLat,$startLon'
        '&destination=$pharmacyLat,$pharmacyLon'
        '&destination_place_id=$pharmacyName'
        '&travelmode=driving',
      );

      // Alternative pour iOS (Apple Maps)
      // final url = Uri.parse(
      //   'http://maps.apple.com/?saddr=$startLat,$startLon'
      //   '&daddr=$pharmacyLat,$pharmacyLon',
      // );

      if (await canLaunchUrl(url)) {
        return await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Ouvre l'app native
        );
      } else {
        throw 'Impossible d\'ouvrir l\'application de navigation';
      }
    } catch (e) {
      print('❌ Erreur navigation: $e');
      return false;
    }
  }

  /// Ouvre directement Google Maps Web
  Future<bool> openGoogleMapsWeb({
    required double lat,
    required double lon,
    String? name,
  }) async {
    try {
      final url = Uri.parse(
        'https://www.google.com/maps/place/?q=place_id:$lat,$lon',
      );

      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('❌ Erreur Google Maps: $e');
      return false;
    }
  }
}