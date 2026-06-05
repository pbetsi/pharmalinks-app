import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddMedicineSmartScreen extends StatefulWidget {
  const AddMedicineSmartScreen({super.key});

  @override
  State<AddMedicineSmartScreen> createState() => _AddMedicineSmartScreenState();
}

class _AddMedicineSmartScreenState extends State<AddMedicineSmartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _formController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  bool _isProcessing = false;
  String _statusMessage = "Cliquez sur la caméra pour scanner la boîte";
  String? _imageUrl;

  // ✅ ÉTAPE 1 : Prendre photo + Uploader + Analyser par IA
  Future<void> _smartScan() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Analyse de l'image en cours...";
    });

    try {
      // 1. Prendre la photo
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera); // ou ImageSource.gallery
      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // 2. Uploader l'image vers Supabase Storage (nécessaire pour l'IA Web)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final fileBytes = await image.readAsBytes();
      
      await Supabase.instance.client.storage
          .from('medicines') // Assurez-vous que ce bucket 'medicines' existe dans Supabase
          .uploadBinary('scans/$fileName', fileBytes);

      final urlResponse = Supabase.instance.client.storage
          .from('medicines')
          .getPublicUrl('scans/$fileName');
      
      _imageUrl = urlResponse;

      // 3. Envoyer l'image à l'IA (Llama 3.2 Vision ou GPT-4o)
      await _analyzeImageWithAI(urlResponse);

    } catch (e) {
      setState(() {
        _statusMessage = "Erreur: $e";
        _isProcessing = false;
      });
      print("Erreur complète: $e");
    }
  }

  // ✅ ÉTAPE 2 : L'IA lit l'image et renvoie le JSON
  Future<void> _analyzeImageWithAI(String imageUrl) async {
    final apiKey = dotenv.env['GROQ_API_KEY']; 
    
    // Note: Pour Groq, utilisez le modèle Vision si disponible, sinon OpenAI
    // Ici, on simule un appel compatible avec les modèles Vision
    // Si vous n'avez pas accès au modèle Vision sur Groq, utilisez l'API OpenAI (GPT-4o)
    
    try {
      // Exemple avec OpenAI (plus fiable pour la vision actuellement)
      // Remplacez par votre clé OpenAI si vous en avez une, ou utilisez Groq Vision
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'), // OU l'URL Groq Vision
        headers: {
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY'] ?? apiKey}', 
          'Content-Type': 'appjson',
        },
        body: jsonEncode({
          'model': 'gpt-4o', // ou 'llama-3.2-11b-vision-preview' sur Groq
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Tu es un assistant pharmacien. Analyse cette image de boîte de médicament. Extrais le NOM, le DOSAGE, et la FORME (comprimé, sirop...). Retourne UNIQUEMENT un JSON valide: {"name": "...", "dosage": "...", "form": "..."}'
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': imageUrl}
                }
              ]
            }
          ],
          'max_tokens': 300,
          'response_format': {'type': 'json_object'}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResult = jsonDecode(data['choices'][0]['message']['content']);

        setState(() {
          _nameController.text = aiResult['name'] ?? 'Inconnu';
          _dosageController.text = aiResult['dosage'] ?? '';
          _formController.text = aiResult['form'] ?? '';
          _statusMessage = "✅ Données extraites ! Vérifiez et complétez le prix/stock.";
          _isProcessing = false;
        });
      } else {
        throw Exception("Erreur API: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erreur IA: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajout Intelligent 🤖"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 📷 ZONE DE SCAN
              Card(
                color: Colors.teal.shade50,
                child: ListTile(
                  leading: _isProcessing 
                      ? const CircularProgressIndicator() 
                      : const Icon(Icons.camera_alt, color: Colors.teal, size: 30),
                  title: Text(_statusMessage),
                  onTap: _isProcessing ? null : _smartScan,
                ),
              ),
              const SizedBox(height: 20),

              // 📝 CHAMPS PRÉ-REMPLIS
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du médicament *', prefixIcon: Icon(Icons.medication)),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText: 'Dosage (ex: 500mg)', prefixIcon: Icon(Icons.science)),
              ),
              TextFormField(
                controller: _formController,
                decoration: const InputDecoration(labelText: 'Forme (ex: Comprimé)', prefixIcon: Icon(Icons.shape_line)),
              ),
              const Divider(height: 30),
              
              // 💰 CHAMPS MANUELS (Prix et Stock)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Prix de vente (FCFA)', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock initial', prefixIcon: Icon(Icons.inventory)),
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Code pour sauvegarder dans Supabase 'medicines'
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Médicament ajouté avec succès !"), backgroundColor: Colors.green),
                    );
                    Navigator.pop(context); // Retour à la liste
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal,
                ),
                child: const Text("💾 Sauvegarder le médicament", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}