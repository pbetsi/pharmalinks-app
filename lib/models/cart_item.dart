class CartItem {
  final String medicineId;
  final String pharmacyId;
  final String medicineName;
  final String pharmacyName;
  final String dosage;
  final String form;
  final double price;
  int quantity;
  final double totalPrice;
  final String? notes;

  CartItem({
    required this.medicineId,
    required this.pharmacyId,
    required this.medicineName,
    required this.pharmacyName,
    required this.dosage,
    required this.form,
    required this.price,
    this.quantity = 1,
    required this.totalPrice,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'pharmacyId': pharmacyId,
      'medicineName': medicineName,
      'pharmacyName': pharmacyName,
      'dosage': dosage,
      'form': form,
      'price': price,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'notes': notes,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      medicineId: map['medicineId'],
      pharmacyId: map['pharmacyId'],
      medicineName: map['medicineName'],
      pharmacyName: map['pharmacyName'],
      dosage: map['dosage'],
      form: map['form'],
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] ?? 1,
      totalPrice: (map['totalPrice'] as num).toDouble(),
      notes: map['notes'],
    );
  }
}