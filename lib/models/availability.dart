class MedicineAvailability {
  final String medicineId;
  final String medicineName;
  final String? dci;
  final String? dosage;
  final String? form;
  final String pharmacyId;
  final String pharmacyName;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final int quantity;
  final double price;
  final String? expiryDate;
 double? distanceFromUser; // ✅ Déclaration du champ

  MedicineAvailability({
    required this.medicineId,
    required this.medicineName,
    this.dci,
    this.dosage,
     this.form,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.quantity,
    required this.price,
    this.expiryDate,
    this.distanceFromUser, // ✅ Ajout dans le constructeur
  });

  factory MedicineAvailability.fromMap(Map<String, dynamic> map) {
    final medicine = map['medicines'] as Map<String, dynamic>? ?? {};
    final pharmacy = map['pharmacies'] as Map<String, dynamic>? ?? {};

    return MedicineAvailability(
      medicineId: map['medicine_id'] ?? medicine['id'],
      medicineName: medicine['name'] ?? 'Inconnu',
      dci: medicine['dci'],
      dosage: medicine['dosage'],
      form: medicine['form'],
      pharmacyId: map['pharmacy_id'] ?? pharmacy['id'],
      pharmacyName: pharmacy['name'] ?? 'Pharmacie',
      address: pharmacy['address'] ?? '',
      lat: (pharmacy['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (pharmacy['lng'] as num?)?.toDouble() ?? 0.0,
      phone: pharmacy['phone'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      expiryDate: map['expiry_date'],
      distanceFromUser: null, // ✅ Initialisé à null par défaut
    );
  }


  // Helper pour convertir en double de manière sécurisée
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}