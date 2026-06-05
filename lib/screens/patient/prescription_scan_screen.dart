import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class PrescriptionScanScreen extends StatefulWidget {
  const PrescriptionScanScreen({super.key});

  @override
  State<PrescriptionScanScreen> createState() => _PrescriptionScanScreenState();
}

class _PrescriptionScanScreenState extends State<PrescriptionScanScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _extractedText;
  List<Map<String, dynamic>> _detectedMedicines = [];
  bool _isProcessing = false;
  String? _errorMessage; // ✅ Gestion propre de l'erreur

  Future<void> _scanPrescription() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null; // ✅ Réinitialiser l'erreur avant scan
    });

    try {
      // 🌐 Fallback Web : image_picker sur Web ouvre un sélecteur de fichiers
      final XFile? image = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1024, // Réduire taille pour Web/OCR
      );
      
      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // 📱 Mobile uniquement : OCR natif
      if (!kIsWeb) {
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = GoogleMlKit.vision.textRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        setState(() {
          _extractedText = recognizedText.text;
          _detectedMedicines = _parseMedicines(recognizedText.text);
          _isProcessing = false;
        });
        await textRecognizer.close();
      } else {
        //  Web : Simulation + Saisie manuelle (ML Kit non fiable sur Web)
        setState(() {
          _extractedText = "Mode Web détecté.\nVeuillez saisir ou coller le texte de l'ordonnance ci-dessous.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('❌ Erreur OCR: $e');
      setState(() {
        _errorMessage = "Erreur lors de l'analyse : ${e.toString().substring(0, 50)}...";
        _isProcessing = false;
      });
      
      // ✅ Afficher l'erreur temporairement (SnackBar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  List<Map<String, dynamic>> _parseMedicines(String text) {
    final commonMeds = ['paracétamol', 'amoxicilline', 'ibuprofène', 'oméprazole', 'métronidazole', 'azithromycine', 'vitamine', 'sirop'];
    final lowerText = text.toLowerCase();
    final List<Map<String, dynamic>> found = [];

    for (final med in commonMeds) {
      if (lowerText.contains(med)) {
        final quantity = RegExp(r'(\d+)\s*(boîtes?|boites?|comprimés?|x)').firstMatch(lowerText)?.group(1) ?? '1';
        found.add({
          'name': med[0].toUpperCase() + med.substring(1),
          'quantity': int.tryParse(quantity) ?? 1,
        });
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📸 Scanner Ordonnance')),
      body: Column(
        children: [
          Expanded(
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : _extractedText == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner, size: 80, color: Colors.teal),
                            const SizedBox(height: 16),
                            Text(
                              kIsWeb ? 'Importez une photo de votre ordonnance' : 'Prenez une photo de votre ordonnance',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _scanPrescription,
                              icon: Icon(kIsWeb ? Icons.upload_file : Icons.camera_alt),
                              label: Text(kIsWeb ? 'Importer une image' : 'Prendre une photo'),
                            ),
                            if (kIsWeb)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  '💡 Sur Web, l\'OCR natif est limité. Saisissez manuellement après import.',
                                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' Texte détecté / à vérifier :', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: TextField(
                                controller: TextEditingController(text: _extractedText),
                                maxLines: 5,
                                decoration: const InputDecoration(border: InputBorder.none),
                                onChanged: (val) => setState(() => _extractedText = val),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('💊 Médicaments identifiés :', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (_detectedMedicines.isEmpty)
                              Text('Aucun médicament reconnu automatiquement. Ajoutez-les manuellement.', style: TextStyle(color: Colors.grey[600])),
                            ..._detectedMedicines.map((med) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.medication, color: Colors.teal),
                                title: Text(med['name']),
                                subtitle: Text('Quantité : ${med['quantity']}'),
                                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                              ),
                            )),
                          ],
                        ),
                      ),
          ),
          // ✅ Barre d'action (remplace le message d'erreur persistant)
          if (_extractedText != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Logique d'envoi au pharmacien
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Ordonnance prête à envoyer !'), backgroundColor: Colors.green),
                        );
                      },
                      child: const Text('✅ Valider & Envoyer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() { _extractedText = null; _detectedMedicines = []; })),
                ],
              ),
            ),
        ],
      ),
    );
  }
}