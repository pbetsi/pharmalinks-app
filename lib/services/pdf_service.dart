import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';

class PdfService {
  Future<void> exportDashboard({
    required int totalReservations,
    required double totalRevenue,
    required int pendingCount,
    required int completedCount,
    required String pharmacyName,
    required DateTime generatedAt,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Pharmalink Pro',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Tableau de Bord - $pharmacyName',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Date de génération
              pw.Text(
                'Généré le: ${_formatDate(generatedAt)}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
              ),
              
              pw.SizedBox(height: 20),
              
              // Statistiques principales
              pw.Text(
                'Statistiques Principales',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildStatBox(
                    'Total Réservations',
                    '$totalReservations',
                    PdfColors.blue,
                  ),
                  pw.SizedBox(width: 20),
                  _buildStatBox(
                    'Revenu Total',
                    '${totalRevenue.toStringAsFixed(0)} FCFA',
                    PdfColors.green,
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Row(
                children: [
                  _buildStatBox(
                    'En Attente',
                    '$pendingCount',
                    PdfColors.orange,
                  ),
                  pw.SizedBox(width: 20),
                  _buildStatBox(
                    'Terminées',
                    '$completedCount',
                    PdfColors.teal,
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Pied de page
              pw.Spacer(),
              
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Rapport généré par Pharmalink Pro',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '© ${DateTime.now().year} - Tous droits réservés',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Afficher le PDF pour impression/partage
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'tableau_de_bord_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildStatBox(String label, String value, PdfColor color) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: color, // ✅ Suppression de withOpacity
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.white, // Texte en blanc pour contraste
            ),
          ),
        ],
      ),
    ),
  );
}

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}