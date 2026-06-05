import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  List<Map<String, dynamic>> _myConversations = [];
  bool _isLoading = true;
  bool _isCheckingRole = true;
  bool _isPharmacist = false;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // ✅ CORRECTION : Utiliser addPostFrameCallback pour éviter l'erreur
    // ModalRoute.of(context) ne peut pas être appelé dans initState() directement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserRole();
    });
    
    _searchController.addListener(() {
      _filterPharmacies();
    });
  }

  // ✅ VÉRIFIER LE RÔLE DE L'UTILISATEUR
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
        return;
      }

      final userData = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      final role = userData['role'];

      if (role == 'pharmacist') {
        // ✅ NE PAS REDIRIGER SI C'EST UNE NOTIFICATION
        // ModalRoute.of(context) est maintenant sûr car appelé après initState()
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null && args is Map && args['fromNotification'] == true) {
          // Laisser passer pour traiter la notification
          print('ℹ️ Pharmacien accède via notification - Accès autorisé');
          setState(() {
            _isCheckingRole = false;
            _isLoading = false;
          });
        } else {
          // Rediriger sinon
          print('⚠️ Pharmacien détecté - Redirection vers espace pharmacien');
          setState(() {
            _isPharmacist = true;
            _isCheckingRole = false;
          });
          
          if (mounted) {
            // ✅ addPostFrameCallback déjà géré par l'appelant, pas besoin de le répéter ici
            Navigator.pushReplacementNamed(context, '/pharmacist-home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Espace réservé aux patients. Redirection vers votre espace pharmacien...'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        setState(() {
          _isCheckingRole = false;
        });
        // Charger les données pour les patients
        _loadData();
      }
    } catch (e) {
      print('❌ Erreur vérification rôle: $e');
      setState(() => _isCheckingRole = false);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Charger toutes les pharmacies actives et validées
      final pharmaciesResponse = await Supabase.instance.client
          .from('pharmacies')
          .select('*')
          .eq('is_active', true)
          .eq('is_verified', true)
          .order('name', ascending: true);

      // Charger mes conversations existantes
      final conversationsResponse = await Supabase.instance.client
          .from('conversations')
          .select('''
            id,
            pharmacy_id,
            created_at,
            pharmacies (
              id,
              name,
              address,
              city,
              phone
            ),
            messages (
              content,
              created_at,
              read
            )
          ''')
          .eq('patient_id', user.id)
          .order('updated_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _pharmacies = List<Map<String, dynamic>>.from(pharmaciesResponse);
        _filteredPharmacies = _pharmacies;
        _myConversations = List<Map<String, dynamic>>.from(conversationsResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPharmacies() {
    if (!mounted) return;
    
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPharmacies = _pharmacies.where((pharmacy) {
        final name = (pharmacy['name'] ?? '').toLowerCase();
        final city = (pharmacy['city'] ?? '').toLowerCase();
        return name.contains(query) || city.contains(query);
      }).toList();
    });
  }

  Future<void> _startConversation(Map<String, dynamic> pharmacy) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final existingConv = _myConversations.firstWhere(
        (conv) => conv['pharmacy_id'] == pharmacy['id'],
        orElse: () => {},
      );

      String conversationId;

      if (existingConv.isNotEmpty) {
        conversationId = existingConv['id'];
      } else {
        final newConv = await Supabase.instance.client
            .from('conversations')
            .insert({
              'patient_id': user.id,
              'pharmacy_id': pharmacy['id'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        conversationId = newConv['id'];
        await _loadData();
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'pharmacyName': pharmacy['name'],
            'medicineName': 'Discussion',
          },
        );
      }
    } catch (e) {
      print('❌ Erreur création conversation: $e');
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

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Supprimer la discussion ?'),
        content: const Text(
          'Cette action supprimera tous les messages de cette conversation. Êtes-vous sûr ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Supprimer d'abord les messages
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('conversation_id', conversation['id']);

        // Puis supprimer la conversation
        await Supabase.instance.client
            .from('conversations')
            .delete()
            .eq('id', conversation['id']);

        if (mounted) {
          await _loadData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Discussion supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
      }
    }
  }

  void _openExistingConversation(Map<String, dynamic> conversation) {
    if (!mounted) return;
    
    final pharmacy = conversation['pharmacies'] as Map<String, dynamic>?;
    if (pharmacy == null) return;

    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': conversation['id'],
        'pharmacyName': pharmacy['name'] ?? 'Pharmacie',
        'medicineName': 'Discussion',
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un chargement pendant la vérification du rôle
    if (_isCheckingRole) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    // Si pharmacien (et pas via notification), afficher un message d'attente avant redirection
    if (_isPharmacist) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Accès réservé aux patients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Redirection en cours...'),
            ],
          ),
        ),
      );
    }

    // ✅ CONTENU NORMAL DE L'ÉCRAN (pour les patients uniquement)
    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Discussions'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pharmacies Disponibles'),
            Tab(text: 'Mes Discussions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPharmaciesList(),
                _buildMyConversations(),
              ],
            ),
    );
  }

  Widget _buildPharmaciesList() {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une pharmacie...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterPharmacies();
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Liste des pharmacies
        Expanded(
          child: _filteredPharmacies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_pharmacy_outlined,
                        size: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Aucune pharmacie disponible'
                            : 'Aucun résultat trouvé',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredPharmacies.length,
                  itemBuilder: (context, index) {
                    final pharmacy = _filteredPharmacies[index];
                    final hasConversation = _myConversations.any(
                      (conv) => conv['pharmacy_id'] == pharmacy['id'],
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasConversation ? Colors.green : Colors.teal,
                          child: Icon(
                            Icons.local_pharmacy,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          pharmacy['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pharmacy['address'] != null && pharmacy['address'].isNotEmpty)
                              Text(pharmacy['address']),
                            if (pharmacy['city'] != null && pharmacy['city'].isNotEmpty)
                              Text(pharmacy['city']),
                            if (pharmacy['phone'] != null && pharmacy['phone'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(pharmacy['phone']),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: hasConversation
                            ? const Icon(Icons.chat, color: Colors.green)
                            : ElevatedButton(
                                onPressed: () => _startConversation(pharmacy),
                                child: const Text('Contacter'),
                              ),
                        onTap: () => _startConversation(pharmacy),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMyConversations() {
    if (_myConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Aucune discussion',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cliquez sur "Contacter" pour commencer',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myConversations.length,
      itemBuilder: (context, index) {
        final conversation = _myConversations[index];
        final pharmacy = conversation['pharmacies'] as Map<String, dynamic>?;
        final lastMessage = conversation['messages']?.isNotEmpty == true
            ? conversation['messages'][0]
            : null;
        final hasUnread = lastMessage != null && lastMessage['read'] == false;

        if (pharmacy == null) return const SizedBox.shrink();

        return Dismissible(
          key: Key(conversation['id']),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (!mounted) return false;
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('🗑️ Supprimer la discussion ?'),
                content: const Text('Cette action est irréversible.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            if (mounted) {
              _deleteConversation(conversation);
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal,
                child: const Icon(Icons.local_pharmacy, color: Colors.white),
              ),
              title: Text(
                pharmacy['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasUnread ? Colors.teal : Colors.black,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lastMessage != null)
                    Text(
                      lastMessage['content'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? Colors.teal : Colors.grey[600],
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  Text(
                    'Cliquez pour discuter',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUnread)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showConversationOptions(conversation),
                  ),
                ],
              ),
              onTap: () => _openExistingConversation(conversation),
            ),
          ),
        );
      },
    );
  }

  void _showConversationOptions(Map<String, dynamic> conversation) {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer la discussion'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteConversation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }
}