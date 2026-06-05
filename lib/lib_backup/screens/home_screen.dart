import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Import du CustomAppBar avec logo
import '../widgets/custom_app_bar.dart';

import 'search_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SearchScreen(), // L'écran de recherche existant
    const MapScreen(),    // Le nouvel écran de carte
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  /// 🔔 Écoute les mises à jour de réservations en temps réel
  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // On écoute la table 'reservations'
    // Filtre : Uniquement les réservations de CET utilisateur
    Supabase.instance.client
        .channel('reservations_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            // Quand une réservation est modifiée (ex: statut passe à 'confirmed')
            final newStatus = payload.newRecord['status'];
            
            if (newStatus == 'confirmed') {
              // Afficher une notification In-App
              if (mounted) {
                _showNotification(
                  context, 
                  "Commande Confirmée", 
                  "Votre médicament est prêt à être récupéré en pharmacie ! ✅"
                );
              }
            } else if (newStatus == 'pending') {
              if (mounted) {
                _showNotification(
                  context, 
                  "Nouvelle Réservation", 
                  "Votre demande de réservation a été envoyée."
                );
              }
            }
          },
        )
        .subscribe();
  }

  /// Affiche une notification dialog
  void _showNotification(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Super !",
              style: TextStyle(
                color: Colors.teal.shade700, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ AppBar personnalisée avec logo
      appBar: const CustomAppBar(
        title: 'Pharmalink Africa',
      ),
      
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Carte',
          ),
        ],
      ),
    );
  }
}