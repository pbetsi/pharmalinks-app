import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;

// ✅ IMPORT CONDITIONNEL pour l'export PDF (Web vs Mobile)
import '../../utils/pdf_export_mobile.dart'
    if (dart.library.html) '../../utils/pdf_export_web.dart' as pdf_export;

import '../../services/analytics_service.dart';
import '../../services/pdf_export_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _analyticsService = AnalyticsService();
  final _numberFormat = NumberFormat('#,##0', 'fr_FR');
  final _currencyFormat = NumberFormat('#,##0', 'fr_FR');

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _topMedicines = [];
  Map<String, int> _statusStats = {};
  List<Map<String, dynamic>> _recentActivity = [];
  
  bool _isLoading = true;
  int _selectedPeriod = 7; // 7, 30, 90 jours
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadAnalytics();
    
    // Rafraîchissement auto toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAnalytics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _analyticsService.getAnalytics(
          startDate: DateTime.now().subtract(Duration(days: _selectedPeriod)),
        ),
        _analyticsService.getDailyReservations(days: _selectedPeriod),
        _analyticsService.getTopMedicines(),
        _analyticsService.getReservationByStatus(),
        _analyticsService.getRecentActivity(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _dailyData = results[1] as List<Map<String, dynamic>>;
        _topMedicines = results[2] as List<Map<String, dynamic>>;
        _statusStats = results[3] as Map<String, int>;
        _recentActivity = results[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ FONCTION EXPORT PDF - COMPATIBLE WEB + MOBILE
Future<void> _exportToPdf() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Générer le PDF (retourne les bytes)
    final pdfBytes = await PdfExportService.generateAnalyticsPdf(
      stats: _stats,
      topMedicines: _topMedicines,
      recentActivity: _recentActivity,
    );

    // Fermer le loading
    if (mounted) Navigator.pop(context);

    // ✅ Utiliser l'import conditionnel pour exporter
    final fileName = "Pharmalink_Rapport_${DateTime.now().millisecondsSinceEpoch}.pdf";
    
    // ✅ Appel unique - la bonne version sera utilisée automatiquement
    await pdf_export.exportPdf(pdfBytes, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rapport exporté avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur export PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Tableau de Bord'),
        actions: [
          // ✅ Bouton Export PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exporter en PDF',
            onPressed: _isLoading ? null : _exportToPdf,
          ),
          
          // Sélecteur de période
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Période',
            onSelected: (period) {
              setState(() => _selectedPeriod = period);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('7 derniers jours')),
              const PopupMenuItem(value: 30, child: Text('30 derniers jours')),
              const PopupMenuItem(value: 90, child: Text('90 derniers jours')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📈 KPI Cards
                    _buildKPICards(),
                    
                    const SizedBox(height: 24),
                    
                    // 📊 Graphique réservations
                    _buildSectionTitle('Réservations par jour'),
                    _buildLineChart(),
                    
                    const SizedBox(height: 24),
                    
                    // 🥇 Top Médicaments
                    _buildSectionTitle('Top Médicaments'),
                    _buildTopMedicines(),
                    
                    const SizedBox(height: 24),
                    
                    // 📋 Statuts des réservations
                    _buildSectionTitle('Statuts des réservations'),
                    _buildStatusPieChart(),
                    
                    const SizedBox(height: 24),
                    
                    // ⏰ Activité récente
                    _buildSectionTitle('Activité récente'),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================
  // 📈 KPI CARDS
  // ============================================
  Widget _buildKPICards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          'Total Réservations',
          _numberFormat.format(_stats['total_reservations'] ?? 0),
          Icons.shopping_bag,
          Colors.blue,
        ),
        _buildKPICard(
          'Revenu Total',
          '${_currencyFormat.format(_stats['total_revenue'] ?? 0)} FCFA',
          Icons.attach_money,
          Colors.green,
        ),
        _buildKPICard(
  'Clients Uniques',
  _numberFormat.format(_stats['unique_customers'] ?? 0),
  Icons.people,  // ← LIGNE 247 : IconData compatible ✅
  Colors.orange,
),
        _buildKPICard(
          'Panier Moyen',
          '${_currencyFormat.format(_stats['avg_order_value'] ?? 0)} FCFA',
          Icons.shopping_cart,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // 📊 GRAPHIQUE LINÉAIRE (Réservations/jour)
  // ============================================
  Widget _buildLineChart() {
    if (_dailyData.isEmpty) {
      return _buildEmptyState('Aucune donnée disponible');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= _dailyData.length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _dailyData[value.toInt()]['day'],
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _dailyData.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value['count'].toDouble());
                  }).toList(),
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.teal.withOpacity(0.3),
                        Colors.teal.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // 🥇 TOP MÉDICAMENTS
  // ============================================
  Widget _buildTopMedicines() {
    if (_topMedicines.isEmpty) {
      return _buildEmptyState('Aucun médicament réservé');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topMedicines.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final med = _topMedicines[index];
          final rank = index + 1;
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: rank <= 3 
                  ? (rank == 1 ? Colors.amber : rank == 2 ? Colors.grey[400] : Colors.brown[300])
                  : Colors.teal.shade100,
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3 ? Colors.white : Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              med['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(med['dosage'] ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${med['total_quantity']} unités',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                Text(
                  '${med['total_reservations']} réservations',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // 📋 STATUTS (Camembert)
  // ============================================
  Widget _buildStatusPieChart() {
    final total = _statusStats.values.fold<int>(0, (sum, val) => sum + val);
    
    if (total == 0) {
      return _buildEmptyState('Aucune réservation');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 150,
                child: PieChart(
                  PieChartData(
                    sections: _statusStats.entries.where((e) => e.value > 0).map((entry) {
                      final percentage = (entry.value / total * 100).round();
                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        title: '${percentage}%\n(${_getStatusName(entry.key)})',
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        color: _getStatusColor(entry.key),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _statusStats.entries.where((e) => e.value > 0).map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getStatusColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusName(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ⏰ ACTIVITÉ RÉCENTE
  // ============================================
  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return _buildEmptyState('Aucune activité récente');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivity.length > 5 ? 5 : _recentActivity.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = _recentActivity[index];
          final user = activity['users'] as Map<String, dynamic>;
          final medicine = activity['medicines'] as Map<String, dynamic>;
          final time = DateTime.parse(activity['created_at']).toLocal();
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(activity['status']),
              child: Icon(
                _getStatusIcon(activity['status']),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(medicine['name']),
            subtitle: Text(
              '${user['full_name']} • ${DateFormat('dd/MM HH:mm').format(time)}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${activity['quantity']} unités',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(activity['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusName(activity['status']),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getStatusColor(activity['status']),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // UTILITAIRES
  // ============================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}