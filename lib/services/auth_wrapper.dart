import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/pharmacist/pharmacist_home.dart'; // Ligne 3
import '../screens/patient/patient_home.dart';       // Ligne 4
import '../screens/admin/admin_pharmacies_screen.dart'; // Ligne 5
import '../screens/auth_screen.dart';    

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      // Utilisateur connecté, vérifier son rôle
      await _redirectBasedOnRole(user.id);
    }
    // Si user == null, rester sur l'écran de connexion
  }

  Future<void> _redirectBasedOnRole(String userId) async {
    try {
      // Récupérer le rôle de l'utilisateur
      final userData = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      final role = userData['role'];

      if (!mounted) return;

      // Redirection selon le rôle
      switch (role) {
        case 'pharmacist':
          // ✅ Vérifier si la pharmacie est validée
          final pharmacyData = await Supabase.instance.client
              .from('pharmacies')
              .select('is_verified, is_active')
              .eq('id', userId)
              .single();

          if (pharmacyData['is_verified'] == true && 
              pharmacyData['is_active'] == true) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PharmacistHomeScreen()),
            );
          } else {
            // Pharmacien non encore validé
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('⏳ Compte en attente'),
                  content: const Text(
                    'Votre pharmacie est en attente de validation par l\'administrateur. '
                    'Vous recevrez un email lorsque votre compte sera activé.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Supabase.instance.client.auth.signOut();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }
          break;

        case 'patient':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
          );
          break;

        case 'admin':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminPharmaciesScreen()),
          );
          break;

        default:
          // Rôle inconnu, déconnecter
          await Supabase.instance.client.auth.signOut();
          break;
      }
    } catch (e) {
      print('❌ Erreur vérification rôle: $e');
      // En cas d'erreur, déconnecter
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Par défaut, afficher l'écran de connexion
    return const AuthScreen();
  }
}