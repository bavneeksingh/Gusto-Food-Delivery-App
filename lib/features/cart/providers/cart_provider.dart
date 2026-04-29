import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartProvider extends ChangeNotifier {
  String? userId;
  String? cartId;
  String? currentCartRestaurantId;
  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  StreamSubscription? _cartSubscription;

  void initialize() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('uid');
    
    if (userId == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final carts = await Supabase.instance.client
          .from('carts')
          .select()
          .eq('user_id', userId!);

      if (carts.isNotEmpty) {
        cartId = carts.first['id'];
        currentCartRestaurantId = carts.first['restaurant_id'];
        
        _cartSubscription = Supabase.instance.client
            .from('cart_items')
            .stream(primaryKey: ['id'])
            .eq('cart_id', cartId!)
            .listen((data) {
          cartItems = data;
          isLoading = false;
          notifyListeners();
        });
      } else {
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error initializing cart provider: \$e");
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCartQuantity({
    required BuildContext context,
    required String menuItemId,
    required int currentQuantity,
    required int delta,
    required String name,
    required double price,
    required String image,
    required String restaurantId,
    required String? restaurantName,
  }) async {
    if (userId == null) return;

    // 1. CROSS-RESTAURANT CHECK
    if (cartId == null) {
      final carts = await Supabase.instance.client.from('carts').select().eq('user_id', userId!);
      if (carts.isNotEmpty) {
        cartId = carts.first['id'];
        currentCartRestaurantId = carts.first['restaurant_id'];
      }
    }

    // Only show replace dialog if cart ACTUALLY has items from a different restaurant
    if (currentCartRestaurantId != null && currentCartRestaurantId != restaurantId && cartItems.isNotEmpty) {
      if (!context.mounted) return;
      final bool? clearCart = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE724C).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFFFE724C),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Replace your cart?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your cart has items from another restaurant. Adding items from ${restaurantName ?? 'this restaurant'} will clear your current cart.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Keep Cart",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFE724C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Replace",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (clearCart == true) {
        await Supabase.instance.client.from('cart_items').delete().eq('cart_id', cartId!);
        await Supabase.instance.client.from('carts').update({'restaurant_id': restaurantId}).eq('id', cartId!);
        currentCartRestaurantId = restaurantId;
        currentQuantity = 0; 
        cartItems.clear();
        notifyListeners();
      } else {
        return; 
      }
    } else if (currentCartRestaurantId != restaurantId && cartId != null) {
      // Cart is empty or same restaurant — just update the restaurant_id silently
      await Supabase.instance.client.from('carts').update({'restaurant_id': restaurantId}).eq('id', cartId!);
      currentCartRestaurantId = restaurantId;
    }

    // 2. OPTIMISTIC UI UPDATE
    int newQuantity = currentQuantity + delta;
    if (newQuantity < 0) newQuantity = 0;

    final existingIndex = cartItems.indexWhere((c) => c['menu_item_id'] == menuItemId);
    if (newQuantity <= 0) {
      if (existingIndex != -1) cartItems.removeAt(existingIndex);
    } else {
      final newItem = {
        'id': 'temp_$menuItemId',
        'cart_id': cartId ?? 'temp',
        'menu_item_id': menuItemId,
        'quantity': newQuantity,
        'price': price,
        'menu_item_name': name,
        'menu_item_image': image,
        'restaurant_id': restaurantId,
      };
      if (existingIndex != -1) {
        cartItems[existingIndex] = newItem;
      } else {
        cartItems.add(newItem);
      }
    }
    notifyListeners();

    // 3. DATABASE SYNC (Background)
    try {
      if (cartId == null) {
        final newCart = await Supabase.instance.client.from('carts').insert({
          'user_id': userId!,
          'restaurant_id': restaurantId,
        }).select().single();
        cartId = newCart['id'];
        currentCartRestaurantId = restaurantId;

        // Subscribing since it was null before
        _cartSubscription = Supabase.instance.client
            .from('cart_items')
            .stream(primaryKey: ['id'])
            .eq('cart_id', cartId!)
            .listen((data) {
          cartItems = data;
          isLoading = false;
          notifyListeners();
        });
      }

      if (newQuantity <= 0) {
        await Supabase.instance.client.from('cart_items').delete().match({'cart_id': cartId!, 'menu_item_id': menuItemId});
        
        final remaining = await Supabase.instance.client.from('cart_items').select().eq('cart_id', cartId!);
        if (remaining.isEmpty) {
          await Supabase.instance.client.from('carts').update({'restaurant_id': null}).eq('id', cartId!);
          currentCartRestaurantId = null;
        }
      } else {
        // Check if item already exists in cart
        final existing = await Supabase.instance.client
            .from('cart_items')
            .select('id')
            .eq('cart_id', cartId!)
            .eq('menu_item_id', menuItemId)
            .maybeSingle();

        if (existing != null) {
          // Update existing item
          await Supabase.instance.client
              .from('cart_items')
              .update({
                'quantity': newQuantity,
                'price': price,
                'menu_item_name': name,
                'menu_item_image': image,
              })
              .eq('id', existing['id']);
        } else {
          // Insert new item
          await Supabase.instance.client
              .from('cart_items')
              .insert({
                'cart_id': cartId!,
                'menu_item_id': menuItemId,
                'quantity': newQuantity,
                'price': price,
                'menu_item_name': name,
                'menu_item_image': image,
              });
        }
      }
    } catch (e) {
      debugPrint("Error updating cart: \$e");
      // Don't show intrusive error SnackBar for transient DB issues
      // The optimistic UI is already updated, stream will reconcile
    }
  }

  Future<void> clearCart() async {
    if (cartId != null) {
      cartItems.clear();
      notifyListeners();
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('cart_id', cartId!);
      currentCartRestaurantId = null;
      await Supabase.instance.client.from('carts').update({'restaurant_id': null}).eq('id', cartId!);
    }
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }
}
