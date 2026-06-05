import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports des écrans
import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/pharmacist/pharmacist_home.dart';

// ✅ Import du service de notifications
import 'services/notification_service.dart';

// ============================================================================
// 🚀 POINT D'ENTRÉE PRINCIPAL
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1️⃣ Initialiser Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: true, // Affiche les logs en mode développement
    );
    print('✅ Supabase initialisé avec succès !');
    print('🔗 URL: ${SupabaseConfig.url}');

    // 2️⃣ Initialiser les notifications push 🔔
    await NotificationService().init();
    print('✅ Notifications push initialisées !');
    
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
  }

  runApp(const PharmalinkApp());
}

// ============================================================================
// 🎨 WIDGET RACINE DE L'APPLICATION
// ============================================================================
class PharmalinkApp extends StatelessWidget {
  const PharmalinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmalink Africa',
      debugShowCheckedModeBanner: false,

      // 🎨 Thème personnalisé
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: const Color(0xFF00897B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
          secondary: const Color(0xFF4DB6AC),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF00897B),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // ✅ ROUTES NOMMÉES - Pour la navigation
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(), // Espace patient
        '/search': (context) => const SearchScreen(), // Recherche médicaments
        '/pharmacist-home': (context) => const PharmacistHomeScreen(), // Espace pharmacien
      },

      // 🔄 Navigation dynamique selon l'état d'authentification
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // État de chargement initial
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('⏳ Chargement de l\'authentification...');
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF00897B)),
              ),
            );
          }

          // Gestion des erreurs d'authentification
          if (snapshot.hasError) {
            print('❌ Erreur d\'authentification: ${snapshot.error}');
            return Scaffold(
              body: Center(
                child: Text(
                  '❌ Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // Vérifie si l'utilisateur est connecté
          final session = snapshot.data?.session;
          if (session != null) {
            print('✅ Utilisateur connecté, redirection vers RoleRouter');
            return const RoleRouter(); // ✅ Routage basé sur le rôle
          }
          
          print('🔓 Utilisateur non connecté, affichage de AuthScreen');
          return const AuthScreen(); // Écran de connexion/inscription
        },
      ),

      // ✅ Gestion des routes inconnues (fallback)
      onUnknownRoute: (settings) {
        print('⚠️ Route inconnue: ${settings.name}, redirection vers /auth');
        return MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        );
      },
    );
  }
}

// ============================================================================
// 🔀 ROUTEUR BASÉ SUR LE RÔLE UTILISATEUR
// ============================================================================
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    print('🔍 Vérification du rôle de l\'utilisateur...');
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    
    if (user != null) {
      print('👤 User ID: ${user.id}');
      try {
        // Récupérer le rôle depuis la table users
        final response = await client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null) {
          final userRole = response['role'] ?? 'patient';
          print('✅ Rôle récupéré: $userRole');
          
          if (mounted) {
            setState(() {
              _role = userRole;
              _loading = false;
            });
          }
        } else {
          print('⚠️ Profil utilisateur non trouvé, rôle par défaut: patient');
          if (mounted) {
            setState(() {
              _role = 'patient';
              _loading = false;
            });
          }
        }
      } catch (e) {
        print('❌ Erreur lors de la récupération du rôle: $e');
        // En cas d'erreur, utiliser le rôle par défaut
        if (mounted) {
          setState(() {
            _role = 'patient';
            _loading = false;
          });
        }
      }
    } else {
      print('❌ Utilisateur null, redirection vers auth');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      print('⏳ Chargement du profil utilisateur...');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00897B))),
      );
    }

    // ✅ Si rôle == 'pharmacie', afficher l'interface pharmacien
    if (_role == 'pharmacie') {
      print('👨‍⚕️ Redirection vers l\'interface PHARMACIEN');
      return const PharmacistHomeScreen();
    }
    
    // ✅ Sinon, interface patient par défaut
    print('👤 Redirection vers l\'interface PATIENT');
    return const HomeScreen();
  }
}