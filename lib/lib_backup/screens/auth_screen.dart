import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // ✅ FONCTION : Gestion des erreurs d'authentification
  String _getAuthErrorMessage(String error) {
    if (error.contains('email rate limit exceeded')) {
      return 'Trop de tentatives. Attendez quelques minutes ou connectez-vous directement.';
    } else if (error.contains('User already registered')) {
      return 'Cet email existe déjà. Connectez-vous plutôt.';
    } else if (error.contains('Weak password')) {
      return 'Mot de passe trop faible (6 caractères minimum).';
    } else if (error.contains('Invalid email')) {
      return 'Email invalide.';
    } else if (error.contains('Phone number')) {
      return 'Numéro de téléphone invalide.';
    }
    return 'Erreur: $error';
  }

  // ✅ FONCTION : Navigation vers l'écran approprié selon le rôle
  void _navigateToHome() async {
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
        if (mounted) {
          if (role == 'pharmacie') {
            // Naviguer vers l'espace pharmacien
            Navigator.of(context).pushReplacementNamed('/pharmacist-home');
          } else {
            // Naviguer vers l'espace patient
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } catch (e) {
        print('Erreur navigation: $e');
        // En cas d'erreur, naviguer vers home par défaut
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  // ✅ FONCTION : Soumission du formulaire
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
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final phone = _phoneController.text.trim();
      final fullName = _nameController.text.trim();

      if (_isLogin) {
        // 🔐 CONNEXION
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connexion réussie !'),
              backgroundColor: Colors.green,
            ),
          );
          
          // ✅ Navigation vers l'écran approprié
          _navigateToHome();
        }
      } else {
        // 📝 INSCRIPTION
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );
        
        if (response.user != null) {
          await client.from('users').insert({
            'id': response.user!.id,
            'email': email,
            'full_name': fullName,
            'phone': phone.isNotEmpty ? phone : null,
            'role': _isPharmacist ? 'pharmacie' : 'patient',
            'created_at': DateTime.now().toIso8601String(),
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Compte créé ! Vérifiez votre email.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
            setState(() => _isLogin = true);
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

            // Champ Téléphone (inscription uniquement)
            if (!_isLogin) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: 'Ex: 690 00 00 00',
                  prefixText: '+237 ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
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