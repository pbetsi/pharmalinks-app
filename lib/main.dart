import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ AJOUTÉ : Pour la localisation en français
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/patient/pharmacy_finder_screen.dart';
import 'screens/patient/patient_orders_screen.dart';
import 'screens/patient/my_orders_screen.dart';
import 'screens/order_details_screen.dart';
import 'screens/patient/prescription_scan_screen.dart';

// ✅ Firebase options
import 'firebase_options.dart';
import 'screens/pharmacist/advanced_analytics_screen.dart';

// ✅ Config Supabase
import 'config/supabase_config.dart';

// ✅ Services
import 'services/notification_service.dart';
import 'services/cart_service.dart';

// ✅ Écrans d'authentification
import 'screens/auth_screen.dart';
import 'screens/auth/register_pharmacy_screen.dart';

// ✅ Écrans principaux
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/debug/debug_screen.dart';

// ✅ Écrans Pharmacien
import 'screens/pharmacist/pharmacist_home.dart';
import 'screens/pharmacist/orders_screen.dart';
import 'screens/pharmacist/pharmacist_chat_screen.dart';

// ✅ Écrans Patient
import 'screens/patient/patient_home.dart';
import 'screens/patient/prescriptions_screen.dart';
import 'screens/patient/search_history_screen.dart';
import 'screens/patient/conversations_screen.dart';
import 'screens/patient/contact_pharmacy_screen.dart';
import 'screens/patient/patient_notifications_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/pharmacy_details_screen.dart';
import 'screens/pharmacist/prescriptions_screen.dart';

// ✅ Écrans Admin
import 'screens/admin/admin_pharmacies_screen.dart';

// ✅ Écrans Notifications & Chat
import 'screens/notifications/notifications_screen.dart';
import 'screens/chat/chat_screen.dart';

// ============================================================================
// 🔔 INITIALISATION DES NOTIFICATIONS LOCALES (awesome_notifications)
// ============================================================================
Future<void> initLocalNotifications() async {
  try {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'pharmalink_channel',
          channelName: 'Pharmalink Africa',
          channelDescription: 'Notifications de réservations et messages',
          defaultColor: const Color(0xFF00897B),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: true,
    );
    
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    
    print('✅ Notifications locales initialisées avec awesome_notifications');
  } catch (e) {
    print('❌ Erreur initialisation notifications locales: $e');
  }
}

// ============================================================================
// 🔔 AFFICHER UNE NOTIFICATION DE RÉSERVATION
// ============================================================================
Future<void> showReservationNotification({
  required String title,
  required String body,
  String? pharmacyName,
}) async {
  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'pharmalink_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: {'pharmacy': pharmacyName, 'type': 'reservation'},
      ),
    );
    print('🔔 Notification affichée: $title');
  } catch (e) {
    print('❌ Erreur affichage notification: $e');
  }
}

// ============================================================================
// 🚀 POINT D'ENTRÉE PRINCIPAL
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Charger les variables d'environnement (compatible Web + Mobile)
  String? groqApiKey;
  
  if (kIsWeb) {
    groqApiKey = const String.fromEnvironment('GROQ_API_KEY');
    if (groqApiKey != null && groqApiKey.isNotEmpty) {
      print('✅ Clé API chargée depuis --dart-define (Web)');
    }
  } else {
    try {
      await dotenv.load(fileName: ".env");
      groqApiKey = dotenv.env['GROQ_API_KEY'];
      print('✅ Variables d\'environnement chargées depuis .env (Mobile)');
    } catch (e) {
      print('⚠️ .env non trouvé ou erreur de chargement: $e');
    }
  }

  if (groqApiKey == null || groqApiKey.isEmpty) {
    print('⚠️ Clé API GROQ non configurée - mode démo activé pour l\'IA');
  } else {
    print('✅ Clé API GROQ configurée et prête');
  }

  try {
    // 1️⃣ Initialiser Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: true,
    );
    print('✅ Supabase initialisé avec succès !');
    print('🔗 URL: ${SupabaseConfig.url}');

    // 2️⃣ Initialiser Firebase UNIQUEMENT si ce n'est pas le web
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialisé');
        await NotificationService().init();
        print('✅ Notifications push (Firebase) initialisées !');
      } catch (e) {
        print('⚠️ Firebase non initialisé: $e');
      }
    } else {
      print('ℹ️ Web détecté - Firebase skipé (utilisez Supabase Realtime)');
    }
    
    // 3️⃣ Initialiser les notifications locales
    await initLocalNotifications();
    
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
  }

  // ✅ WRAPPER AVEC PROVIDER POUR LE PANIER
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartService(),
      child: const PharmalinkApp(),
    ),
  );
}

// ============================================================================
// 🎨 WIDGET RACINE DE L'APPLICATION - ✅ LOCALISATION FRANÇAISE AJOUTÉE
// ============================================================================
class PharmalinkApp extends StatelessWidget {
  const PharmalinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmalink Africa',
      debugShowCheckedModeBanner: false,
      
