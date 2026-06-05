import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  final _client = Supabase.instance.client;

  /// Obtenir les statistiques globales pour une période
  Future<Map<String, dynamic>> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now();

    // ✅ Utiliser RPC pour les statistiques complexes
    final response = await _client.rpc(
      'get_pharmacy_analytics',
      params: {
        'pharmacy_owner_id': userId,
        'start_date': start.toIso8601String().split('T')[0],
        'end_date': end.toIso8601String().split('T')[0],
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Réservations par jour (pour graphique)
  Future<List<Map<String, dynamic>>> getDailyReservations({
    int days = 7,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final pharmacyId = await _getPharmacyId();
    if (pharmacyId == null) throw Exception('Pharmacie non trouvée');

    final startDate = DateTime.now().subtract(Duration(days: days));

    // ✅ Utiliser .select() avec DATE_TRUNC pour grouper par jour
    final response = await _client
        .from('reservations')
        .select('''
          created_at,
          quantity,
          pharmacy_id
        ''')
        .eq('pharmacy_id', pharmacyId)
        .gte('created_at', startDate.toIso8601String())
        .neq('status', 'cancelled');

    // ✅ Grouper les données côté Dart
    final Map<String, Map<String, dynamic>> dataMap = {};
    
    for (var item in response) {
      final date = DateTime.parse(item['created_at']);
      final dateStr = date.toIso8601String().split('T')[0];
      
      if (!dataMap.containsKey(dateStr)) {
        dataMap[dateStr] = {
          'date': dateStr,
          'day': _getDayName(date),
          'count': 0,
          'total_quantity': 0,
        };
      }
      
      dataMap[dateStr]!['count'] = (dataMap[dateStr]!['count'] as int) + 1;
      dataMap[dateStr]!['total_quantity'] = 
          (dataMap[dateStr]!['total_quantity'] as int) + (item['quantity'] as int);
    }

    // ✅ Compléter les jours manquants
    final List<Map<String, dynamic>> completeData = [];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      
      completeData.add(dataMap[dateStr] ?? {
        'date': dateStr,
        'day': _getDayName(date),
        'count': 0,
        'total_quantity': 0,
      });
    }

    return completeData;
  }

  /// Top médicaments
  Future<List<Map<String, dynamic>>> getTopMedicines({int limit = 5}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final pharmacyId = await _getPharmacyId();
    if (pharmacyId == null) throw Exception('Pharmacie non trouvée');

    // ✅ Utiliser .select() avec JOIN et faire l'agrégation côté Dart
    final response = await _client
        .from('reservations')
        .select('''
          medicine_id,
          quantity,
          medicines (
            id,
            name,
            dosage
          )
        ''')
        .eq('pharmacy_id', pharmacyId)
        .neq('status', 'cancelled');

    // ✅ Agréger les données par médicament
    final Map<String, Map<String, dynamic>> medicineMap = {};
    
    for (var item in response) {
      final medId = item['medicine_id'] as String;
      final med = item['medicines'] as Map<String, dynamic>;
      
      if (!medicineMap.containsKey(medId)) {
        medicineMap[medId] = {
          'medicine_id': medId,
          'name': med['name'],
          'dosage': med['dosage'] ?? '',
          'total_reservations': 0,
          'total_quantity': 0,
        };
      }
      
      medicineMap[medId]!['total_reservations'] = 
          (medicineMap[medId]!['total_reservations'] as int) + 1;
      medicineMap[medId]!['total_quantity'] = 
          (medicineMap[medId]!['total_quantity'] as int) + (item['quantity'] as int);
    }

    // ✅ Convertir en liste et trier
    final List<Map<String, dynamic>> result = medicineMap.values.toList()
      ..sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));

    return result.take(limit).toList();
  }

  /// Statistiques par statut
  Future<Map<String, int>> getReservationByStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final pharmacyId = await _getPharmacyId();
    if (pharmacyId == null) throw Exception('Pharmacie non trouvée');

    final response = await _client
        .from('reservations')
        .select('status')
        .eq('pharmacy_id', pharmacyId);

    final Map<String, int> stats = {
      'pending': 0,
      'confirmed': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (var item in response) {
      final status = item['status'] as String;
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }

  /// Activité récente
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final pharmacyId = await _getPharmacyId();
    if (pharmacyId == null) throw Exception('Pharmacie non trouvée');

    final response = await _client
        .from('reservations')
        .select('''
          id,
          quantity,
          status,
          created_at,
          users!inner(
            full_name,
            phone
          ),
          medicines!inner(
            name,
            dosage
          )
        ''')
        .eq('pharmacy_id', pharmacyId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Revenu par mois (6 derniers mois)
  Future<List<Map<String, dynamic>>> getMonthlyRevenue({int months = 6}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    final pharmacyId = await _getPharmacyId();
    if (pharmacyId == null) throw Exception('Pharmacie non trouvée');

    final startDate = DateTime.now().subtract(Duration(days: months * 30));

    final response = await _client
        .from('reservations')
        .select('''
          created_at,
          quantity
        ''')
        .eq('pharmacy_id', pharmacyId)
        .gte('created_at', startDate.toIso8601String())
        .neq('status', 'cancelled');

    // ✅ Récupérer les prix depuis stocks
    final stocksResponse = await _client
        .from('stocks')
        .select('medicine_id, price')
        .eq('pharmacy_id', pharmacyId);

    final Map<String, double> medicinePrices = {};
    for (var stock in stocksResponse) {
      medicinePrices[stock['medicine_id'] as String] = (stock['price'] as num).toDouble();
    }

    // ✅ Grouper par mois
    final Map<String, Map<String, dynamic>> monthlyData = {};
    
    for (var item in response) {
      final date = DateTime.parse(item['created_at']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'month': monthKey,
          'total_reservations': 0,
          'total_revenue': 0.0,
        };
      }
      
      monthlyData[monthKey]!['total_reservations'] = 
          (monthlyData[monthKey]!['total_reservations'] as int) + 1;
      
      final medicineId = item['medicine_id'] as String?;
      final price = medicineId != null ? (medicinePrices[medicineId] ?? 0.0) : 0.0;
      final quantity = item['quantity'] as int;
      
      monthlyData[monthKey]!['total_revenue'] = 
          (monthlyData[monthKey]!['total_revenue'] as double) + (price * quantity);
    }

    return monthlyData.values.toList()
      ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  
  Future<String?> _getPharmacyId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('pharmacies')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();

    return response?['id'] as String?;
  }

  String _getDayName(DateTime date) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[date.weekday - 1];
  }

  /// Stream pour mises à jour temps réel
  Stream<List<Map<String, dynamic>>> streamRecentActivity() {
    return _client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('pharmacy_id', _getPharmacyId().toString())
        .order('created_at', ascending: false)
        .limit(10)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}