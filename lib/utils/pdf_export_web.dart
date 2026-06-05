import 'dart:typed_data';
import 'dart:html' as html; // ✅ dart:html UNIQUEMENT dans ce fichier web

/// Export PDF pour le Web
Future<void> exportPdf(Uint8List pdfBytes, String fileName) async {
  try {
    // Créer un Blob et télécharger
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    rethrow;
  }
}