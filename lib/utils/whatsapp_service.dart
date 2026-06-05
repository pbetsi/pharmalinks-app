import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Ouvre WhatsApp avec un message pré-rempli
  /// [phoneNumber] : Le numéro du patient (ex: "2376500000")
  /// [message] : Le message à envoyer
  static Future<void> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // 1. Nettoyer le numéro (enlever espaces, +, -)
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      // 2. Si le numéro ne commence pas par le code pays, ajouter le Cameroun (237) par défaut
      if (cleanNumber.length < 12 && !cleanNumber.startsWith('237')) {
        cleanNumber = '237$cleanNumber';
      }

      // 3. Encoder le message pour l'URL
      String encodedMessage = Uri.encodeComponent(message);
      
      // 4. Créer le lien WhatsApp
      final url = Uri.parse('https://wa.me/$cleanNumber?text=$encodedMessage');

      // 5. Lancer l'application
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        print('✅ WhatsApp ouvert vers $cleanNumber');
      } else {
        print('❌ Impossible d\'ouvrir WhatsApp');
      }
    } catch (e) {
      print('❌ Erreur WhatsApp: $e');
    }
  }
}