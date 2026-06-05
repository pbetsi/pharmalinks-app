import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PharmacyWorkingHoursWidget extends StatefulWidget {
  final String pharmacyId;

  const PharmacyWorkingHoursWidget({
    super.key,
    required this.pharmacyId,
  });

  @override
  State<PharmacyWorkingHoursWidget> createState() => _PharmacyWorkingHoursWidgetState();
}

class _PharmacyWorkingHoursWidgetState extends State<PharmacyWorkingHoursWidget> {
  List<Map<String, dynamic>> _workingHours = [];
  bool _isLoading = true;
  bool _isOpenNow = false;

  @override
  void initState() {
    super.initState();
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    try {
      final response = await Supabase.instance.client
          .from('pharmacy_working_hours')
          .select('*')
          .eq('pharmacy_id', widget.pharmacyId)
          .order('day_of_week');

      setState(() {
        _workingHours = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
        _checkIfOpenNow();
      });
    } catch (e) {
      print('❌ Erreur chargement horaires: $e');
      setState(() => _isLoading = false);
    }
  }

    void _checkIfOpenNow() {
    final now = DateTime.now();
    final currentDay = now.weekday % 7; // 0=Dimanche, 1=Lundi, etc.
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    // ✅ CORRECTION 1 : Utiliser .where() pour éviter l'erreur de type sur firstWhere
    final todayHoursList = _workingHours.where((h) => 
      h['day_of_week'] == currentDay && h['is_open'] == true
    ).toList();

    if (todayHoursList.isNotEmpty) {
      final todayHours = todayHoursList.first;
      
      // ✅ CORRECTION 2 : Parser manuellement l'heure car TimeOfDay.parse() n'existe pas
      // Supabase renvoie souvent "08:00:00", on split par ":"
      final openingParts = todayHours['opening_time'].toString().split(':');
      final closingParts = todayHours['closing_time'].toString().split(':');
      
      final openingTime = TimeOfDay(
        hour: int.parse(openingParts[0]), 
        minute: int.parse(openingParts[1])
      );
      
      final closingTime = TimeOfDay(
        hour: int.parse(closingParts[0]), 
        minute: int.parse(closingParts[1])
      );

      setState(() {
        // Vérification précise (conversion en minutes pour comparer)
        final currentMinutes = currentTime.hour * 60 + currentTime.minute;
        final openMinutes = openingTime.hour * 60 + openingTime.minute;
        final closeMinutes = closingTime.hour * 60 + closingTime.minute;
        
        _isOpenNow = currentMinutes >= openMinutes && currentMinutes < closeMinutes;
      });
    } else {
      setState(() {
        _isOpenNow = false;
      });
    }
  }

  String _getDayName(int dayIndex) {
    const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    return days[dayIndex];
  }

  String _getFullDayName(int dayIndex) {
    const days = [
      'Dimanche',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
    ];
    return days[dayIndex];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isOpenNow ? Icons.check_circle : Icons.cancel,
                color: _isOpenNow ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              const Text(
                'Horaires d\'Ouverture',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOpenNow ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isOpenNow ? 'Ouvert maintenant' : 'Fermé',
                  style: TextStyle(
                    color: _isOpenNow ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_workingHours.isEmpty)
            const Text(
              'Aucun horaire disponible',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._workingHours.map((hours) {
              final isToday = hours['day_of_week'] == DateTime.now().weekday % 7;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isToday ? Colors.teal.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: Colors.teal, width: 2) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _getFullDayName(hours['day_of_week']),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? Colors.teal.shade700 : Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        hours['is_open'] == true
                            ? '${hours['opening_time']} - ${hours['closing_time']}'
                            : 'Fermé',
                        style: TextStyle(
                          color: hours['is_open'] == true 
                              ? Colors.teal.shade700 
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (isToday)
                      Icon(
                        Icons.today,
                        size: 16,
                        color: Colors.teal,
                      ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}