import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentReservations = [];
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _topMedicines = [];
  bool _isLoading = true;
  int _selectedPeriod = 7; // 7, 30, 90 jours

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

Future<void> _loadAnalytics() async {
  setState(() => _isLoading = true);

  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    print('📊 Chargement des analytics pour pharmacy_id: ${user.id}');

    // 1. Récupérer TOUTES les réservations SANS JOIN
    final statsResponse = await Supabase.instance.client
        .from('reservations')
        .select('*')  // ✅ Pas de JOIN, juste les colonnes de reservations
        .eq('pharmacy_id', user.id);

    print('📦 Réservations brutes: ${statsResponse.length}');

    // Calculer les statistiques
    int totalReservations = statsResponse.length;
    double totalRevenue = 0;
    int pendingCount = 0;
    int acceptedCount = 0;
    int completedCount = 0;
    int rejectedCount = 0;

    Map<String, int> medicineCount = {};
    Map<String, int> dailyReservations = {};
    Map<String, double> dailyRevenue = {};

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedPeriod));

    // Récupérer les noms des médicaments séparément
    List<Map<String, dynamic>> medicinesCache = [];
    try {
      final medsResponse = await Supabase.instance.client
          .from('medicines')
          .select('id, name');
      medicinesCache = List<Map<String, dynamic>>.from(medsResponse);
      print('💊 Médicaments chargés: ${medicinesCache.length}');
    } catch (e) {
      print('⚠️ Impossible de charger les médicaments: $e');
    }

    for (var res in statsResponse) {
      final createdAtStr = res['created_at'] as String?;
      if (createdAtStr == null) continue;

      final createdAt = DateTime.parse(createdAtStr);
      
      // Filtrer par période
      if (createdAt.isBefore(startDate)) continue;

      final price = (res['total_price'] as num?)?.toDouble() ?? 0;
      final status = res['status'] as String? ?? 'pending';
      final medicineId = res['medicine_id'] as String?;

      totalRevenue += price;

      // Compter par statut
      switch (status) {
        case 'pending':
          pendingCount++;
          break;
        case 'accepted':
        case 'confirmed':
          acceptedCount++;
          break;
        case 'completed':
          completedCount++;
          break;
        case 'rejected':
          rejectedCount++;
          break;
      }

      // Compter les médicaments les plus demandés
      if (medicineId != null) {
        final medicine = medicinesCache.firstWhere(
          (m) => m['id'] == medicineId,
          orElse: () => {'name': 'Inconnu'},
        );
        final medicineName = medicine['name'] ?? 'Inconnu';
        medicineCount[medicineName] = (medicineCount[medicineName] ?? 0) + 1;
      }

      // Statistiques par jour
      final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      dailyReservations[dateKey] = (dailyReservations[dateKey] ?? 0) + 1;
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + price;
    }

    // Formater les données pour le graphique
    List<Map<String, dynamic>> dailyData = [];
    for (int i = _selectedPeriod - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dayName = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][date.weekday - 1];
      
      dailyData.add({
        'day': dayName,
        'date': dateKey,
        'reservations': dailyReservations[dateKey] ?? 0,
        'revenue': dailyRevenue[dateKey] ?? 0,
      });
    }

    // Top médicaments
    List<Map<String, dynamic>> topMeds = medicineCount.entries
        .map((e) => {'name': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // 2. Réservations récentes (SANS JOIN)
    final recentResponse = await Supabase.instance.client
        .from('reservations')
        .select('*')  // ✅ Pas de JOIN
        .eq('pharmacy_id', user.id)
        .order('created_at', ascending: false)
        .limit(5);

    // Récupérer les infos patients séparément
    List<Map<String, dynamic>> recentWithDetails = [];
    for (var res in recentResponse) {
      final patientId = res['patient_id'] as String?;
      final medicineId = res['medicine_id'] as String?;
      
      Map<String, dynamic> resWithDetails = Map<String, dynamic>.from(res);
      
      // Récupérer patient
      if (patientId != null) {
        try {
          final patientData = await Supabase.instance.client
              .from('users')
              .select('email, full_name')
              .eq('id', patientId)
              .single();
          resWithDetails['patient_info'] = patientData;
        } catch (e) {
          print('⚠️ Patient non trouvé: $patientId');
        }
      }
      
      // Récupérer médicament
      if (medicineId != null) {
        try {
          final medData = await Supabase.instance.client
              .from('medicines')
              .select('name')
              .eq('id', medicineId)
              .single();
          resWithDetails['medicine_info'] = medData;
        } catch (e) {
          print('⚠️ Médicament non trouvé: $medicineId');
        }
      }
      
      recentWithDetails.add(resWithDetails);
    }

    setState(() {
      _stats = {
        'totalReservations': totalReservations,
        'totalRevenue': totalRevenue,
        'pendingCount': pendingCount,
        'acceptedCount': acceptedCount,
        'completedCount': completedCount,
        'rejectedCount': rejectedCount,
      };
      _recentReservations = recentWithDetails;
      _dailyStats = dailyData;
      _topMedicines = topMeds.take(5).toList();
      _isLoading = false;
    });

    print('✅ Analytics chargés: $totalReservations réservations, $totalRevenue FCFA');
  } catch (e) {
    print('❌ Erreur chargement analytics: $e');
    print('❌ Stack: ${StackTrace.current}');
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  Future<void> _exportPDF() async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Rapport Pharmalink Pro', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Total Réservations: ${_stats['totalReservations']}', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Revenu Total: ${_stats['totalRevenue']} FCFA', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text('Réservations récentes:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ..._recentReservations.map((res) => pw.Text('- ${res['medicines']?['name']}: ${res['total_price']} FCFA')),
              ],
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/rapport_pharmalink.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF exporté: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur export PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics, color: Colors.white),
            SizedBox(width: 8),
            Text('Tableau de Bord'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Sélecteur de période
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('7 derniers jours')),
              const PopupMenuItem(value: 30, child: Text('30 derniers jours')),
              const PopupMenuItem(value: 90, child: Text('90 derniers jours')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _isLoading ? null : _exportPDF,
            tooltip: 'Exporter PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistiques principales
                      _buildStatsCards(),
                      
                      const SizedBox(height: 24),
                      
                      // Graphique des réservations
                      _buildWeeklyChart(),
                      
                      const SizedBox(height: 24),
                      
                      // Top médicaments
                      if (_topMedicines.isNotEmpty) ...[
                        const Text(
                          '📊 Top Médicaments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTopMedicines(),
                        const SizedBox(height: 24),
                      ],
                      
                      // Réservations récentes
                      const Text(
                        '📋 Réservations Récentes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentReservations(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Réservations',
          '${_stats['totalReservations'] ?? 0}',
          Icons.shopping_bag,
          Colors.blue,
        ),
        _buildStatCard(
          'Revenu Total',
          '${(_stats['totalRevenue'] ?? 0).toStringAsFixed(0)} FCFA',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          'En Attente',
          '${_stats['pendingCount'] ?? 0}',
          Icons.pending,
          Colors.orange,
        ),
        _buildStatCard(
          'Terminées',
          '${_stats['completedCount'] ?? 0}',
          Icons.check_circle,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_dailyStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Aucune donnée disponible'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réservations par Jour (${_selectedPeriod} derniers jours)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _dailyStats
                      .map((e) => e['reservations'] as int)
                      .fold<int>(0, (max, value) => value > max ? value : max)
                      .toDouble()
                      .clamp(1, double.infinity),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} réservations',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _dailyStats.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _dailyStats[value.toInt()]['day'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: _dailyStats.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value['reservations'].toDouble(),
                          color: Colors.teal,
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMedicines() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _topMedicines.asMap().entries.map((entry) {
            final index = entry.key;
            final med = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(med['name']),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${med['count']} ventes',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentReservations() {
    if (_recentReservations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Aucune réservation récente'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentReservations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final res = _recentReservations[index];
          final medicine = res['medicines'] as Map<String, dynamic>?;
          final patient = res['users'] as Map<String, dynamic>?;
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(res['status']),
              child: Icon(
                _getStatusIcon(res['status']),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(medicine?['name'] ?? 'Médicament'),
            subtitle: Text('Patient: ${patient?['full_name'] ?? patient?['email'] ?? 'N/A'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${res['total_price']} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                Text(
                  _formatDate(res['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}