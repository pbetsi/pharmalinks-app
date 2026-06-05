import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/location_service.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';
import 'cart_screen.dart';

class SearchScreen extends StatefulWidget {
  final Position? initialPosition;
  final String? initialQuery;

  const SearchScreen({
    super.key, 
    this.initialPosition,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _locationService = LocationService();
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String _locationStatus = '';
  bool _isSearching = false;
  
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
      _locationStatus = 'Position détectée';
    }
    
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _medicineController.text = widget.initialQuery!;
      _saveToHistory(widget.initialQuery!);
      _searchMedicines();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Recherche de position...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Service de localisation désactivé';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Permission refusée';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = 'Position détectée avec succès';
        _isLoadingLocation = false;
      });

      try {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
      } catch (e) {
        print('⚠️ Erreur déplacement carte: $e');
      }

      await _saveUserLocation(position);
    } catch (e) {
      setState(() {
        _locationStatus = 'Erreur: ${e.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _saveUserLocation(Position position) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .upsert({
              'id': user.id,
              'last_latitude': position.latitude,
              'last_longitude': position.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'id');
      }
    } catch (e) {
      print('⚠️ Erreur sauvegarde position: $e');
    }
  }

  Future<void> _saveToHistory(String medicineName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('search_history');
      List<Map<String, dynamic>> history = [];
      
      if (historyString != null) {
        final List<dynamic> historyList = json.decode(historyString);
        history = historyList.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      final existingIndex = history.indexWhere(
        (item) => item['medicine'] == medicineName && 
                  item['pharmacy'] == (_cityController.text.isNotEmpty ? _cityController.text : 'Toutes pharmacies'),
      );

      if (existingIndex != -1) {
        history[existingIndex]['timestamp'] = DateTime.now().toIso8601String();
        final item = history.removeAt(existingIndex);
        history.insert(0, item);
      } else {
        history.insert(0, {
          'medicine': medicineName,
          'pharmacy': _cityController.text.isNotEmpty ? _cityController.text : 'Toutes pharmacies',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      if (history.length > 10) history = history.sublist(0, 10);
      await prefs.setString('search_history', json.encode(history));
      print('💾 Recherche sauvegardée : $medicineName');
    } catch (e) {
      print('❌ Erreur historique: $e');
    }
  }

  Future<void> _searchMedicines() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final medicineName = _medicineController.text.trim();
      print('🔍 Recherche de: "$medicineName"');

      _saveToHistory(medicineName);

      var query = Supabase.instance.client
          .from('medicines')
          .select('''
            id,
            name,
            dosage,
            form,
            price,
            stock_quantity,
            is_available,
            pharmacy_id,
            image_url,
            description,
            manufacturer,
            requires_prescription,
            pharmacies!medicines_pharmacy_id_fkey (
              id,
              name,
              address,
              city,
              phone,
              latitude,
              longitude
            )
          ''')
          .ilike('name', '%$medicineName%')
          .eq('is_available', true);

      final response = await query;
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);

      if (_currentPosition != null) {
        print('📍 Tri automatique par distance activé');
        
        results = results.where((med) {
          final pharmacy = med['pharmacies'] as Map<String, dynamic>?;
          if (pharmacy == null || 
              pharmacy['latitude'] == null || 
              pharmacy['longitude'] == null) {
            return false;
          }

          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (pharmacy['latitude'] as num).toDouble(),
            (pharmacy['longitude'] as num).toDouble(),
          );

          med['distance'] = distance;
          return true;
        }).toList();

        results.sort((a, b) {
          final distA = (a['distance'] as num?)?.toDouble() ?? 999999;
          final distB = (b['distance'] as num?)?.toDouble() ?? 999999;
          return distA.compareTo(distB);
        });

        print('✅ Résultats triés par distance: ${results.length} pharmacies');
      }

      print('✅ Résultats finaux: ${results.length}');

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (mounted && results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Aucun médicament trouvé pour "$medicineName"'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('❌ Erreur recherche: $e');
      setState(() { _searchResults = []; _isSearching = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Future<void> _reserveMedicine(Map<String, dynamic> medicine, Map<String, dynamic> pharmacy, int quantity) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Veuillez vous connecter'), backgroundColor: Colors.red),
        );
        return;
      }

      final reservation = await Supabase.instance.client
          .from('reservations')
          .insert({
            'medicine_id': medicine['id'],
            'patient_id': user.id,
            'pharmacy_id': pharmacy['id'],
            'quantity': quantity,
            'total_price': (medicine['price'] as num) * quantity,
            'status': 'pending',
            'patient_name': user.email,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      await Supabase.instance.client.from('notifications').insert({
        'user_id': pharmacy['id'],
        'type': 'new_order',
        'title': 'Nouvelle commande',
        'message': '${user.email} a commandé ${medicine['name']}',
        'data': {
          'reservationId': reservation['id'],
          'patientName': user.email,
          'medicineName': medicine['name'],
          'quantity': quantity,
          'totalPrice': (medicine['price'] as num) * quantity,
        },
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réservation effectuée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur réservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToCart(Map<String, dynamic> medicine, Map<String, dynamic> pharmacy) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez vous connecter pour réserver'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final medicineId = medicine['id'];
    final quantity = _quantities[medicineId] ?? 1;
    
    final cartItem = CartItem(
      medicineId: medicineId,
      pharmacyId: pharmacy['id'],
      medicineName: medicine['name'],
      pharmacyName: pharmacy['name'] ?? 'Pharmacie',
      dosage: medicine['dosage'],
      form: medicine['form'],
      price: (medicine['price'] as num).toDouble(),
      quantity: quantity,
      totalPrice: (medicine['price'] as num).toDouble() * quantity,
    );

    context.read<CartService>().addToCart(cartItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${medicine['name']} ajouté au panier'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Voir',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ),
      );
    }
  }

  void _navigateToPharmacyDetails(Map<String, dynamic> pharmacy, Map<String, dynamic> medicine) {
    Navigator.pushNamed(
      context,
      '/pharmacy-details',
      arguments: {
        'pharmacyId': pharmacy['id'],
        'pharmacyName': pharmacy['name'],
        'medicine': medicine,
        'currentPosition': _currentPosition,
      },
    );
  }

  Future<void> _contactPharmacy(Map<String, dynamic>? pharmacy, Map<String, dynamic> medicine) async {
    if (pharmacy == null) return;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Veuillez vous connecter'), backgroundColor: Colors.red)
        );
        return;
      }

      if (user.id.isEmpty || 
          pharmacy['id'].toString().isEmpty || 
          medicine['id'].toString().isEmpty) {
        print('❌ IDs vides détectés!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Données invalides'), backgroundColor: Colors.red)
        );
        return;
      }

      print('🔍 Création/récupération conversation...');
      print('Patient ID: ${user.id}');
      print('Pharmacy ID: ${pharmacy['id']}');

      var existingConv = await Supabase.instance.client
          .from('conversations')
          .select('*')
          .eq('patient_id', user.id)
          .eq('pharmacy_id', pharmacy['id'])
          .maybeSingle();

      String conversationId;

      if (existingConv != null) {
        conversationId = existingConv['id'];
        print('✅ Conversation existante: $conversationId');
      } else {
        print('🆕 Création nouvelle conversation...');
        
        final newConv = await Supabase.instance.client
            .from('conversations')
            .insert({
              'patient_id': user.id,
              'pharmacy_id': pharmacy['id'],
              'medicine_id': medicine['id'],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        conversationId = newConv['id'];
        print('✅ Nouvelle conversation créée: $conversationId');
      }

      if (mounted) {
        print('🚀 Navigation vers le chat...');
        print('   conversationId: $conversationId');
        
        await Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'pharmacyName': pharmacy['name'] ?? 'Pharmacie',
            'medicineName': medicine['name'] ?? 'Discussion',
          },
        );
      }
    } catch (e) {
      print('❌ Erreur contact pharmacie: $e');
      print('❌ Stack: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQuantitySelector(Map<String, dynamic> medicine, Map<String, dynamic> pharmacy) {
    int quantity = 1;
    final maxStock = medicine['stock_quantity'] ?? 10; // Utilisé en interne mais pas affiché
    final price = (medicine['price'] as num).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Quantité - ${medicine['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Prix unitaire: ${price.toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 8),
              // Stock visible uniquement dans le sélecteur de quantité (pour validation)
              Text('Disponibilité: ${maxStock > 0 ? "En stock" : "Rupture"}', 
                  style: TextStyle(color: maxStock > 0 ? Colors.green : Colors.red)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: quantity > 1 ? () {
                      setDialogState(() => quantity--);
                    } : null,
                    color: Colors.teal,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: quantity < maxStock ? () {
                      setDialogState(() => quantity++);
                    } : null,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Prix total',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '${(price * quantity).toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final cartItem = CartItem(
                  medicineId: medicine['id'],
                  pharmacyId: pharmacy['id'],
                  medicineName: medicine['name'],
                  pharmacyName: pharmacy['name'] ?? 'Pharmacie',
                  dosage: medicine['dosage'],
                  form: medicine['form'],
                  price: price,
                  quantity: quantity,
                  totalPrice: price * quantity,
                );

                context.read<CartService>().addToCart(cartItem);
                Navigator.pop(ctx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ $quantity x ${medicine['name']} ajouté au panier'),
                    backgroundColor: Colors.green,
                    action: SnackBarAction(
                      label: 'Voir',
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(context, '/cart');
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Ajouter au panier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NOUVELLE FONCTION : Affichage avec image en haut, détails en dessous, SANS STOCK
 // ✅ NOUVELLE FONCTION : Image mieux visible, SANS STOCK
Widget _buildSearchResult(Map<String, dynamic> result) {
  final medicine = result;
  final pharmacy = medicine['pharmacies'] as Map<String, dynamic>?;
  double? distance = result['distance'] as double?;
  
  if (distance == null && _currentPosition != null && pharmacy?['latitude'] != null) {
    distance = _calculateDistance(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      (pharmacy!['latitude'] as num).toDouble(), 
      (pharmacy['longitude'] as num).toDouble()
    );
  }

  return Container(
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖼️ IMAGE DU PRODUIT AMÉLIORÉE (plus grande et mieux cadrée)
        Container(
          width: double.infinity,
          height: 220, // ✅ Augmenté de 150 à 220 pour meilleure visibilité
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: medicine['image_url'] != null && medicine['image_url'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    medicine['image_url'],
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.contain, // ✅ Contain pour voir tout le produit
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication,
                              size: 80,
                              color: Colors.teal.shade300,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image non disponible',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication,
                        size: 80,
                        color: Colors.teal.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pas d\'image',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
        ),
        
        // 📝 DESCRIPTION DU PRODUIT
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom du médicament
              Text(
                medicine['name'] ?? 'Médicament',
                style: const TextStyle(
                  fontSize: 18, // ✅ Augmenté de 16 à 18
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Pharmacie (cliquable)
              GestureDetector(
                onTap: () {
                  if (pharmacy != null) {
                    _navigateToPharmacyDetails(pharmacy, medicine);
                  }
                },
                child: Text(
                  pharmacy?['name'] ?? 'Pharmacie',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              
              // Description si disponible
              if (medicine['description'] != null && medicine['description'].toString().isNotEmpty) ...[
                Text(
                  medicine['description'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
              ],
              
              // Prix
              Row(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${medicine['price']} FCFA',
                    style: const TextStyle(
                      fontSize: 16, // ✅ Augmenté
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // ❌ STOCK SUPPRIMÉ - Ne pas afficher aux patients
              // Le stock reste utilisé en interne dans _showQuantitySelector
              
              // Dosage et forme
              Row(
                children: [
                  Icon(Icons.science, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${medicine['dosage']} - ${medicine['form']}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              
              // Distance
              if (distance != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: Colors.teal.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Boutons d'action
              Row(
                children: [
                  // Bouton Contacter
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _contactPharmacy(pharmacy, medicine),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Contacter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10), // ✅ Plus grand
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Bouton Ajouter
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showQuantitySelector(medicine, pharmacy!),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10), // ✅ Plus grand
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Rechercher un médicament'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          Consumer<CartService>(
            builder: (context, cart, _) => Stack(
              children: [
                IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))),
                if (cart.itemCount > 0)
                  Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10)))),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _getCurrentLocation, tooltip: 'Actualiser position'),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ma position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_locationStatus, style: TextStyle(color: Colors.teal.shade600, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.refresh, color: Colors.teal), onPressed: _getCurrentLocation),
                        ],
                      ),
                    ),
                    if (_currentPosition != null)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
                              MarkerLayer(markers: [
                                Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 60, height: 60, child: const Icon(Icons.location_on, color: Colors.red, size: 60)),
                              ]),
                            ],
                          ),
                        ),
                      )
                    else if (_isLoadingLocation)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.location_searching, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _currentPosition != null 
                              ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                              : 'En attente de position...',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _medicineController,
                      decoration: InputDecoration(
                        labelText: 'Nom du médicament *',
                        hintText: 'Ex: Paracétamol...',
                        prefixIcon: const Icon(Icons.medication, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.teal.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Veuillez entrer un médicament';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSearching ? null : _searchMedicines,
                        icon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                        label: Text(_isSearching ? 'Recherche en cours...' : 'Rechercher', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_searchResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${_searchResults.length} résultat(s) trouvé(s)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_currentPosition != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.near_me, size: 14, color: Colors.teal.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Triés par distance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._searchResults.map((result) => _buildSearchResult(result)).toList(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _locationService.dispose();
    super.dispose();
  }
}