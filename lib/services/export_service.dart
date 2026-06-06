import 'package:csv/csv.dart';

class ExportService {
  /// Exporte une liste de médicaments en CSV
  static String exportMedicinesToCsv(List<Map<String, dynamic>> medicines) {
    // En-têtes du CSV
    final List<List<dynamic>> rows = [
      ['Nom', 'Dosage', 'Forme', 'Prix (FCFA)', 'Stock', 'Date expiration'],
    ];

    // Ajouter les données
    for (var med in medicines) {
      rows.add([
        med['name'] ?? '',
        med['dosage'] ?? '',
        med['form'] ?? '',
        med['price'] ?? '',
        med['stock_quantity'] ?? med['stock'] ?? '',
        med['expiration_date'] ?? '',
      ]);
    }

    // Convertir en CSV
    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }
}