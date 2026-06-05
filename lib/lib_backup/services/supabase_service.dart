import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/availability.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 🔍 Recherche de médicaments avec filtres de localisation
  Future<List<MedicineAvailability>> searchMedicinesByLocation({
    required String medicineName,
    String? city,
    String? neighborhood,
  }) async {
    if (medicineName.trim().isEmpty) return [];

    try {
      // Construire la requête de base
      var query = _client
          .from('stocks')
          .select('''
            medicine_id, 
            quantity, 
            price, 
            expiry_date,
            medicines(id, name, dci, dosage, form),
            pharmacies(id, name, address, city, lat, lng, phone, is_verified)
          ''')
          .gte('quantity', 1);

      // Filtre par ville si spécifié
      if (city != null && city.trim().isNotEmpty) {
        query = query.eq('pharmacies.city', city.trim());
      }

      // Filtre par quartier (recherche dans l'adresse)
      if (neighborhood != null && neighborhood.trim().isNotEmpty) {
        query = query.ilike('pharmacies.address', '%$neighborhood%');
      }

      // Exécuter la requête
      final response = await query;

      // Filtrer manuellement les médicaments
      final results = (response as List).where((item) {
        final medicine = item['medicines'] as Map<String, dynamic>?;
        if (medicine == null) return false;
        
        final name = (medicine['name'] ?? '').toString().toLowerCase();
        final dci = (medicine['dci'] ?? '').toString().toLowerCase();
        final searchQuery = medicineName.toLowerCase();
        
        return name.contains(searchQuery) || dci.contains(searchQuery);
      }).toList();

      // Trier par prix et limiter à 50 résultats
      results.sort((a, b) {
        final priceA = (a['price'] as num?)?.toDouble() ?? 0.0;
        final priceB = (b['price'] as num?)?.toDouble() ?? 0.0;
        return priceA.compareTo(priceB);
      });

      final limitedResults = results.take(50).toList();

      return limitedResults
          .map((e) => MedicineAvailability.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Erreur searchMedicinesByLocation: $e');
      rethrow;
    }
  }

  /// 🔍 Ancienne méthode (sans filtres) - pour compatibilité
  Future<List<MedicineAvailability>> searchMedicines(String query) async {
    return searchMedicinesByLocation(
      medicineName: query,
      city: null,
      neighborhood: null,
    );
  }

  /// 🏥 Récupère toutes les pharmacies vérifiées
  Future<List<Map<String, dynamic>>> getPharmacies() async {
    try {
      final response = await _client
          .from('pharmacies')
          .select('id, name, address, city, lat, lng, phone, is_verified, opening_hours')
          .eq('is_verified', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getPharmacies: $e');
      rethrow;
    }
  }

  /// 🛒 Crée une réservation (VERSION CORRIGÉE)
  Future<void> createReservation({
    required String pharmacyId,
    required String medicineId,
    required int quantity,
  }) async {
    // ✅ Validation CRITIQUE des paramètres
    if (pharmacyId.isEmpty || pharmacyId == 'null') {
      throw Exception('ID pharmacie manquant ou invalide');
    }
    if (medicineId.isEmpty || medicineId == 'null') {
      throw Exception('ID médicament manquant ou invalide');
    }
    if (quantity <= 0) {
      throw Exception('Quantité invalide');
    }

    // ✅ Vérifier que l'utilisateur est connecté
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utilisateur non connecté');
    }

    // 📝 Debug logs (à supprimer en production si besoin)
    print('🔄 Création réservation:');
    print('  - pharmacyId: "$pharmacyId"');
    print('  - medicineId: "$medicineId"');
    print('  - userId: "$userId"');
    print('  - quantity: $quantity');
    print('  - timestamp: ${DateTime.now().toIso8601String()}');

    try {
      await _client.from('reservations').insert({
        'user_id': userId,
        'pharmacy_id': pharmacyId,      // ✅ Vérifié non-null ci-dessus
        'medicine_id': medicineId,      // ✅ Vérifié non-null ci-dessus
        'quantity': quantity,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select(); // ✅ Retourne l'ID créé pour confirmation

      print('✅ Réservation créée avec succès');
    } catch (e) {
      print('❌ Erreur insertion réservation: $e');
      
      // Messages d'erreur plus clairs pour le frontend
      if (e.toString().contains('foreign key constraint')) {
        throw Exception('Pharmacie ou médicament introuvable');
      } else if (e.toString().contains('null value in column')) {
        throw Exception('Données manquantes pour la réservation');
      }
      
      rethrow;
    }
  }

  /// 📋 Récupère les réservations d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserReservations() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final response = await _client
          .from('reservations')
          .select('''
            id, 
            quantity, 
            status, 
            created_at,
            medicines(id, name, dosage),
            pharmacies(id, name, address, city, phone)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getUserReservations: $e');
      rethrow;
    }
  }

  /// 🔄 Met à jour le statut d'une réservation
  Future<void> updateReservationStatus({
    required String reservationId,
    required String status, // 'pending', 'confirmed', 'completed', 'cancelled'
  }) async {
    try {
      final validStatuses = ['pending', 'confirmed', 'completed', 'cancelled'];
      if (!validStatuses.contains(status)) {
        throw Exception('Statut invalide: $status');
      }

      await _client
          .from('reservations')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId);

      print('✅ Statut mis à jour: $reservationId → $status');
    } catch (e) {
      print('❌ Erreur updateReservationStatus: $e');
      rethrow;
    }
  }

  /// 👤 Crée ou met à jour le profil utilisateur
  Future<void> createUserProfile({
    required String userId,
    required String fullName,
    required String phone,
    String role = 'patient', // 'patient' ou 'pharmacie'
  }) async {
    try {
      // Vérifier si le profil existe déjà
      final existing = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing != null) {
        // Mise à jour
        await _client
            .from('users')
            .update({
              'full_name': fullName,
              'phone': phone,
              'role': role,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      } else {
        // Création
        await _client.from('users').insert({
          'id': userId,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      print('✅ Profil utilisateur: $fullName ($role)');
    } catch (e) {
      print('❌ Erreur createUserProfile: $e');
      rethrow;
    }
  }

  /// 🔐 Vérifie le rôle d'un utilisateur
  Future<String> getUserRole(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] ?? 'patient';
    } catch (e) {
      print('⚠️ Erreur getUserRole: $e → rôle par défaut: patient');
      return 'patient';
    }
  }

  /// 📊 Récupère les stocks d'une pharmacie (pour interface pharmacien)
  Future<List<Map<String, dynamic>>> getPharmacyStock(String pharmacyId) async {
    try {
      final response = await _client
          .from('stocks')
          .select('''
            id,
            quantity,
            price,
            expiry_date,
            medicines(id, name, dci, dosage, form)
          ''')
          .eq('pharmacy_id', pharmacyId)
          .order('medicines.name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getPharmacyStock: $e');
      rethrow;
    }
  }

  /// 📦 Met à jour la quantité d'un stock
  Future<void> updateStockQuantity({
    required String stockId,
    required int newQuantity,
  }) async {
    try {
      if (newQuantity < 0) {
        throw Exception('Quantité invalide');
      }

      await _client
          .from('stocks')
          .update({
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', stockId);

      print('✅ Stock mis à jour: $stockId → $newQuantity');
    } catch (e) {
      print('❌ Erreur updateStockQuantity: $e');
      rethrow;
    }
  }

  /// 🏥 Récupère les réservations d'une pharmacie (pour interface pharmacien)
  Future<List<Map<String, dynamic>>> getPharmacyReservations(String pharmacyId) async {
    try {
      final response = await _client
          .from('reservations')
          .select('''
            id,
            quantity,
            status,
            created_at,
            users(id, full_name, phone),
            medicines(id, name, dosage)
          ''')
          .eq('pharmacy_id', pharmacyId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getPharmacyReservations: $e');
      rethrow;
    }
  }
}