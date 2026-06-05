import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';

class PharmacyDetailsScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  final Map<String, dynamic>? medicine;
  final Position? currentPosition;

  const PharmacyDetailsScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    this.medicine,
    this.currentPosition,
  });

  @override
  State<PharmacyDetailsScreen> createState() => _PharmacyDetailsScreenState();
}

class _PharmacyDetailsScreenState extends State<PharmacyDetailsScreen> {
  Map<String, dynamic>? _pharmacy;
  bool _isLoading = true;
  Position? _pharmacyPosition;  // ✅ Pour la navigation
  LatLng? _pharmacyLatLng;      // ✅ Pour l'affichage carte
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadPharmacyDetails();
  }

  Future<void> _loadPharmacyDetails() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('pharmacies')
          .select('*')
          .eq('id', widget.pharmacyId)
          .single();

      setState(() {
  _pharmacy = response;
  if (_pharmacy?['latitude'] != null && _pharmacy?['longitude'] != null) {
    final lat = (_pharmacy!['latitude'] as num).toDouble();
    final lng = (_pharmacy!['longitude'] as num).toDouble();
    
    // ✅ Pour la carte (plus simple)
    _pharmacyLatLng = LatLng(lat, lng);
    
    // ✅ Pour la navigation - TOUS les paramètres requis
    _pharmacyPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
  _isLoading = false;
});
    } catch (e) {
      print('❌ Erreur chargement pharmacie: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ OUVRIR GOOGLE MAPS POUR L'ITINÉRAIRE
  Future<void> _openNavigation() async {
    if (_pharmacyPosition == null || widget.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Position indisponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // URL Google Maps avec itinéraire
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${widget.currentPosition!.latitude},${widget.currentPosition!.longitude}'
      '&destination=${_pharmacyPosition!.latitude},${_pharmacyPosition!.longitude}'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Impossible d\'ouvrir Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ OUVRIR WAZE (alternative)
  Future<void> _openWaze() async {
    if (_pharmacyPosition == null) return;

    final url = Uri.parse(
      'waze://?ll=${_pharmacyPosition!.latitude},${_pharmacyPosition!.longitude}&navigate=yes',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waze n\'est pas installé')),
      );
    }
  }

  // ✅ CONTACTER LA PHARMACIE
  void _contactPharmacy() {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': '',
        'pharmacyName': widget.pharmacyName,
        'medicineName': widget.medicine?['name'] ?? 'Discussion',
        'pharmacyId': widget.pharmacyId,
      },
    );
  }

  // ✅ AJOUTER AU PANIER
  void _addToCart() {
    if (widget.medicine == null) return;

    final cartItem = CartItem(
      medicineId: widget.medicine!['id'],
      pharmacyId: widget.pharmacyId,
      medicineName: widget.medicine!['name'],
      pharmacyName: widget.pharmacyName,
      dosage: widget.medicine!['dosage'],
      form: widget.medicine!['form'],
      price: (widget.medicine!['price'] as num).toDouble(),
      quantity: 1,
      totalPrice: (widget.medicine!['price'] as num).toDouble(),
    );

    context.read<CartService>().addToCart(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${widget.medicine!['name']} ajouté au panier'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ✅ APP BAR AVEC IMAGE DE FOND
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.teal,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.pharmacyName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de fond ou carte
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _pharmacyPosition != null
                          ? FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: LatLng(
                                  _pharmacyPosition!.latitude,
                                  _pharmacyPosition!.longitude,
                                ),
                                initialZoom: 16.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        _pharmacyPosition!.latitude,
                                        _pharmacyPosition!.longitude,
                                      ),
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
                            )
                          : Container(color: Colors.teal.shade200),
                  // Dégradé
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Partager la pharmacie
                },
              ),
            ],
          ),

          // ✅ CONTENU PRINCIPAL
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ BOUTONS D'ACTION RAPIDE
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _contactPharmacy,
                                icon: const Icon(Icons.chat_bubble),
                                label: const Text('Contacter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.medicine != null
                                    ? _addToCart
                                    : null,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(
                                  widget.medicine != null
                                      ? 'Ajouter au panier'
                                      : 'Voir produits',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openNavigation,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Itinéraire (Google Maps)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openWaze,
                            icon: const Icon(Icons.directions_car),
                            label: const Text('Ouvertir avec Waze'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ✅ INFORMATIONS DE LA PHARMACIE
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.location_on,
                          'Adresse',
                          _pharmacy?['address'] ?? 'Non renseignée',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.phone,
                          'Téléphone',
                          _pharmacy?['phone'] ?? 'Non renseigné',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.access_time,
                          'Horaires',
                          _pharmacy?['working_hours'] ?? 'Non renseignés',
                        ),
                        if (_pharmacy?['is_open'] != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _pharmacy!['is_open']
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _pharmacy!['is_open']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _pharmacy!['is_open']
                                    ? 'Ouvert maintenant'
                                    : 'Fermé',
                                style: TextStyle(
                                  color: _pharmacy!['is_open']
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ✅ MÉDICAMENT RECHERCHÉ (si applicable)
                  if (widget.medicine != null) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Médicament disponible',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.teal,
                                        child: const Icon(
                                          Icons.medication,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.medicine!['name'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${widget.medicine!['dosage']} - ${widget.medicine!['form']}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStat(
                                        Icons.attach_money,
                                        '${widget.medicine!['price']} FCFA',
                                        'Prix',
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey[300],
                                      ),
                                      _buildStat(
                                        Icons.inventory_2,
                                        '${widget.medicine!['stock_quantity']}',
                                        'En stock',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Espace pour le scroll
                ],
              ),
            ),
        ],
      ),

      // ✅ FLOATING ACTION BUTTON POUR NAVIGATION RAPIDE
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNavigation,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.navigation),
        label: const Text('Y aller'),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.teal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}