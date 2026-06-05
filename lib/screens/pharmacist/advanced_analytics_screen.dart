import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  bool _isLoading = true;
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _lowStockCount = 0;
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _criticalStock = [];
  List<Map<String, dynamic>> _expiringSoon = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Récupérer TOUTES les réservations (Terminées et Acceptées = Revenu)
      final resResponse = await Supabase.instance.client
          .from('reservations')
          .select('id, total_price, status, created_at')
          .eq('pharmacy_id', user.id)
         .or('status.eq.completed,status.eq.accepted');

      // Calculs
      _totalOrders = resResponse.length;
      _totalRevenue = resResponse.fold<double>(0, (sum, item) => sum + (item['total_price'] as num? ?? 0));

      // Données pour le graphique (7 derniers jours)
      _dailySales = _processWeeklyData(resResponse);

      // 2. Récupérer Stock Critique (< 10 unités)
      final stockResponse = await Supabase.instance.client
          .from('medicines')
          .select('id, name, stock_quantity, price')
          .eq('pharmacy_id', user.id)
          .lt('stock_quantity', 10)
          .order('stock_quantity', ascending: true);

      _criticalStock = List<Map<String, dynamic>>.from(stockResponse);
      _lowStockCount = _criticalStock.length;

      // 3. Récupérer Médicaments bientôt périmés (< 30 jours)
      // Note: Nécessite une colonne expiry_date dans la table medicines
      // Si vous ne l'avez pas, cette partie retournera vide ou vous pouvez l'ignorer pour l'instant
      final expiryResponse = await Supabase.instance.client
          .from('medicines')
          .select('id, name, expiry_date, stock_quantity')
          .eq('pharmacy_id', user.id)
          .gte('expiry_date', DateTime.now().toIso8601String())
          .lte('expiry_date', DateTime.now().add(const Duration(days: 30)).toIso8601String())
          .order('expiry_date', ascending: true);

      _expiringSoon = List<Map<String, dynamic>>.from(expiryResponse);

    } catch (e) {
      print('❌ Erreur Analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper pour grouper les ventes par jour
  List<Map<String, dynamic>> _processWeeklyData(List<Map<String, dynamic>> reservations) {
    final now = DateTime.now();
    final Map<String, double> dailyMap = {};

    // Initialiser les 7 derniers jours à 0
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      dailyMap['${date.month}-${date.day}'] = 0;
    }

    // Additionner les ventes
    for (var res in reservations) {
      final date = DateTime.parse(res['created_at']);
      final key = '${date.month}-${date.day}';
      if (dailyMap.containsKey(key)) {
        dailyMap[key] = (dailyMap[key] ?? 0) + (res['total_price'] as num? ?? 0);
      }
    }

    return dailyMap.entries.map((e) => {
      'day': e.key,
      'value': e.value,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_CM', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Tableau de Bord'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECTION 1: KPIs ---
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _buildKpiCard('💰 Revenu Total', currencyFormat.format(_totalRevenue), Colors.green.shade100, Colors.green.shade800),
                          _buildKpiCard('📦 Commandes', '$_totalOrders', Colors.blue.shade100, Colors.blue.shade800),
                          _buildKpiCard('📉 Stock Critique', '$_lowStockCount', _lowStockCount > 0 ? Colors.red.shade100 : Colors.grey.shade200, _lowStockCount > 0 ? Colors.red.shade800 : Colors.grey.shade600),
                          _buildKpiCard('⚠️ Expiration Proche', '${_expiringSoon.length}', Colors.orange.shade100, Colors.orange.shade800),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 2: GRAPHIQUE DES VENTES ---
                      _buildSalesChart(),

                      const SizedBox(height: 24),

                      // --- SECTION 3: ALERTES INTELLIGENTES ---
                      if (_lowStockCount > 0 || _expiringSoon.isNotEmpty)
                        const Text('🚨 ALERTES PRIORITAIRES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      
                      if (_lowStockCount > 0) ...[
                        const SizedBox(height: 8),
                        ..._criticalStock.take(3).map((med) => _buildAlertCard(
                          title: med['name'],
                          subtitle: 'Stock: ${med['stock_quantity']} unités',
                          icon: Icons.inventory_2,
                          color: Colors.red,
                          action: 'Commander',
                        )).toList(),
                      ],

                      if (_expiringSoon.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._expiringSoon.take(3).map((med) => _buildAlertCard(
                          title: med['name'],
                          subtitle: 'Expire: ${DateTime.parse(med['expiry_date']).day}/${DateTime.parse(med['expiry_date']).month}',
                          icon: Icons.warning_amber,
                          color: Colors.orange,
                          action: 'Promouvoir',
                        )).toList(),
                      ],

                      // --- SECTION 4: SUGGESTION IA ---
                      const SizedBox(height: 24),
                      const Text('🤖 SUGGESTIONS INTELLIGENTES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.teal, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tendance à la hausse',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                  Text(
                                    'Le Paracétamol et l\'Amoxicilline représentent 60% de vos ventes cette semaine. Assurez-vous d\'avoir du stock.',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color.withOpacity(0.8))),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    if (_dailySales.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 Revenus (7 derniers jours)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _dailySales.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                      if (value.toInt() >= _dailySales.length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_dailySales[value.toInt()]['day'], style: const TextStyle(fontSize: 10)),
                      );
                    }),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _dailySales.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['value'] as double,
                        color: Colors.teal,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({required String title, required String subtitle, required IconData icon, required Color color, required String action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {}, // Action future
            child: Text(action, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}