import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  String _result = "Scannez un produit...";
  bool _isScanning = true;

  Future<void> _searchProduct(String barcode) async {
    setState(() {
      _result = "Recherche en cours...";
      _isScanning = false;
      cameraController.stop();
    });

    try {
      final response = await Supabase.instance.client
          .from('medicines')
          .select('*')
          .eq('barcode', barcode) // Assurez-vous d'avoir une colonne 'barcode'
          .single();

      if (mounted) {
        setState(() {
          _result = "Produit trouvé: ${response['name']}";
        });
        
        // Action: Afficher le produit ou l'ajouter au panier
        _showProductDialog(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = "Produit non trouvé dans la base.";
        });
        // Optionnel: Réactiver le scanner
        // cameraController.start();
      }
    }
  }

  void _showProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Prix: ${product['price']} FCFA"),
            Text("Stock: ${product['stock']}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () {
              // Logique pour ajouter au panier de vente
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${product['name']} ajouté au panier !")),
              );
            },
            child: const Text("Vendre"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner Code-Barres")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (_isScanning && barcode.rawValue != null) {
                    _searchProduct(barcode.rawValue!);
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 48, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (!_isScanning)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isScanning = true;
                          _result = "Scannez un produit...";
                        });
                        cameraController.start();
                      },
                      child: const Text("Scanner à nouveau"),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}