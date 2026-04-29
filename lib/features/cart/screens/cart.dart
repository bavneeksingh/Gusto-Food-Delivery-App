import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gusto/features/home/screens/root_screen.dart';
import 'package:gusto/features/auth/screens/location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gusto/core/widgets/skeleton_loader.dart';
import 'package:gusto/features/cart/screens/order_timer_screen.dart';
import 'package:provider/provider.dart';
import 'package:gusto/features/cart/providers/cart_provider.dart';

// --- Data Models ---
class CartItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });
}



class PromoOffer {
  final String id;
  final String code;
  final String description;
  final String discountType; // 'fixed' or 'percentage'
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;

  PromoOffer({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    this.minOrderValue = 0,
  });

  factory PromoOffer.fromMap(Map<String, dynamic> map) {
    return PromoOffer(
      id: map['id'],
      code: map['code'] ?? 'UNKNOWN',
      description: map['subtitle'] ?? map['description'] ?? '',
      discountType: map['discount_type'] ?? 'fixed',
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      minOrderValue: (map['min_order_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// --- Main Cart Page ---
class CartPage extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const CartPage({super.key, this.onBackToHome});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // --- Local Screen State Variables ---
  String? userId;
  bool isPlacingOrder = false;
  String? _lastRestaurantId;

  // Deliverability State
  bool _isUndeliverable = false;
  double? _restaurantLat;
  double? _restaurantLng;
  double? _distanceInMeters;

  List<Map<String, dynamic>> get cartItems => context.read<CartProvider>().cartItems;
  bool get isLoading => context.read<CartProvider>().isLoading;
  String? get cartId => context.read<CartProvider>().cartId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid != null && mounted) {
      setState(() => userId = uid);
      _fetchUserProfile();
      _fetchUserAddresses();
    }
    _fetchAvailableOffers();
  }


  Future<void> _fetchUserProfile() async {
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId!)
          .single();

      if (mounted) {
        setState(() {
          userName = data['name'];
          userPhone = data['phone'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> _fetchUserAddresses() async {
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_addresses')
          .select()
          .eq('user_id', userId!);

      if (mounted) {
        setState(() {
          userAddresses = List<Map<String, dynamic>>.from(data);
          // Auto-select default address
          final defaultAddr = userAddresses.firstWhere(
            (addr) => addr['is_default'] == true,
            orElse: () => userAddresses.isNotEmpty ? userAddresses.first : {},
          );
          if (mounted) {
            setState(() {
              selectedAddress = defaultAddr;
            });
            _checkDeliverability();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user addresses: $e");
    }
  }

  /// Calculates distance between user and restaurant
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  /// Verifies if the restaurant can deliver to the selected address
  Future<void> _checkDeliverability() async {
    final restaurantId = context.read<CartProvider>().currentCartRestaurantId;
    if (restaurantId == null || selectedAddress == null) {
      if (mounted) setState(() => _isUndeliverable = false);
      return;
    }

    try {
      // Fetch restaurant coordinates if not already cached for this restaurant
      if (_lastRestaurantId != restaurantId) {
        final data = await Supabase.instance.client
            .from('restaurants')
            .select('latitude, longitude')
            .eq('id', restaurantId)
            .single();
        
        _restaurantLat = (data['latitude'] as num?)?.toDouble();
        _restaurantLng = (data['longitude'] as num?)?.toDouble();
        _lastRestaurantId = restaurantId;
      }

      if (_restaurantLat != null && _restaurantLng != null) {
        final userLat = (selectedAddress!['latitude'] as num?)?.toDouble();
        final userLng = (selectedAddress!['longitude'] as num?)?.toDouble();

        if (userLat != null && userLng != null) {
          final distance = _calculateDistance(userLat, userLng, _restaurantLat!, _restaurantLng!);
          if (mounted) {
            setState(() {
              _distanceInMeters = distance;
              _isUndeliverable = distance > 5000; // 5km limit
            });
          }
          return;
        }
      }
      
      if (mounted) setState(() => _isUndeliverable = false);
    } catch (e) {
      debugPrint("Error checking deliverability: $e");
      if (mounted) setState(() => _isUndeliverable = false);
    }
  }

  Future<void> _fetchAvailableOffers() async {
    try {
      final data = await Supabase.instance.client
          .from('offers')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          availableOffers = (data as List)
              .map((o) => PromoOffer.fromMap(o))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching offers: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- State Variables ---
  final TextEditingController _instructionController = TextEditingController();

  // Contact Info (Dynamic)
  String? userName;
  String? userPhone;

  // Addresses
  List<Map<String, dynamic>> userAddresses = [];
  Map<String, dynamic>? selectedAddress;


  PromoOffer? appliedOffer; // Tracks the currently applied offer // Tracks the currently applied offer

  List<PromoOffer> availableOffers = [];

  String selectedPaymentMethod = 'Cash on Delivery';

  double deliveryFee = 2.99;
  double serviceFee = 1.50;
  double selectedTip = 2.00;

  // Logic
  Future<void> _incrementQuantity(int index) async {
    final item = cartItems[index];
    final provider = context.read<CartProvider>();
    await provider.updateCartQuantity(
      context: context,
      menuItemId: item['menu_item_id']?.toString() ?? '',
      currentQuantity: (item['quantity'] as num?)?.toInt() ?? 1,
      delta: 1,
      name: item['menu_item_name']?.toString() ?? 'Item',
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      image: item['menu_item_image']?.toString() ?? '',
      restaurantId: provider.currentCartRestaurantId ?? item['restaurant_id']?.toString() ?? '',
      restaurantName: null,
    );
  }

  Future<void> _decrementQuantity(int index) async {
    final item = cartItems[index];
    final provider = context.read<CartProvider>();
    await provider.updateCartQuantity(
      context: context,
      menuItemId: item['menu_item_id']?.toString() ?? '',
      currentQuantity: (item['quantity'] as num?)?.toInt() ?? 1,
      delta: -1,
      name: item['menu_item_name']?.toString() ?? 'Item',
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      image: item['menu_item_image']?.toString() ?? '',
      restaurantId: provider.currentCartRestaurantId ?? item['restaurant_id']?.toString() ?? '',
      restaurantName: null,
    );
  }

  double get subtotal => cartItems.fold(0, (sum, item) {
    double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    return sum + (price * quantity);
  });

  double get packagingFee => 20.00;
  double get gstAmount => (subtotal - discountAmount) * 0.05; // 5% GST
  double get taxesAndCharges => packagingFee + gstAmount;

  double get discountAmount {
    if (appliedOffer == null) return 0.0;

    double discount = 0.0;
    if (appliedOffer!.discountType == 'percentage') {
      discount = subtotal * (appliedOffer!.discountValue / 100);
      if (appliedOffer!.maxDiscount != null &&
          discount > appliedOffer!.maxDiscount!) {
        discount = appliedOffer!.maxDiscount!;
      }
    } else {
      discount = appliedOffer!.discountValue;
    }

    // Discount cannot exceed subtotal
    return discount > subtotal ? subtotal : discount;
  }

  Future<void> _placeOrder() async {
    if (userId == null || cartItems.isEmpty) return;
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a delivery address"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    if (isPlacingOrder) return;
    setState(() => isPlacingOrder = true);

    final provider = context.read<CartProvider>();
    
    // Resolve restaurant_id properly
    String? restaurantId = provider.currentCartRestaurantId;
    if ((restaurantId == null || restaurantId.isEmpty) && provider.cartId != null) {
      // Fallback: query the carts table directly
      try {
        final cartData = await Supabase.instance.client
            .from('carts')
            .select('restaurant_id')
            .eq('id', provider.cartId!)
            .maybeSingle();
        restaurantId = cartData?['restaurant_id']?.toString();
      } catch (_) {}
    }

    if (restaurantId == null || restaurantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not determine restaurant. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => isPlacingOrder = false);
      }
      return;
    }

    // Snapshot values before any async gaps (widget may rebuild)
    final snapshotItems = List<Map<String, dynamic>>.from(cartItems);
    final snapshotTotal = total;
    final snapshotSubtotal = subtotal;
    final snapshotDiscount = discountAmount;

    try {
      // 1. Create Order
      final orderData = {
        'user_id': userId,
        'restaurant_id': restaurantId,
        'total_amount': snapshotSubtotal,
        'final_amount': snapshotTotal,
        'discount': snapshotDiscount,
        'delivery_charge': deliveryFee,
        'service_fee': serviceFee.toString(),
        'tip_amount': selectedTip.toString(),
        'delivery_address': selectedAddress!['full_address'],
        'customer_name': userName,
        'customer_phone': userPhone,
        'special_instructions': _instructionController.text,
        'payment_method': selectedPaymentMethod,
        'packaging_fee': packagingFee,
        'taxes_and_charges': taxesAndCharges,
      };
      
      debugPrint("Placing order with data: $orderData");
      
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'];
      debugPrint("Order created: $orderId");

      // 2. Insert order items from snapshot
      List<Map<String, dynamic>> orderItemsList = snapshotItems.map((item) {
        return {
          'order_id': orderId,
          'menu_item_id': item['menu_item_id'],
          'name': item['menu_item_name']?.toString() ?? 'Item',
          'quantity': item['quantity'],
          'price': item['price'],
          'image_url': item['menu_item_image']?.toString() ?? '',
        };
      }).toList();

      await Supabase.instance.client.from('order_items').insert(orderItemsList);

      // 3. Navigate FIRST, then clear cart (prevents empty cart flash)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTimerScreen(
              orderId: orderId?.toString() ?? '',
              totalAmount: snapshotTotal,
              restaurantId: restaurantId!,
            ),
          ),
        );
      }

      // 4. Clear Cart in background (after navigation)
      provider.clearCart();
    } catch (e) {
      debugPrint("Error placing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  double get total {
    return subtotal + deliveryFee + serviceFee + selectedTip + taxesAndCharges - discountAmount;
  }

  // --- Promo Logic ---
  void _showOffersDialog() {
    final TextEditingController promoController = TextEditingController();
    const Color primaryColor = Color(0xFFFE724C);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFE724C), Color(0xFFFF9A76)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_offer, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Promo Codes & Offers",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Apply a code or select an offer below",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Manual Promo Code Input
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: promoController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    hintText: "Enter promo code",
                                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ElevatedButton(
                                  onPressed: () {
                                    final code = promoController.text.trim().toUpperCase();
                                    if (code.isEmpty) return;
                                    // Find matching offer
                                    final match = availableOffers.where(
                                      (o) => o.code.toUpperCase() == code,
                                    );
                                    if (match.isNotEmpty) {
                                      Navigator.pop(context);
                                      _applyOffer(match.first);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Invalid promo code"),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text("APPLY", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (availableOffers.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "AVAILABLE OFFERS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: availableOffers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final offer = availableOffers[index];
                          final discountText = offer.discountType == 'percentage'
                              ? "${offer.discountValue.toInt()}% OFF"
                              : "₹${offer.discountValue.toStringAsFixed(0)} OFF";
                          final bool meetsMin = subtotal >= offer.minOrderValue;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: meetsMin ? primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: meetsMin
                                  ? () {
                                      Navigator.pop(context);
                                      _applyOffer(offer);
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Discount badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: meetsMin
                                              ? [const Color(0xFFFE724C), const Color(0xFFFF9A76)]
                                              : [Colors.grey.shade300, Colors.grey.shade400],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            discountText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            offer.code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            offer.description,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            maxLines: 2,
                                          ),
                                          if (offer.minOrderValue > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                "Min order: ₹${offer.minOrderValue.toStringAsFixed(0)}",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: meetsMin ? Colors.green : Colors.red[400],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Apply button
                                    if (meetsMin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: primaryColor),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          "APPLY",
                                          style: TextStyle(
                                            color: Color(0xFFFE724C),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        "Add ₹${(offer.minOrderValue - subtotal).toStringAsFixed(0)} more",
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text("No offers available right now", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyOffer(PromoOffer offer) {
    if (subtotal < offer.minOrderValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Min order value for this offer is ₹${offer.minOrderValue.toStringAsFixed(0)}",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      appliedOffer = offer;
    });

    // Show beautiful promo success card
    _showPromoSuccessCard(offer);
  }

  void _showPromoSuccessCard(PromoOffer offer) {
    final discountText = offer.discountType == 'percentage'
        ? "${offer.discountValue.toInt()}% OFF"
        : "₹${offer.discountValue.toStringAsFixed(0)} OFF";
    
    final savingsText = "You're saving ₹${discountAmount.toStringAsFixed(0)} on this order";
    bool isDialogOpen = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "PromoSuccess",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, anim1, anim2) {
        // Auto-dismiss after 2.5 seconds — only if dialog is still open
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (isDialogOpen && Navigator.of(dialogContext, rootNavigator: true).canPop()) {
            isDialogOpen = false;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated check icon
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.celebration, color: Colors.white, size: 40),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Coupon Applied! 🎉",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Promo code badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFE724C), Color(0xFFFF9A76)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            offer.code,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Discount info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            discountText,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            savingsText,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
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
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    ).then((_) {
      isDialogOpen = false;
    });
  }

  void _showPremiumStatusDialog({
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Status",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 80,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (onDismiss != null) onDismiss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFE724C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Awesome!",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showPaymentSelectionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildPaymentOption("Cash on Delivery", Icons.money_off, "Pay after you get your food"),
            _buildPaymentOption("UPI", Icons.account_balance_wallet, "Pay using any UPI app"),
            _buildPaymentOption("Credit/Debit Card", Icons.credit_card, "Pay using your cards"),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String title, IconData icon, String subtitle) {
    final isSelected = selectedPaymentMethod == title;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFE724C).withValues(alpha: 0.1) : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? const Color(0xFFFE724C) : Colors.grey),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFFFE724C) : Colors.black,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFFE724C)) : null,
      onTap: () {
        setState(() => selectedPaymentMethod = title);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _addNewAddress() async {
    if (userId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null) {
      LatLng position = result['position'];
      Placemark place = result['placemark'];
      String houseNo = result['houseNo'] ?? "";
      String landmark = result['landmark'] ?? "";

      String fullAddress = [
        houseNo,
        place.name,
        place.subLocality,
        place.locality,
      ].where((e) => e != null && e.toString().isNotEmpty).join(", ");

      try {
        // Make existing addresses non-default
        await Supabase.instance.client
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', userId!);

        // Insert new default address
        final newAddressList = await Supabase.instance.client
            .from("user_addresses")
            .insert({
              "user_id": userId!,
              "landmark": landmark,
              "full_address": fullAddress,
              "is_default": true,
              "latitude": position.latitude,
              "longitude": position.longitude,
            })
            .select();

        if (newAddressList.isNotEmpty) {
          setState(() {
            userAddresses.add(newAddressList.first);
            selectedAddress = newAddressList.first;
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save address: $e")),
        );
      }
    }
  }

  void _showAddressSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                "Select Delivery Address",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
            ),
            
            // Address List with overflow protection
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: userAddresses.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final addr = userAddresses[index];
                  final isSelected = selectedAddress?['id'] == addr['id'];
                  
                  return InkWell(
                    onTap: () async {
                      setState(() => selectedAddress = addr);
                      Navigator.pop(context);
                      _checkDeliverability();
                      
                      if (userId != null) {
                        await Supabase.instance.client
                            .from('user_addresses')
                            .update({'is_default': false})
                            .eq('user_id', userId!);
                        await Supabase.instance.client
                            .from('user_addresses')
                            .update({'is_default': true})
                            .eq('id', addr['id']);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFE724C).withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFE724C) : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFE724C) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr['address_type']?.toString().toUpperCase() ?? 'OTHER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFFFE724C) : Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  addr['full_address'] ?? 'No Address',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? Colors.black : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Color(0xFFFE724C), size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _addNewAddress();
                  },
                  icon: const Icon(Icons.add_location_alt, color: Colors.white, size: 20),
                  label: const Text(
                    "Add New Address",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE724C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 80,
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Your cart is empty",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Looks like you haven't added anything to your cart yet. Go ahead and explore top restaurants!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onBackToHome != null) {
                    widget.onBackToHome!();
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const RootScreen()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Browse Restaurants",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection() {
    final address = selectedAddress?['full_address'] ?? "Select an address";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFE724C).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFFFE724C),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Deliver to",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  address,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showAddressSelectionSheet,
            child: const Text(
              "CHANGE",
              style: TextStyle(
                color: Color(0xFFFE724C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider here to trigger rebuilds when cart changes
    context.watch<CartProvider>();
    
    const Color primaryColor = Color(0xFFFE724C);
    const Color backgroundColor = Color(0xFFF8F9FA);
    return PopScope(
      canPop: widget.onBackToHome == null,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        if (widget.onBackToHome != null) {
          widget.onBackToHome!();
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        extendBody: false,
        backgroundColor: backgroundColor,
        bottomNavigationBar: (!isLoading && cartItems.isNotEmpty)
            ? _buildBottomCheckout(primaryColor)
            : const SizedBox.shrink(),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () {
              if (widget.onBackToHome != null) {
                widget.onBackToHome!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            "My Order",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (cartId != null) {
                  await context.read<CartProvider>().clearCart();
                }
              },
              child: const Text(
                "Clear",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
        body: isLoading
            ? _buildLoadingSkeleton(primaryColor)
            : cartItems.isEmpty
            ? _buildEmptyCart(primaryColor)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeliverySection(),
                    if (_isUndeliverable) ...[
                      const SizedBox(height: 16),
                      _buildUndeliverableBanner(),
                    ],
                    const SizedBox(height: 20),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartItems.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildCartItem(index, primaryColor),
                    ),
                    const SizedBox(height: 16),

                    // Add More from Restaurant Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 18),
                        label: Text(
                          "Add items",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Special Instructions",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSpecialInstructions(primaryColor),

                    const SizedBox(height: 20),

                    // --- 1. Promo Code Section ---
                    _buildPromoSection(primaryColor),

                    const SizedBox(height: 16),

                    // --- 2. Contact Info Section (New Location) ---
                    const Text(
                      "Contact Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactSection(),

                    const SizedBox(height: 20),

                    _buildBillSummary(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  // --- NEW / MODIFIED WIDGETS ---

  Widget _buildPromoSection(Color primaryColor) {
    if (appliedOffer == null) {
      return GestureDetector(
        onTap: _showOffersDialog,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFE724C), Color(0xFFFF9A76)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_offer, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Apply Promo Code",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "Save more on your order",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.05),
              Colors.green.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${appliedOffer!.code} applied!",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "You're saving ₹${discountAmount.toStringAsFixed(0)} on this order",
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => appliedOffer = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Remove",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildContactSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE724C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFFFE724C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Full Name",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName ?? "Loading...",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),

          // Mobile Number Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE724C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone,
                  color: Color(0xFFFE724C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mobile Number",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userPhone ?? "Loading...",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUndeliverableBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Outside Delivery Range",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    Text(
                      "This restaurant is too far from your selected location (${(_distanceInMeters! / 1000).toStringAsFixed(1)} km away).",
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                final provider = context.read<CartProvider>();
                await provider.clearCart();
                _checkDeliverability();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "CLEAR CART",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildSpecialInstructions(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(Icons.edit_note_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _instructionController,
              decoration: InputDecoration(
                hintText: "E.g., No onion, extra spicy, ring the bell...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
    );
  }

  // --- EXISTING WIDGETS ---


  Widget _buildCartItem(int index, Color primaryColor) {
    final item = cartItems[index];
    final String itemId = item['id']?.toString() ?? 'temp_${item['menu_item_id']}';
    final String name = item['menu_item_name']?.toString() ?? 'Unknown Item';
    final String description = "Customisable";
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final String imageUrl =
        item['menu_item_image'] != null &&
            item['menu_item_image'].toString().isNotEmpty
        ? item['menu_item_image'].toString()
        : "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=300&q=80";

    return Dismissible(
      key: Key(itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (direction) async {
        final provider = context.read<CartProvider>();
        await provider.updateCartQuantity(
          context: context,
          menuItemId: item['menu_item_id']?.toString() ?? '',
          currentQuantity: quantity,
          delta: -quantity,
          name: name,
          price: price,
          image: imageUrl,
          restaurantId: provider.currentCartRestaurantId ?? item['restaurant_id']?.toString() ?? '',
          restaurantName: null,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    Container(width: 80, height: 80, color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${price.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _incrementQuantity(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.add, size: 16),
                    ),
                  ),
                  Text(
                    "$quantity",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  InkWell(
                    onTap: () => _decrementQuantity(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.remove, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBillSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bill Summary",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 20),
          _buildBillRow("Item Total", subtotal),
          if (appliedOffer != null)
            _buildBillRow("Item Discount", -discountAmount, isDiscount: true),
          _buildBillRow("Delivery Fee", deliveryFee),
          _buildBillRow("Platform Fee", serviceFee),
          
          InkWell(
            onTap: _showTaxesBreakdown,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "Taxes & Charges",
                        style: TextStyle(
                          color: Colors.grey[600],
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                    ],
                  ),
                  Text(
                    "₹${taxesAndCharges.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          // Driver Tip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Driver Tip", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Row(
                children: [10, 20, 50].map((tip) {
                  bool isSelected = selectedTip == tip.toDouble();
                  return GestureDetector(
                    onTap: () => setState(() => selectedTip = tip.toDouble()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFE724C) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFE724C) : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "₹$tip",
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),

          // Final Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "To Pay",
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 18,
                ),
              ),
              Text(
                "₹${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTaxesBreakdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Taxes & Charges",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildPopupChargeRow("GST (5%)", gstAmount),
            _buildPopupChargeRow("Restaurant Packaging Charges", packagingFee),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1),
            ),
            _buildPopupChargeRow("Total", taxesAndCharges, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupChargeRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.black : Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, double amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            isDiscount ? "-₹${amount.abs().toStringAsFixed(2)}" : "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckout(Color primaryColor) {
    final bool isInsideRootNav = widget.onBackToHome != null;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = bottomInset > 0;

    if (_isUndeliverable) {
      return Container(
        margin: EdgeInsets.only(
          left: 16, 
          right: 16, 
          bottom: isKeyboardOpen ? 8 : (isInsideRootNav ? 100 : 16)
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    "UNDELIVERABLE",
                     style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                   ),
                   Text(
                    "Area not covered",
                     style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                   ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Place Order", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    IconData paymentIcon = Icons.money_off;
    if (selectedPaymentMethod == 'UPI') paymentIcon = Icons.account_balance_wallet;
    if (selectedPaymentMethod == 'Credit/Debit Card') paymentIcon = Icons.credit_card;
    
    // If inside RootScreen, onBackToHome is not null. 
    // We add 100px bottom margin to clear the floating bottom nav, 
    // but REMOVE it if the keyboard is open to avoid white space.

    Widget checkoutContainer = Container(
      margin: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: isKeyboardOpen ? 8 : (isInsideRootNav ? 100 : 16)
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Payment Method Selector
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _showPaymentSelectionSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(paymentIcon, size: 20, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "PAY VIA",
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            selectedPaymentMethod,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Checkout Button
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isPlacingOrder ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                ),
                child: isPlacingOrder 
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Place Order",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            height: 16,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          Text(
                            "₹${total.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!isInsideRootNav) {
      return SafeArea(child: checkoutContainer);
    }
    return checkoutContainer;
  }

  Widget _buildLoadingSkeleton(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Delivery Section Skeleton
          const SkeletonLoader(
            height: 80,
            width: double.infinity,
            borderRadius: 16,
          ),
          const SizedBox(height: 24),

          // 2. Cart Items Title Skeleton
          const SkeletonLoader(height: 20, width: 120, borderRadius: 4),
          const SizedBox(height: 16),

          // 3. Cart Items Skeletons
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => const SkeletonLoader(
              height: 100,
              width: double.infinity,
              borderRadius: 16,
            ),
          ),
        ],
      ),
    );
  }
}
