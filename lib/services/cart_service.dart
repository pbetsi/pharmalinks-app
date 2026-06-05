import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _cart = [];

  List<CartItem> get cart => _cart;
  int get itemCount => _cart.length;
  
  double get totalPrice {
    return _cart.fold(0, (sum, item) => sum + item.totalPrice);
  }

  void addToCart(CartItem item) {
    _cart.add(item);
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < _cart.length) {
      _cart[index].quantity = quantity;
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void confirmOrder() {
    // Ici, vous pouvez envoyer la commande à la base de données
    print('✅ Commande confirmée: ${_cart.length} articles');
    _cart.clear();
    notifyListeners();
  }

  void cancelOrder() {
    print('❌ Commande annulée');
    _cart.clear();
    notifyListeners();
  }
}