      // ✅ Changez en anglais (plus stable)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),  // ✅ Anglais au lieu de français
      ],
      locale: const Locale('en', 'US'),

      // ... reste du code inchangé

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
        // ✅ DatePicker en français
        datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: Colors.teal,
          headerForegroundColor: Colors.white,
          weekdayStyle: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
          dayStyle: TextStyle(color: Colors.grey[800]),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.teal;
            return Colors.teal.withOpacity(0.1);
          }),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return Colors.teal;
          }),
        ),
      ),

      // ✅ ROUTES NOMMÉES - Toutes les routes organisées
      initialRoute: '/',
      routes: {
        '/analytics': (context) => const AdvancedAnalyticsScreen(),
        '/prescriptions-pharmacist': (context) => const PharmacistPrescriptionsScreen(),
        '/prescription-scan': (context) => const PrescriptionScanScreen(),
        '/pharmacy-finder': (context) => const PharmacyFinderScreen(),
        '/patient-orders': (context) => const PatientOrdersScreen(),
        '/order-details': (context) => const OrderDetailsScreen(),
        '/my-orders': (context) => const MyOrdersScreen(),
        
        // 🔐 Authentification
        '/': (context) => const AuthWrapper(),
        '/auth': (context) => const AuthScreen(),
        '/register-pharmacy': (context) => const RegisterPharmacyScreen(),

        // 🏠 Écrans principaux
        '/home': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/debug': (context) => const DebugScreen(),
        
        // 👨‍⚕️ Pharmacien
        '/pharmacist-home': (context) => const PharmacistHomeScreen(),
        '/orders': (context) => const OrdersScreen(),
       
        // 👤 Patient
        '/patient-home': (context) => const PatientHomeScreen(),
        '/prescriptions': (context) => const PrescriptionsScreen(),
        '/search-history': (context) => const SearchHistoryScreen(),

        // 🔒 CONVERSATIONS - Protégé contre les pharmaciens
        '/conversations': (context) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            return FutureBuilder(
              future: Supabase.instance.client
                  .from('users')
                  .select('role')
                  .eq('id', user.id)
                  .single(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator(color: Colors.teal)),
                  );
                }
                
                if (snapshot.hasData && snapshot.data!['role'] == 'pharmacist') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacementNamed(context, '/pharmacist-home');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Espace réservé aux patients'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  });
                  return const Scaffold(body: SizedBox());
                }
                
                return const ConversationsScreen();
              },
            );
          }
          return const AuthScreen();
        },
        
        '/contact-pharmacy': (context) => const ContactPharmacyScreen(),
        '/patient-notifications': (context) => const PatientNotificationsScreen(),
        
        // 🛒 Panier & Commande
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        
        // 🏥 Détails Pharmacie
        '/pharmacy-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return PharmacyDetailsScreen(
            pharmacyId: args?['pharmacyId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? 'Pharmacie',
            medicine: args?['medicine'],
            currentPosition: args?['currentPosition'],
          );
        },
        
        // 💬 Chat Patient (avec arguments)
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ChatScreen(
            conversationId: args?['conversationId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? 'Pharmacie',
            medicineName: args?['medicineName'] ?? 'Discussion',
          );
        },
        
        // 💬 Chat Pharmacien (route dédiée pour les notifications)
        '/pharmacist-chat': (context) {
          print('📍 Route /pharmacist-chat appelée');
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          
          print('📦 Arguments reçus: $args');
          
          if (args == null) {
            print('❌ Arguments null!');
            return const Scaffold(
              body: Center(child: Text('Erreur: Arguments manquants')),
            );
          }
          
          return PharmacistChatScreen(
            conversationId: args['conversationId'] ?? '',
            patientName: args['patientName'] ?? 'Patient',
            patientId: args['patientId'] ?? '',
          );
        },
        
        // 🔔 Notifications
        '/notifications': (context) => const NotificationsScreen(),
        
        // 🔐 Admin
        '/admin/pharmacies': (context) => const AdminPharmaciesScreen(),
      },

      // ✅ Gestion des routes inconnues
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        );
      },
    );
  }
}

// ============================================================================
// 🔀 WRAPPER D'AUTHENTIFICATION - Gère la connexion/déconnexion
// ============================================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                '❌ Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserRole(session.user.id),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00897B)),
                  ),
                );
              }

              final userData = userSnapshot.data;
              final role = userData?['role'];

              if (role == 'pharmacist') {
                return const PharmacistHomeScreen();
              } else if (role == 'patient') {
                return const PatientHomeScreen();
              } else if (role == 'admin') {
                return const AdminPharmaciesScreen();
              } else {
                return const AuthScreen();
              }
            },
          );
        }

        return const AuthScreen();
      },
    );
  }

  Future<Map<String, dynamic>?> _getUserRole(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('❌ Erreur récupération rôle: $e');
      return null;
    }
  }
}

// ============================================================================
// 🔀 ANCIEN ROUTEUR BASÉ SUR LE RÔLE (gardé pour compatibilité)
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
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    
    if (user != null) {
      try {
        final response = await client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null) {
          final userRole = response['role'] ?? 'patient';
          
          if (userRole == 'pharmacist') {
            final pharmacyData = await client
                .from('pharmacies')
                .select('is_verified, is_active')
                .eq('id', user.id)
                .maybeSingle();
            
            if (pharmacyData != null && 
                pharmacyData['is_verified'] == true && 
                pharmacyData['is_active'] == true) {
              if (mounted) {
                setState(() {
                  _role = 'pharmacist';
                  _loading = false;
                });
              }
            } else {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('⏳ Compte en attente'),
                    content: const Text(
                      'Votre pharmacie est en attente de validation par l\'administrateur.\n\n'
                      'Vous recevrez un email lorsque votre compte sera activé.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await client.auth.signOut();
                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/auth');
                          }
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                setState(() => _loading = false);
              }
              return;
            }
          } else {
            if (mounted) {
              setState(() {
                _role = userRole;
                _loading = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _role = 'patient';
              _loading = false;
            });
          }
        }
      } catch (e) {
        print('❌ Erreur vérification rôle: $e');
        if (mounted) {
          setState(() {
            _role = 'patient';
            _loading = false;
          });
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00897B))),
      );
    }

    if (_role == 'pharmacist') {
      return const PharmacistHomeScreen();
    }
    
    if (_role == 'admin') {
      return const AdminPharmaciesScreen();
    }
    
    return const HomeScreen();
  }
}