import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/availability.dart';
import '../services/location_service.dart';
import '../utils/location_utils.dart';
// ✅ Imports pour le Chat
import '../services/chat_service.dart';
import 'chat/chat_screen.dart';
// ✅ Import pour le CustomAppBar
import '../widgets/custom_app_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // 🎛️ Contrôleurs pour les champs de saisie
  final _medicineController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  
  // 🔧 Services
  final _service = SupabaseService();
  final _locationService = LocationService();
  // ✅ Service Chat
  final _chatService = ChatService();

  // 📊 État de l'application
  List<MedicineAvailability> _results = [];
  bool _isLoading = false;
  String? _error;

  // 📍 Variables de localisation GPS
  double? _userLat;
  double? _userLng;
  bool _isLocating = false;
  
  // 🔍 Option de tri par distance
  bool _sortByDistance = false;

  // 🌍 Liste des villes disponibles (Cameroun)
  final List<String> _cities = [
    'Douala', 'Yaoundé', 'Bafoussam', 'Garoua', 
    'Bamenda', 'Ngaoundéré', 'Maroua', 
    'Buea', 'Limbe', 'Kumba',
  ];
  String? _selectedCity;

  // ============================================
  // 🚪 DIALOG DE DÉCONNEXION - VERSION CORRIGÉE ✅
  // ============================================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Déconnexion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?\n\nVous devrez vous reconnecter pour continuer à utiliser Pharmalink Africa.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // 1️⃣ Fermer le dialog de confirmation
                Navigator.of(dialogContext).pop();
                
                // 2️⃣ Afficher le loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    return const Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.teal),
                          SizedBox(height: 16),
                          Text(
                            'Déconnexion...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
                
                // 3️⃣ Attendre un court instant pour que le loading s'affiche
                await Future.delayed(const Duration(milliseconds: 300));
                
                try {
                  // 4️⃣ Déconnexion Supabase
                  await Supabase.instance.client.auth.signOut();
                  
                  // 5️⃣ Fermer le loading
                  if (mounted) {
                    Navigator.of(context).pop(); // Ferme le dialog de loading
                    
                    // 6️⃣ Navigation vers login avec délai
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/auth',
                        (route) => false,
                      );
                    }
                  }
                } catch (e) {
                  print('Erreur déconnexion: $e');
                  
                  // 7️⃣ En cas d'erreur, fermer le loading et afficher l'erreur
                  if (mounted) {
                    Navigator.of(context).pop(); // Ferme le loading
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Erreur: $e'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 📍 Détecter la position GPS de l'utilisateur
  Future<void> _detectMyLocation() async {
    setState(() => _isLocating = true);

    try {
      final hasPermission = await _locationService.handleLocationPermission();
      
      if (!hasPermission) {
        if (mounted) {
          setState(() => _isLocating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Permission GPS refusée. Activez-la dans les paramètres.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        final address = await _locationService.getAddressFromPosition(
          position.latitude, 
          position.longitude
        );

        if (mounted) {
          setState(() {
            _userLat = position.latitude;
            _userLng = position.longitude;
            _cityController.text = address?['city'] ?? '';
            _neighborhoodController.text = address?['neighborhood'] ?? '';
            _selectedCity = address?['city'];
            _sortByDistance = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Localisation détectée ! Tri par distance activé.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Impossible d\'obtenir la position. Vérifiez que le GPS est activé.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Erreur géolocalisation: $e');
      if (mounted) {
        String message = 'Erreur GPS';
        if (e.toString().contains('Permission denied')) {
          message = 'Permission GPS refusée. Activez-la dans Paramètres > Applications';
        } else if (e.toString().contains('Location services disabled')) {
          message = 'Activez le GPS dans les paramètres';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  // 🔍 Fonction de recherche avec filtres + tri par distance
  Future<void> _search() async {
    if (_medicineController.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez entrer un nom de médicament');
      return;
    }

    setState(() { 
      _isLoading = true; 
      _error = null; 
    });

    try {
      final results = await _service.searchMedicinesByLocation(
        medicineName: _medicineController.text.trim(),
        city: _selectedCity ?? _cityController.text.trim(),
        neighborhood: _neighborhoodController.text.trim(),
      );

      if (_sortByDistance && _userLat != null && _userLng != null) {
        for (var item in results) {
          item.distanceFromUser = calculateDistanceInKm(
            _userLat!, 
            _userLng!, 
            item.lat, 
            item.lng
          );
        }
        results.sort((a, b) => 
          (a.distanceFromUser ?? 999).compareTo(b.distanceFromUser ?? 999)
        );
      }

      setState(() {
        _results = results;
        _isLoading = false;
        if (results.isEmpty) {
          _error = 'Aucun médicament trouvé dans cette zone. Essayez une autre localisation.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion: $e';
        _isLoading = false;
      });
    }
  }

  // 🧹 Effacer tous les filtres
  void _clearFilters() {
    _medicineController.clear();
    _cityController.clear();
    _neighborhoodController.clear();
    setState(() {
      _selectedCity = null;
      _userLat = null;
      _userLng = null;
      _results = [];
      _error = null;
      _sortByDistance = false;
    });
  }

  // 🚪 Déconnexion (ancienne méthode - gardée pour compatibilité)
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  // 🛒 Réserver un médicament - VERSION CORRIGÉE ✅
  void _reserve(MedicineAvailability item) {
    // Debug : afficher les données dans la console
    print('Réservation demandée:');
    print('  pharmacyId: "${item.pharmacyId}"');
    print('  medicineId: "${item.medicineId}"');
    print('  pharmacyName: ${item.pharmacyName}');
    print('  medicineName: ${item.medicineName}');

    // Validation CRITIQUE : vérifier que les IDs ne sont pas vides ou "null"
    if (item.pharmacyId.isEmpty || item.pharmacyId == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur: ID pharmacie manquant'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (item.medicineId.isEmpty || item.medicineId == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur: ID médicament manquant'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    int selectedQty = 1;
    double totalPrice = item.price;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateQty(int delta) {
              int newQty = selectedQty + delta;
              if (newQty >= 1 && newQty <= item.quantity) {
                setDialogState(() {
                  selectedQty = newQty;
                  totalPrice = item.price * selectedQty;
                });
              }
            }

            String formatForm(String? f) {
              if (f == null || f.isEmpty) return 'Non spécifié';
              return f[0].toUpperCase() + f.substring(1).toLowerCase();
            }

            return AlertDialog(
              title: const Text('🛒 Réserver'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Text(
                        '📦 Forme: ${formatForm(item.form)}',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Quantité souhaitée:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: selectedQty > 1 ? () => updateQty(-1) : null,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selectedQty',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: selectedQty < item.quantity ? Colors.green : Colors.grey),
                          onPressed: selectedQty < item.quantity ? () => updateQty(1) : null,
                        ),
                      ],
                    ),
                    Text(
                      'Stock dispo: ${item.quantity}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prix total:', style: TextStyle(fontSize: 16)),
                        Text(
                          '${totalPrice.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      print('Envoi de la réservation...');
                      print('  pharmacyId: ${item.pharmacyId}');
                      print('  medicineId: ${item.medicineId}');
                      print('  quantity: $selectedQty');
                      
                      await _service.createReservation(
                        pharmacyId: item.pharmacyId,
                        medicineId: item.medicineId,
                        quantity: selectedQty,
                      );
                      
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ Réservation confirmée !\nPrésentez-vous en pharmacie avec une pièce d\'identité.',
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Erreur réservation: $e');
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Échec: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💬 Ouvrir le chat avec la pharmacie
  Future<void> _openChat(MedicineAvailability item) async {
    try {
      // Créer ou récupérer la conversation
      final conversationId = await _chatService.getOrCreateConversation(
        pharmacyId: item.pharmacyId,
        medicineId: item.medicineId,
      );
      
      // Naviguer vers le chat
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              pharmacyName: item.pharmacyName,
              medicineName: item.medicineName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ AppBar avec Logo et boutons de déconnexion/rafraîchissement
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Rechercher un médicament',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // 🔄 Bouton Rafraîchir
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Recharger les données si nécessaire
                _results = [];
                _error = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 Actualisé'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Rafraîchir',
          ),
          
          // 🚪 Bouton Déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Se déconnecter',
            color: Colors.white,
          ),
          
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 📍 Section Filtres de localisation
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre + Bouton GPS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Ma localisation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: _isLocating 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : const Icon(Icons.my_location, color: Colors.teal),
                      onPressed: _isLocating ? null : _detectMyLocation,
                      tooltip: 'Détecter ma position',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Ville (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCity = value);
                  },
                ),
                const SizedBox(height: 8),
                
                // Quartier (champ libre)
                TextField(
                  controller: _neighborhoodController,
                  decoration: const InputDecoration(
                    labelText: 'Quartier (optionnel)',
                    hintText: 'Ex: Akwa, Bastos, Bonanjo...',
                    prefixIcon: Icon(Icons.place),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nom du médicament
                TextField(
                  controller: _medicineController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du médicament *',
                    hintText: 'Ex: Paracétamol, Amoxicilline...',
                    prefixIcon: Icon(Icons.medication),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                
                // ✅ Checkbox "Trier par distance" (visible seulement si GPS actif)
                if (_userLat != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _sortByDistance,
                          activeColor: Colors.teal,
                          onChanged: (val) {
                            setState(() => _sortByDistance = val!);
                            if (_results.isNotEmpty) _search();
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Trier par distance (Proches de moi)',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_sortByDistance)
                          Icon(Icons.check_circle, color: Colors.teal, size: 20),
                      ],
                    ),
                  ),

                // Bouton Rechercher
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _search,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Recherche...' : 'Rechercher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 📊 Compteur de résultats
          if (_results.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_results.length} pharmacie${_results.length > 1 ? 's' : ''} trouvée${_results.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  if (_sortByDistance && _userLat != null)
                    const Text(
                      '📏 Tri: Distance',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                ],
              ),
            ),
          
          // 📋 Liste des résultats
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 64,
                                color: Colors.orange.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'Remplissez les champs et cliquez sur Rechercher',
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade50,
                                    child: Icon(
                                      Icons.local_pharmacy,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    item.medicineName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(item.pharmacyName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.address,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qté: ${item.quantity} • Prix: ${item.price.toStringAsFixed(0)} FCFA',
                                        style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                                      ),
                                      // ✅ Affichage de la distance si disponible
                                      if (item.distanceFromUser != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '📍 À ${item.distanceFromUser!.toStringAsFixed(2)} km de vous',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  // ✅ TRAILING CORRIGÉ : Chat + Réserver
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 💬 Bouton Chat
                                      IconButton(
                                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.teal),
                                        tooltip: 'Contacter la pharmacie',
                                        onPressed: () => _openChat(item),
                                      ),
                                      // 🛒 Bouton Réserver
                                      IconButton(
                                        icon: Icon(Icons.add_shopping_cart, color: Colors.teal.shade700),
                                        onPressed: () => _reserve(item),
                                        tooltip: 'Réserver',
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }
}