import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Paramètres'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Notifications
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.teal),
              title: const Text('Tester les notifications push'),
              subtitle: const Text('Vérifiez que vous recevez bien les alertes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                NotificationService().sendTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 Notification de test envoyée !'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
            ),
          ),
          
          // Autres paramètres...
          const SizedBox(height: 16),
          
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter'),
              onTap: () {
                // Logique de déconnexion
              },
            ),
          ),
        ],
      ),
    );
  }
}