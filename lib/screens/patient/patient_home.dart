import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../notifications/notifications_screen.dart';
import '../search_screen.dart';
import 'map_position_screen.dart';
import 'patient_order_notifications_screen.dart';
import 'my_orders_screen.dart';
// ✅ IMPORT POUR LE SCANNER (à décommenter quand le fichier existe)
// import 'prescription_scan_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _unreadCount = 0;
  int _orderNotificationsCount = 0;
  List<Map<String, dynamic>> _searchHistory = [];
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String _locationStatus = 'Position non détectée';

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    _loadUnreadNotificationsCount();
    _setupNotificationListener();
    _loadSearchHistory();
    _getCurrentLocation();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .inFilter('type', ['order_accepted', 'order_rejected'])
          .eq('read', false);

      setState(() {
        _orderNotificationsCount = response.length;
      });
    } catch (e) {
      print('❌ Erreur chargement count: $e');
    }
  }

  void _setupNotificationListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
      final unreadNotifications = data.where((notif) => notif['read'] == false).toList();
      
      final orderNotifications = data.where((n) {
        final type = n['type'] as String?;
        return (type == 'order_accepted' || type == 'order_rejected') && n['read'] == false;
      }).length;

      setState(() {
        _unreadCount = unreadNotifications.length;
        _orderNotificationsCount = orderNotifications;
      });
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
        
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/auth',
            (route) => false,
          );
        }
      } catch (e) {
        print('❌ Erreur déconnexion: $e');
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
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Localisation en cours...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Service de localisation désactivé';
          _isLoadingLocation = false;
        });
        
        if (mounted) {
          _showEnableLocationDialog();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Permission de localisation refusée';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Permission définitivement refusée';
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = 'Position détectée avec succès';
        _isLoadingLocation = false;
      });

      print('📍 Position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      setState(() {
        _locationStatus = 'Erreur: ${e.toString()}';
        _isLoadingLocation = false;
      });
      print('❌ Erreur géolocalisation: $e');
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer la localisation'),
        content: const Text(
          'Veuillez activer la localisation pour utiliser cette fonctionnalité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('search_history');
      if (historyString != null) {
        final List<dynamic> historyList = json.decode(historyString);
        setState(() {
          _searchHistory = historyList.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
    }
  }

  Future<void> _saveSearch(String medicineName, String? pharmacyName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newSearch = {
        'medicine': medicineName,
        'pharmacy': pharmacyName ?? 'Toutes pharmacies',
        'timestamp': DateTime.now().toIso8601String(),
      };

      _searchHistory.insert(0, newSearch);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }

      await prefs.setString('search_history', json.encode(_searchHistory));
      setState(() {});
    } catch (e) {
      print('❌ Erreur sauvegarde historique: $e');
    }
  }

  Future<void> _clearSearchHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text('Voulez-vous vraiment supprimer tout l\'historique ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('search_history');
        setState(() {
          _searchHistory = [];
        });
      } catch (e) {
        print('❌ Erreur effacement historique: $e');
      }
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('read', false);

      setState(() {
        _unreadCount = response.length;
      });
    } catch (e) {
      print('❌ Erreur chargement notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmalink Africa'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_orderNotificationsCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PatientOrderNotificationsScreen(),
                      ),
                    ).then((_) => _loadUnreadNotificationsCount());
                  },
                  tooltip: 'Notifications de commandes',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _orderNotificationsCount > 9 ? '9+' : '$_orderNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((_) => _loadUnreadNotifications());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            tooltip: 'Actualiser position',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getCurrentLocation();
          await _loadUnreadNotifications();
          await _loadUnreadNotificationsCount();
          await _loadSearchHistory();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPositionSection(),
              const SizedBox(height: 16),

              _buildSearchSection(),
              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildHistorySection(),
              const SizedBox(height: 8),

              // ✅ MES COMMANDES
              _buildServiceItem(
                icon: Icons.shopping_bag,
                iconColor: Colors.blue,
                title: 'Mes Commandes',
                subtitle: 'Suivez vos commandes en cours',
                onTap: () {
                  Navigator.pushNamed(context, '/my-orders');
                },
              ),
              const SizedBox(height: 8),

              // ✅ PHARMACIES À PROXIMITÉ
              _buildServiceItem(
                icon: Icons.local_pharmacy,
                iconColor: Colors.teal,
                title: 'Pharmacies à proximité',
                subtitle: 'Trouvez une pharmacie ouverte maintenant',
                onTap: () {
                  Navigator.pushNamed(context, '/pharmacy-finder');
                },
              ),
              const SizedBox(height: 8),

              // ✅ SCANNER ORDONNANCE - NOUVEAU BOUTON AJOUTÉ
              _buildServiceItem(
                icon: Icons.document_scanner,
                iconColor: Colors.purple,
                title: 'Scanner Ordonnance',
                subtitle: 'Envoyez votre ordonnance en photo',
                onTap: () {
                  // ✅ NAVIGATION VERS LE SCANNER
                  Navigator.pushNamed(context, '/prescription-scan');
                  // OU si le fichier existe déjà :
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const PrescriptionScanScreen(),
                  //   ),
                  // );
                },
              ),
              const SizedBox(height: 8),

              // ✅ DISCUSSIONS
              _buildServiceItem(
                icon: Icons.chat_bubble,
                iconColor: Colors.orange,
                title: 'Discussions',
                subtitle: 'Parlez avec les pharmaciens',
                onTap: () {
                  Navigator.pushNamed(context, '/conversations');
                },
              ),
              const SizedBox(height: 8),

              // ✅ NOTIFICATIONS
              _buildServiceItem(
                icon: Icons.notifications,
                iconColor: Colors.purple,
                title: 'Notifications',
                subtitle: _unreadCount > 0 
                    ? '$_unreadCount notification(s) non lue(s)'
                    : 'Aucune nouvelle notification',
                badge: _unreadCount > 0 ? _unreadCount : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((_) => _loadUnreadNotifications());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isLoadingLocation ? Icons.my_location : Icons.location_on,
                  color: _currentPosition != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ma position',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _locationStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentPosition != null 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentPosition != null)
                  IconButton(
                    icon: const Icon(Icons.map, color: Colors.teal),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPositionScreen(
                            position: _currentPosition!,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Voir sur la carte',
                  ),
              ],
            ),
          ),

          if (_currentPosition != null)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoadingLocation)
                      const CircularProgressIndicator()
                    else
                      const Icon(
                        Icons.location_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _locationStatus,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.location_searching, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ),
          );
          if (mounted) {
            _loadSearchHistory();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.search,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Rechercher un médicament',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trouvez les pharmacies près de chez vous',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: Icon(Icons.history, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historique',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Vos recherches récentes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchHistory.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _clearSearchHistory,
                    tooltip: 'Effacer l\'historique',
                    iconSize: 20,
                  ),
              ],
            ),
          ),
          
          if (_searchHistory.isNotEmpty) ...[
            const Divider(height: 1),
            ..._searchHistory.take(3).map((search) {
              final timestamp = DateTime.parse(search['timestamp']);
              final timeStr = _formatTime(timestamp);
              
              return ListTile(
                dense: true,
                leading: Icon(Icons.search, size: 18, color: Colors.grey[600]),
                title: Text(
                  search['medicine'],
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  '${search['pharmacy']} • $timeStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchScreen(initialQuery: search['medicine']),
                    ),
                  ).then((_) => _loadSearchHistory());
                },
              );
            }).toList(),
            if (_searchHistory.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Historique complet: ${_searchHistory.length} recherches')),
                    );
                  },
                  child: Text(
                    'Voir tout (${_searchHistory.length})',
                    style: TextStyle(color: Colors.teal.shade700),
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Aucune recherche récente',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Text(title),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return '${time.day}/${time.month} à ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}