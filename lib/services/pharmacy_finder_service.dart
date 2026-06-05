import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
// ❌ SUPPRIMER : import 'package:opening_hours/opening_hours.dart';
// ✅ AJOUTER :
import '../utils/opening_hours_parser.dart';

class PharmacyFinderService {
  static final PharmacyFinderService _instance = PharmacyFinderService._internal();
  factory PharmacyFinderService() => _instance;
  PharmacyFinderService._internal();

  // ✅ VÉRIFIER SI OUVERT MAINTENANT (Format OSM)
  bool isCurrentlyOpen(String? openingHours) {
    if (openingHours == null || openingHours.isEmpty) return true; // Par défaut ouvert si non spécifié
    return OpeningHoursParser.isOpenNow(openingHours);
  }

  // ✅ RÉCUPÉRER LES PHARMACIES OUVERTES AUTOUR DE VOUS
Future<List<Map<String, dynamic>>> fetchOpenPharmaciesNearby(
  Position position, {
  double radiusKm = 5.0,
  bool onlyOpen = true,
}) async {
  try {
    print('🔍 Recherche pharmacies autour de: ${position.latitude}, ${position.longitude}');
    
    // ✅ Utiliser Overpass Turbo (autorise CORS)
    final url = Uri.parse('https://overpass-turbo.eu/api/interpreter');
    // paul
    final query = '''
      [out:json][timeout:25];
      node["amenity"="pharmacy"](around:${radiusKm * 1000},${position.latitude},${position.longitude});
      out body;
    ''';

    print('📤 Requête Overpass...');

    final response = await http.post(
      url,
      body: query,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
    );
    
    print('📥 Statut: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('❌ Erreur HTTP ${response.statusCode}');
      print('❌ Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      return [];
    }

    // Vérifier si la réponse est du JSON valide
    if (!response.body.trim().startsWith('{')) {
      print('❌ La réponse n\'est pas du JSON valide');
      print('❌ Début de la réponse: ${response.body.substring(0, 100)}');
      return [];
    }

    final data = jsonDecode(response.body);
    final elements = data['elements'] as List;
    
    print('✅ ${elements.length} pharmacies trouvées');

    final List<Map<String, dynamic>> openPharmacies = [];

    for (final e in elements) {
      final lat = e['lat'] as double;
      final lon = e['lon'] as double;
      final dist = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lon);
      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      final oh = tags['opening_hours'] as String?;

      final isOpen = onlyOpen ? isCurrentlyOpen(oh) : true;
      if (onlyOpen && !isOpen) continue;

      openPharmacies.add({
        'id': 'osm_${e['id']}',
        'name': tags['name'] ?? 'Pharmacie',
        'address': tags['addr:street'] ?? '',
        'city': tags['addr:city'] ?? '',
        'phone': tags['phone'] ?? '',
        'latitude': lat,
        'longitude': lon,
        'opening_hours': oh ?? 'Non renseigné',
        'distance': dist,
        'source': 'external',
        'isOpenNow': isOpen,
        'markerColor': '#00C853',
      });
    }

    openPharmacies.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    print('✅ ${openPharmacies.length} pharmacies ouvertes');
    return openPharmacies.take(50).toList();
    
  } catch (e, stackTrace) {
    print('❌ Erreur fetchOpenPharmaciesNearby: $e');
    print('❌ Stack: $stackTrace');
    return [];
  }
}
}