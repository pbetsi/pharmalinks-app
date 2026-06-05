import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({super.key});

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  List<Map<String, dynamic>> _searchHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('search_history')
          .select('*')
          .eq('user_id', user.id)
          .order('searched_at', ascending: false)
          .limit(50);

      setState(() {
        _searchHistory = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Effacer l\'historique'),
        content: const Text('Êtes-vous sûr de vouloir effacer tout l\'historique ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('search_history')
              .delete()
              .eq('user_id', user.id);
          _loadSearchHistory();
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
      }
    }
  }

  Future<void> _searchAgain(String medicineName) async {
    // Naviguer vers l'écran de recherche avec le médicament
    // Vous devrez peut-être adapter selon votre structure
    Navigator.pop(context, medicineName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🕐 Historique des Recherches'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_searchHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
              tooltip: 'Effacer l\'historique',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 100, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun historique',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vos recherches récentes apparaîtront ici',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchHistory.length,
                  itemBuilder: (context, index) {
                    final search = _searchHistory[index];
                    final searchedAt = DateTime.parse(search['searched_at']);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: const Icon(Icons.search, color: Colors.teal),
                        ),
                        title: Text(
                          search['medicine_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          searchedAt.toString().substring(0, 16),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _searchAgain(search['medicine_name']),
                          tooltip: 'Rechercher à nouveau',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}