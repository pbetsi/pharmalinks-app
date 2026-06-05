import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> medicine;
  final Map<String, dynamic>? pharmacy;
  final double? distance;

  const MedicineDetailScreen({
    super.key,
    required this.medicine,
    this.pharmacy,
    this.distance,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  int _quantity = 1;
  int _maxStock = 10;

  @override
  void initState() {
    super.initState();
    _maxStock = widget.medicine['stock_quantity'] ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.medicine;
    final pharmacy = widget.pharmacy;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ✅ HEADER AVEC IMAGE
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: medicine['image_url'] != null
                  ? Image.network(
                      medicine['image_url'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.medication, size: 64, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.medication, size: 64, color: Colors.grey),
                    ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: Colors.black),
                ),
                onPressed: () {
                  // TODO: Partager
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom et Pharmacie
                  Text(
                    medicine['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.local_pharmacy, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        pharmacy?['name'] ?? 'Pharmacie',
                        style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
                      ),
                      if (widget.distance != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me, size: 16, color: Colors.grey),
                        Text('${widget.distance!.toStringAsFixed(1)} km'),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Prix
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${medicine['price']} FCFA',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Stock: ${medicine['stock_quantity']}',
                          style: TextStyle(
                            color: medicine['stock_quantity'] > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Détails
                  _buildDetailSection('Dosage & Forme', [
                    _buildDetailRow('Dosage', medicine['dosage'] ?? 'Non spécifié'),
                    _buildDetailRow('Forme', medicine['form'] ?? 'Non spécifié'),
                  ]),
                  
                  _buildDetailSection('Description', [
                    Text(
                      medicine['description'] ?? 'Aucune description disponible',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ]),
                  
                  if (medicine['manufacturer'] != null)
                    _buildDetailSection('Fabricant', [
                      _buildDetailRow('Laboratoire', medicine['manufacturer']),
                    ]),
                  
                  if (medicine['lot_number'] != null)
                    _buildDetailSection('Informations supplémentaires', [
                      _buildDetailRow('N° Lot', medicine['lot_number']),
                      if (medicine['expiry_date'] != null)
                        _buildDetailRow(
                          'Date d\'expiration',
                          DateTime.parse(medicine['expiry_date']).toLocal().toString().split(' ')[0],
                        ),
                    ]),
                  
                  if (medicine['requires_prescription'] == true)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ce médicament nécessite une ordonnance médicale',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Sélection quantité
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quantité',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.teal),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _quantity < _maxStock ? () => setState(() => _quantity++) : null,
                            ),
                            const Spacer(),
                            Text(
                              'Total: ${medicine['price'] * _quantity} FCFA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100), // Espace pour la barre fixe
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ✅ BARRE D'ACTION FIXE EN BAS
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Contacter la pharmacie
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contacter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Ajouter au panier
                  _addToCart();
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text('Ajouter au panier ($_quantity)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart() {
    // TODO: Ajouter au panier avec la quantité sélectionnée
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${widget.medicine['name']} x$_quantity ajouté au panier'),
        backgroundColor: Colors.green,
      ),
    );
  }
}