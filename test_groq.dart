import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  await dotenv.load();
  final key = dotenv.env['GROQ_API_KEY'];
  
  final res = await http.post(
    Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
    body: jsonEncode({
      'model': 'llama3-8b-8192',
      'messages': [{'role': 'user', 'content': 'Dis OK'}],
      'max_tokens': 5,
    }),
  );
  
  print(res.statusCode == 200 ? '✅ Clé valide !' : '❌ Erreur: ${res.body}');
}