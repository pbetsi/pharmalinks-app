import 'dart:math';

/// Calcule la distance en kilomètres entre deux points GPS
double calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
  const p = 0.017453292519943295; // PI / 180
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  
  // 12742 est le diamètre de la Terre en km (2 * 6371)
  return 12742 * asin(sqrt(a));
}