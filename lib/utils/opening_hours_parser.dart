class OpeningHoursParser {
  /// Vérifie si une pharmacie est ouverte maintenant
  /// Format OSM: "Mo-Fr 08:00-18:00; Sa 09:00-13:00"
  static bool isOpenNow(String? openingHours) {
    if (openingHours == null || openingHours.isEmpty) return true;
    
    try {
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Lundi, 7=Dimanche
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final rules = openingHours.split(';');
      for (final rule in rules) {
        final parts = rule.trim().split(' ');
        if (parts.length >= 2) {
          final days = parts[0];
          final hours = parts[1];
          
          if (_matchesDay(days, weekday) && _matchesTime(hours, currentTime)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return true; // Fallback sécuritaire
    }
  }
  
  static bool _matchesDay(String daysRule, int weekday) {
    if (daysRule.contains('24/7') || daysRule.contains('00:00-24:00')) return true;
    if (daysRule.contains('Mo-Fr') && weekday >= 1 && weekday <= 5) return true;
    if (daysRule.contains('Mo-Sa') && weekday >= 1 && weekday <= 6) return true;
    if (daysRule.contains('Sa') && weekday == 6) return true;
    if (daysRule.contains('Su') && weekday == 7) return true;
    if (daysRule.contains('Mo') && weekday == 1) return true;
    return false;
  }
  
  static bool _matchesTime(String timeRule, String currentTime) {
    if (timeRule.contains('-')) {
      final times = timeRule.split('-');
      if (times.length == 2) {
        return currentTime.compareTo(times[0]) >= 0 && 
               currentTime.compareTo(times[1]) <= 0;
      }
    }
    return false;
  }
}