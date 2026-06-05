import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ CHEMIN RELATIF CORRECT (sans ../)
import 'pharmacist/pharmacist_home.dart';
import 'patient/patient_home.dart';
import 'admin/admin_pharmacies_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPharmacist = false;
  
  // ✅ NOUVEAU : Sélecteur de pays pour l'indicatif téléphonique
  String _selectedCountryCode = '+237'; // Cameroun par défaut
  
  // ✅ Liste des pays africains avec leurs indicatifs
  final List<Map<String, String>> _africanCountries = [
    {'name': 'Cameroun', 'code': '+237', 'flag': '🇨'},
    {'name': 'Côte d\'Ivoire', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Sénégal', 'code': '+221', 'flag': '🇸'},
    {'name': 'Mali', 'code': '+223', 'flag': '🇲'},
    {'name': 'Burkina Faso', 'code': '+226', 'flag': '🇧🇫'},
    {'name': 'Niger', 'code': '+227', 'flag': '🇳🇪'},
    {'name': 'Togo', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Bénin', 'code': '+229', 'flag': '🇧'},
    {'name': 'Guinée', 'code': '+224', 'flag': '🇬'},
    {'name': 'Guinée-Bissau', 'code': '+245', 'flag': '🇬🇼'},
    {'name': 'Cap-Vert', 'code': '+238', 'flag': '🇨'},
    {'name': 'Gambie', 'code': '+220', 'flag': '🇬🇲'},
    {'name': 'Sierra Leone', 'code': '+232', 'flag': '🇸🇱'},
    {'name': 'Libéria', 'code': '+231', 'flag': '🇱🇷'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳'},
    {'name': 'Tchad', 'code': '+235', 'flag': '🇹🇩'},
    {'name': 'RCA', 'code': '+236', 'flag': '🇨🇫'},
    {'name': 'Gabon', 'code': '+241', 'flag': '🇬🇦'},
    {'name': 'Congo', 'code': '+242', 'flag': '🇨🇬'},
    {'name': 'RDC', 'code': '+243', 'flag': '🇨🇩'},
    {'name': 'Sao Tomé', 'code': '+239', 'flag': '🇸'},
    {'name': 'Angola', 'code': '+244', 'flag': '🇦'},
    {'name': 'Zambie', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'code': '+263', 'flag': '🇿'},
    {'name': 'Botswana', 'code': '+267', 'flag': '🇧'},
    {'name': 'Namibie', 'code': '+264', 'flag': '🇳🇦'},
    {'name': 'Afrique du Sud', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'Lesotho', 'code': '+266', 'flag': '🇱🇸'},
    {'name': 'Eswatini', 'code': '+268', 'flag': '🇸🇿'},
    {'name': 'Mozambique', 'code': '+258', 'flag': '🇲'},
    {'name': 'Madagascar', 'code': '+261', 'flag': '🇲'},
    {'name': 'Maurice', 'code': '+230', 'flag': '🇲🇺'},
    {'name': 'Comores', 'code': '+269', 'flag': '🇰'},
    {'name': 'Seychelles', 'code': '+248', 'flag': '🇸🇨'},
    {'name': 'Tanzanie', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰'},
    {'name': 'Ouganda', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Rwanda', 'code': '+250', 'flag': '🇷'},
    {'name': 'Burundi', 'code': '+257', 'flag': '🇧'},
    {'name': 'Éthiopie', 'code': '+251', 'flag': '🇪🇹'},
    {'name': 'Érythrée', 'code': '+291', 'flag': '🇪🇷'},
    {'name': 'Djibouti', 'code': '+253', 'flag': '🇩🇯'},
    {'name': 'Somalie', 'code': '+252', 'flag': '🇸🇴'},
    {'name': 'Soudan', 'code': '+249', 'flag': '🇸🇩'},
    {'name': 'Soudan du Sud', 'code': '+211', 'flag': '🇸'},
    {'name': 'Égypte', 'code': '+20', 'flag': '🇪'},
    {'name': 'Libye', 'code': '+218', 'flag': '🇱'},
    {'name': 'Tunisie', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'Algérie', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Maroc', 'code': '+212', 'flag': '🇲'},
    {'name': 'Mauritanie', 'code': '+222', 'flag': '🇲🇷'},
  ];

  // ✅ FONCTION : Gestion des erreurs d'authentification
  String _getAuthErrorMessage(String error) {
    if (error.contains('email rate limit exceeded') || 
        error.contains('rate limit') ||
        error.contains('429')) {
      return 'Trop de tentatives. Attendez quelques minutes ou connectez-vous directement.';
    } else if (error.contains('User already registered') || 
               error.contains('already registered')) {
      return 'Cet email existe déjà. Connectez-vous plutôt.';
    } else if (error.contains('Weak password')) {
      return 'Mot de passe trop faible (6 caractères minimum).';
    } else if (error.contains('Invalid email')) {
      return 'Email invalide.';
    } else if (error.contains('Phone number')) {
      return 'Numéro de téléphone invalide.';
    } else if (error.contains('row-level security')) {
      return 'Problème de configuration. Contactez le support.';
    }
    return 'Erreur: $error';
  }

  // ✅ FONCTION : Navigation vers l'écran approprié selon le rôle
  Future<void> _navigateToHome() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      try {
        // Récupérer le profil utilisateur depuis Supabase
        final profile = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        final role = profile?['role'] ?? 'patient';

        // Navigation selon le rôle
        if (!mounted) return;

        if (role == 'pharmacist') {  // ✅ Correction: 'pharmacist' au lieu de 'pharmacie'
          // Vérifier si la pharmacie est validée
          final pharmacyData = await Supabase.instance.client
              .from('pharmacies')
              .select('is_verified, is_active')
              .eq('id', user.id)
              .maybeSingle();

          if (pharmacyData != null && 
              pharmacyData['is_verified'] == true && 
              pharmacyData['is_active'] == true) {
            // ✅ Pharmacien validé → Espace pharmacien
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PharmacistHomeScreen()),
            );
          } else {
            // ⏳ Pharmacien non validé → Message + déconnexion
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
        } else if (role == 'patient') {
          // ✅ Patient → Espace patient
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
          );
        } else if (role == 'admin') {
          // ✅ Admin → Panel admin
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminPharmaciesScreen()),
          );
        } else {
          // Rôle inconnu → Déconnexion
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Rôle utilisateur inconnu'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Erreur navigation: $e');
        // En cas d'erreur, naviguer vers home par défaut ou déconnecter
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  // ✅ DIALOGUE DE CONFIRMATION D'ENVOI D'EMAIL
  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.email_outlined,
                  color: Colors.teal.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📧 Email envoyé !',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Un email de confirmation a été envoyé à :',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    email,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📋 Instructions :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionStep('1', 'Ouvrez votre boîte mail'),
                _buildInstructionStep('2', 'Recherchez l\'email de Pharmalink Africa'),
                _buildInstructionStep('3', 'Cliquez sur le lien de confirmation'),
                _buildInstructionStep('4', 'Vous pourrez ensuite vous connecter'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vérifiez aussi vos spams/courriers indésirables si vous ne voyez pas l\'email.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isLogin = true);
              },
              child: const Text('J\'ai compris'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.resend(
                    type: OtpType.signup,
                    email: email,
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Email de confirmation renvoyé !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Erreur: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Renvoyer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FONCTION : Soumission du formulaire (CONNEXION + INSCRIPTION)
  Future<void> _submit() async {
    // Validation des champs
    if (_emailController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez remplir tous les champs obligatoires'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isLogin) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Veuillez entrer votre nom'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_passwordController.text.trim().length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Mot de passe : 6 caractères minimum'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // ✅ Validation du numéro de téléphone
      final phoneRegex = RegExp(r'^[0-9]{8,9}$');
      if (_phoneController.text.trim().isEmpty || 
          !phoneRegex.hasMatch(_phoneController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Numéro de téléphone invalide (8-9 chiffres requis)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // ✅ COMBINER indicatif + numéro de téléphone
      final phone = _isLogin 
          ? _phoneController.text.trim()
          : '$_selectedCountryCode${_phoneController.text.trim()}';
      
      final fullName = _nameController.text.trim();

      if (_isLogin) {
        // 🔐 CONNEXION
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (response.user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connexion réussie !'),
              backgroundColor: Colors.green,
            ),
          );
          
          // ✅ Navigation intelligente selon le rôle
          await _navigateToHome();
        }
      } else {
        // 📝 INSCRIPTION
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );
        
        if (response.user != null) {
          // ✅ Correction: utiliser 'pharmacist' au lieu de 'pharmacie'
          await client.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'phone': phone.isNotEmpty ? phone : null,
            'role': _isPharmacist ? 'pharmacist' : 'patient',  // ✅ CORRECTION ICI
            'created_at': DateTime.now().toIso8601String(),
          });
          
          // ✅ AFFICHER LE DIALOGUE DE CONFIRMATION EMAIL
          if (mounted) {
            _showEmailConfirmationDialog(email);
          }
        }
      }
    } on AuthException catch (e) {
      final message = _getAuthErrorMessage(e.message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      final message = _getAuthErrorMessage(e.toString());
      if (mounted) {
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // ✅ LOGO CENTRÉ AVEC CERCLE
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  width: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Pharmalink Africa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Votre santé à portée de main',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Champ Nom complet (inscription uniquement)
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  hintText: 'Ex: Jean Dupont',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
            ],
            
            // Champ Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'exemple@email.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            
            // Champ Mot de passe
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Mot de passe *',
                hintText: '6 caractères minimum',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // ✅ CHAMP TÉLÉPHONE AVEC SÉLECTEUR DE PAYS (inscription uniquement)
            if (!_isLogin) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de pays
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Indicatif pays',
                        ),
                        items: _africanCountries.map((country) {
                          return DropdownMenuItem(
                            value: country['code'],
                            child: Text(
                              '${country['flag']} ${country['name']} (${country['code']})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value!;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Champ numéro de téléphone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone *',
                        hintText: 'Ex: 6XXXXXXXX',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Numéro à 8 ou 9 chiffres',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un numéro de téléphone';
                        }
                        // Validation simple : 8-9 chiffres
                        final phoneRegex = RegExp(r'^[0-9]{8,9}$');
                        if (!phoneRegex.hasMatch(value)) {
                          return 'Numéro invalide (8-9 chiffres requis)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Option Pharmacien (inscription uniquement)
            if (!_isLogin) ...[
              Row(
                children: [
                  Checkbox(
                    value: _isPharmacist,
                    onChanged: (val) => setState(() => _isPharmacist = val!),
                    activeColor: Colors.teal,
                  ),
                  const Text('Je suis pharmacien / gérant d\'officine'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            const SizedBox(height: 24),
            
            // Bouton principal
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _isLogin ? 'Se connecter' : 'Créer un compte',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton bascule Login/Signup
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  if (_isLogin) {
                    _nameController.clear();
                    _phoneController.clear();
                    _isPharmacist = false;
                  }
                });
              },
              child: Text(
                _isLogin 
                  ? 'Pas de compte ? Créez-en un gratuitement' 
                  : 'Déjà un compte ? Connectez-vous',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // ✅ NOUVEAU : Lien inscription pharmacien (affiché seulement en mode login)
            if (_isLogin) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register-pharmacy'),
                child: const Text(
                  '🏥 Vous êtes pharmacien ? Inscrivez votre officine',
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Footer
            Center(
              child: Text(
                'En continuant, vous acceptez nos Conditions d\'utilisation',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}