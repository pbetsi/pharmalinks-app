import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Export PDF pour mobile (Android/iOS)
Future<void> exportPdf(Uint8List pdfBytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    
    // Ouvrir automatiquement le fichier
    await OpenFile.open(filePath);
  } catch (e) {
    throw Exception('Erreur lors de la sauvegarde du PDF: $e');
  }
}