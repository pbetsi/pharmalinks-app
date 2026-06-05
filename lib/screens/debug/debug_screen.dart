import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Débogage'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Outils de test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // ✅ Bouton test notifications
            ElevatedButton.icon(
              onPressed: () {
                NotificationService().sendTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔔 Notification de test envoyée')),
                );
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('🔔 Tester notification locale'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton test FCM token
            ElevatedButton.icon(
              onPressed: () async {
                final token = NotificationService().fcmToken;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(token != null 
                      ? '✅ Token: ${token.substring(0, 20)}...' 
                      : '❌ Token non disponible'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              icon: const Icon(Icons.key),
              label: const Text('🔑 Afficher token FCM'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            const Spacer(),
            
            // Info
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '💡 Conseil : Testez aussi les notifications push en envoyant un message depuis un autre compte.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}