// lib/screens/pharmacist/pharmacist_home.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports des écrans existants
import 'stock_screen.dart';
import 'reservations_screen.dart';

// ✅ Imports des nouvelles fonctionnalités
import '../chat/conversations_list_screen.dart'; // ← Chat patient-pharmacien
import 'analytics_screen.dart';                   // ← Dashboard Analytics

class PharmacistHomeScreen extends StatefulWidget {
  const PharmacistHomeScreen({super.key});

  @override
  State<PharmacistHomeScreen> createState() => _PharmacistHomeScreenState();
}

class _PharmacistHomeScreenState extends State<PharmacistHomeScreen> {
  
  // ============================================
  // 🚪 Dialog de confirmation de déconnexion
  // ============================================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Déconnexion'),
            ],
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?\n\nVous devrez vous reconnecter pour accéder à votre tableau de bord.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Déconnexion de Supabase
                  await Supabase.instance.client.auth.signOut();
                  
                  // Navigation vers login
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/auth',
                      (route) => false, // Supprime toutes les routes précédentes
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Erreur: $e'),
                        backgroundColor: Colors.red,
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
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // 🔄 Fonction de rafraîchissement
  // ============================================
  void _refreshData() {
    setState(() {
      // Recharger les données si nécessaire
      // Les widgets enfants se rafraîchiront automatiquement
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('🔄 Données actualisées'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // ✅ 4 onglets : Stock, Commandes, Messages, Analytics
      child: Scaffold(
        // ✅ AppBar complète avec logo et boutons fonctionnels
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
                'Pharmalink Pro',
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
              onPressed: _refreshData,
              tooltip: 'Rafraîchir les données',
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
        
        // ✅ Barre d'onglets
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: const TabBar(
            isScrollable: true, // ✅ Permet le scroll horizontal sur petits écrans
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            tabs: [
              Tab(icon: Icon(Icons.inventory), text: 'Stock'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Commandes'),
              Tab(icon: Icon(Icons.chat), text: 'Messages'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'), // ✅ NOUVEAU
            ],
          ),
        ),
        
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(), // ✅ Désactive le swipe horizontal (optionnel)
          children: [
            StockManagementScreen(),           // Onglet 1 : Gestion du stock
            PharmacistReservationsScreen(),    // Onglet 2 : Réservations
            ConversationsListScreen(),         // Onglet 3 : Chat avec patients
            AnalyticsScreen(),                 // Onglet 4 : Dashboard Analytics ✅ NOUVEAU
          ],
        ),
      ),
    );
  }
}