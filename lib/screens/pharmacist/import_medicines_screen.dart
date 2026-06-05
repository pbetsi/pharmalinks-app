import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'dart:html' as html;
class ImportMedicinesScreen extends StatefulWidget {
  const ImportMedicinesScreen({super.key});

  @override
  State<ImportMedicinesScreen> createState() => _ImportMedicinesScreenState();
}

class _ImportMedicinesScreenState extends State<ImportMedicinesScreen> {
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = "Sélectionnez un fichier CSV";
  int _totalRows = 0;
  int _processedRows = 0;
  List<String> _errors = [];

  // ✅ FORMAT ATTENDU
  final List<String> _requiredHeaders = ['name', 'dosage', 'form', 'price', 'stock'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📥 Importation de Masse (CSV)"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📖 Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📝 Format requis (CSV)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Le fichier doit contenir ces colonnes exactement :"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _requiredHeaders.map((h) => _buildHeaderChip(h)).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download),
                      label: const Text("Télécharger le modèle CSV exemple"),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue.shade800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📂 Bouton d'upload
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndImportFile,
                icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.file_upload),
                label: Text(_isProcessing ? "Traitement en cours..." : "Choisir un fichier CSV"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // 📊 Barre de progression
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              Text("$_status ($_processedRows / $_totalRows médicaments)"),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress, minHeight: 10),
            ],

            // ⚠️ Liste des erreurs
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("️ Lignes ignorées :", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _errors.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text("• Ligne ${i + 2}: ${_errors[i]}", style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.teal.shade100,
      labelStyle: TextStyle(color: Colors.teal.shade800),
    );
  }

  // ✅ TÉLÉCHARGER UN MODÈLE CSV
  Future<void> _downloadTemplate() async {
    const csvContent = "name,dosage,form,price,stock\nParacétamol,500mg,Comprimé,400,100\nAmoxicilline,250mg,Gélule,95,50\n";
    
    // Sur Web, on ouvre un lien data
    if (kIsWeb) {
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "modele_medicaments.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Sur Mobile, on sauvegarde dans le dossier téléchargements
      final dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) dir.createSync();
      File('${dir.path}/modele_medicaments.csv').writeAsStringSync(csvContent);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Modèle téléchargé"), backgroundColor: Colors.green),
      );
    }
  }

  // ✅ SÉLECTION & IMPORT
  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _status = "Lecture du fichier...";
        _errors = [];
      });

      String csvString;
      if (kIsWeb) {
        csvString = utf8.decode(result.files.single.bytes!);
      } else {
        csvString = await File(result.files.single.path!).readAsString();
      }

      final rows = const CsvToListConverter().convert(csvString);
      if (rows.isEmpty) throw Exception("Fichier vide");

      // Vérification des en-têtes
      final headers = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
      for (final req in _requiredHeaders) {
        if (!headers.contains(req)) {
          throw Exception("Colonne manquante : '$req'. Vérifiez le modèle.");
        }
      }

      // Mapping des données
      final List<Map<String, dynamic>> medicinesToInsert = [];
      _totalRows = rows.length - 1;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 5) continue;

        try {
          medicinesToInsert.add({
            'name': row[0].toString().trim(),
            'dosage': row[1].toString().trim(),
            'form': row[2].toString().trim(),
            'price': double.parse(row[3].toString()),
            'stock': int.parse(row[4].toString()),
            'pharmacy_id': Supabase.instance.client.auth.currentUser?.id,
            'created_at': DateTime.now().toIso8601String(),
          });
          _processedRows++;
          _progress = _processedRows / _totalRows;
          _status = "Préparation des données...";
        } catch (e) {
          _errors.add("Format invalide (prix/stock manquants ?)");
        }
      }

      // ✅ INSERTION PAR BLOCS (50 par requête pour éviter les timeouts)
      setState(() => _status = "Envoi vers la base de données...");
      const batchSize = 50;
      for (int i = 0; i < medicinesToInsert.length; i += batchSize) {
        final batch = medicinesToInsert.sublist(
          i,
          i + batchSize > medicinesToInsert.length ? medicinesToInsert.length : i + batchSize,
        );
        
        await Supabase.instance.client.from('medicines').insert(batch);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 1.0;
          _status = "✅ Import terminé avec succès !";
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${medicinesToInsert.length} médicaments ajoutés !"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = "❌ Erreur: ${e.toString()}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}