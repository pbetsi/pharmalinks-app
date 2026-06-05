import 'dart:typed_data';  // ← IMPORTANT pour Uint8List
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
class PdfExportService {
  /// Génère le rapport Analytics complet
  static Future<Uint8List> generateAnalyticsPdf({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> topMedicines,
    required List<Map<String, dynamic>> recentActivity,
  }) async {
    // Initialiser la locale française
    await initializeDateFormatting('fr_FR', null);

    final pdf = pw.Document();
    final dateStr = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return <pw.Widget>[
            _buildHeader(dateStr),
            pw.SizedBox(height: 20),
            pw.Text('📊 Résumé des Performances',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildKPISummary(stats),
            pw.SizedBox(height: 20),
            pw.Text('🏆 Top Médicaments Vendus',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildMedicinesTable(topMedicines),
            pw.SizedBox(height: 20),
            pw.Text('⏰ Dernières Réservations',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildActivityTable(recentActivity),
          ];
        },
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Pharmalink Africa - Rapport généré le $dateStr',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ),
    );

    // Retourner les bytes du PDF (compatible web + mobile)
    return await pdf.save();
  }

  // ... (mêmes méthodes _buildHeader, _buildKPISummary, etc. qu'avant)
  
  static pw.Widget _buildHeader(String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Pharmalink Africa',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.Text('Tableau de bord Pharmacie',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal800)),
          child: pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  static pw.Widget _buildKPISummary(Map<String, dynamic> stats) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildKPICard('Réservations', '${stats['total_reservations'] ?? 0}', PdfColors.blue),
        _buildKPICard('Revenu', '${(stats['total_revenue'] ?? 0).toString()} FCFA', PdfColors.green),
        _buildKPICard('Clients', '${stats['unique_customers'] ?? 0}', PdfColors.orange),
      ],
    );
  }

  static pw.Widget _buildKPICard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
       color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 5),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicinesTable(List<Map<String, dynamic>> data) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
      },
      headers: ['Médicament', 'Qté Totale', 'Revenu'],
      data: data.map((item) {
        return [
          "${item['name']} (${item['dosage'] ?? ''})",
          "${item['total_quantity']}",
          "${item['total_revenue'] ?? 0} FCFA",
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildActivityTable(List<Map<String, dynamic>> data) {
    final limitedData = data.length > 10 ? data.sublist(0, 10) : data;
    
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellHeight: 25,
      headers: ['Date', 'Client', 'Médicament', 'Qté'],
      data: limitedData.map((item) {
        final user = item['users'] as Map<String, dynamic>?;
        final med = item['medicines'] as Map<String, dynamic>?;
        final date = DateTime.parse(item['created_at']);
        final dateStr = DateFormat('dd/MM HH:mm').format(date);

        return [
          dateStr,
          user?['full_name'] ?? 'Inconnu',
          med?['name'] ?? '-',
          "${item['quantity']}",
        ];
      }).toList(),
    );
  }
}