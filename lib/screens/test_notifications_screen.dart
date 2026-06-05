import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestNotificationsScreen extends StatelessWidget {
  const TestNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tester Notifications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Créer une notification de test',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;

                // Créer une notification de test
                await Supabase.instance.client.from('notifications').insert({
                  'user_id': user.id,
                  'type': 'message',
                  'title': 'Test Notification',
                  'message': 'Ceci est un test de notification',
                  'data': {
                    'test': true,
                    'conversationId': 'test-123',
                  },
                  'read': false,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Notification de test créée !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notification_add),
              label: const Text('Créer une notification'),
            ),
          ],
        ),
      ),
    );
  }
}