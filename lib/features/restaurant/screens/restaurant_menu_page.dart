import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gusto/features/home/screens/root_screen.dart'; // Uncomment in your project
import 'package:gusto/features/cart/screens/cart.dart';
import 'package:provider/provider.dart';
import 'package:gusto/features/cart/providers/cart_provider.dart';
import 'package:gusto/core/providers/preferences_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gusto/core/widgets/skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RestaurantMenuPage extends StatefulWidget {
  final String? restaurantId;
  final String? restaurantName;
  final String? restaurantImage;
  final double? restaurantRating;
  final String? restaurantAddress;
  final String? deliveryTime;
  final bool? initialIsOpen; // NEW

  const RestaurantMenuPage({
    super.key,
    this.restaurantId,
    this.restaurantName,
    this.restaurantImage,
    this.restaurantRating,
    this.restaurantAddress,
    this.deliveryTime,
    this.initialIsOpen,
  });

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  List<Map<String, dynamic>> get cartItems => context.watch<CartProvider>().cartItems;
  StreamSubscription? _statusSubscription; // NEW
  late Future<List<Map<String, dynamic>>> _menuItemsFuture;
  bool _isOpen = true; // NEW

  // Filter states
  String selectedCategory = 'All';
  bool? isVegFilter; // null = all, true = veg, false = non-veg
  List<String> availableCategories = ['All'];

  @override
  void initState() {
    super.initState();
    _isOpen = widget.initialIsOpen ?? true;
    _menuItemsFuture = _fetchMenuItems();
    _listenToRestaurantStatus(); // NEW
  }

  Future<List<Map<String, dynamic>>> _fetchMenuItems({int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        List<Map<String, dynamic>> items;
        if (widget.restaurantId != null) {
          items = await Supabase.instance.client
              .from('menu_items')
              .select()
              .eq('restaurant_id', widget.restaurantId!);
        } else {
          items = await Supabase.instance.client.from('menu_items').select();
        }

        // Set the main categories for all restaurants unconditionally
        if (mounted) {
          setState(() {
            availableCategories = [
              'All',
              'Combos',
              'Starters',
              'Burger',
              'Pizza',
              'Main Course',
              'Beverages',
              'Desserts',
              'Healthy',
            ];
          });
        }
        return items;
      } catch (e) {
        attempt++;
        debugPrint("Attempt $attempt: Error fetching menu items: $e");
        if (attempt >= retries) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return [];
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); // NEW
    super.dispose();
  }

  void _listenToRestaurantStatus() {
    if (widget.restaurantId == null) return;
    
    _statusSubscription = Supabase.instance.client
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .eq('id', widget.restaurantId!)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final status = data.first['is_open'] != false;
        if (status != _isOpen) {
          setState(() => _isOpen = status);
        }
      }
    });
  }
  Future<void> _updateCartQuantity(String menuItemId, int currentQuantity, int delta, String name, double price, String image) async {
    if (!_isOpen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This restaurant is currently closed. You cannot add items to your cart."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await context.read<CartProvider>().updateCartQuantity(
      context: context,
      menuItemId: menuItemId,
      currentQuantity: currentQuantity,
      delta: delta,
      name: name,
      price: price,
      image: image,
      restaurantId: widget.restaurantId ?? '',
      restaurantName: widget.restaurantName,
    );
  }

  // ZERO-DELAY BACK FUNCTION
  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _goBack(); 
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _buildCartPrompt(cartItems),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 0. CLOSED BANNER
                if (!_isOpen)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "RESTAURANT IS CURRENTLY CLOSED",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 1. COMPACT TOP APP BAR
                SliverAppBar(
                  expandedHeight: 60.0,
                  pinned: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      _buildHeaderButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: _goBack,
                        isDark: false,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.restaurantName ?? "Restaurant",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildHeaderButton(
                        icon: Icons.search,
                        onTap: () {},
                        isDark: false,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderButton(
                        icon: Icons.more_vert,
                        onTap: () {},
                        isDark: false,
                      ),
                    ],
                  ),
                ),

                // 2. RESTAURANT DETAILS (NAME, RATING, TIME)
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.restaurantName ?? "Restaurant",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E8F3C),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${widget.restaurantRating ?? 4.0}",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(Icons.location_on_outlined, widget.restaurantAddress ?? "Location", showArrow: true),
                              const SizedBox(height: 8),
                              _buildDetailRow(Icons.access_time, widget.deliveryTime ?? "30-45 mins", showArrow: true),
                              const SizedBox(height: 16),
                              const DashedDivider(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. FLOATING / PINNED FILTERS
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterHeaderDelegate(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Global Veg App-Wide Enforcement
                          if (!context.watch<PreferencesProvider>().isVegMode) ...[
                            _buildVegNonVegFilter(),
                            const SizedBox(height: 12),
                          ],
                          _buildCategoryBubbles(),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. MENU ITEMS LIST
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      "Recommended Items",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _menuItemsFuture,
                  builder: (context, menuSnapshot) {
                    if (menuSnapshot.connectionState == ConnectionState.waiting) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SkeletonMenuItem(),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: DashedDivider(),
                              ),
                            ],
                          ),
                          childCount: 4,
                        ),
                      );
                    }
                    
                    if (menuSnapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                const SizedBox(height: 16),
                                Text("Error loading menu: ${menuSnapshot.error}"),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _menuItemsFuture = _fetchMenuItems();
                                    });
                                  },
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final menuItems = menuSnapshot.data ?? [];
                    if (menuItems.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No items found."))));

                    // Filter items
                    var displayedItems = menuItems;
                    if (selectedCategory != 'All') {
                      displayedItems = displayedItems.where((i) => i['category'] == selectedCategory).toList();
                    }
                    
                    // Force complete veg if App Global Veg is enabled
                    final isGlobalVeg = context.watch<PreferencesProvider>().isVegMode;
                    if (isGlobalVeg) {
                      displayedItems = displayedItems.where((i) => i['is_veg'] == true).toList();
                    } else if (isVegFilter != null) {
                      displayedItems = displayedItems.where((i) => (i['is_veg'] == true) == isVegFilter).toList();
                    }

                    if (displayedItems.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text("No items match your filters."),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = displayedItems[index];
                            int qty = 0;
                            try {
                              final matched = cartItems.firstWhere((c) => c['menu_item_id'] == item['id']);
                              qty = (matched['quantity'] as num).toInt();
                            } catch (_) {}
                            return RepaintBoundary(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildMenuItem(item, qty),
                                  if (index < displayedItems.length - 1)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: DashedDivider(),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: displayedItems.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // FAB: Floating Menu Button
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text("MENU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDark = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 20),
      ),
    );
  }

  Widget _buildVegNonVegFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Filter Veg button
          GestureDetector(
            onTap: () {
              setState(() {
                isVegFilter = isVegFilter == true ? null : true;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isVegFilter == true ? Colors.green.shade50 : Colors.white,
                border: Border.all(
                  color: isVegFilter == true ? Colors.green : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Veg Only",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isVegFilter == true ? FontWeight.bold : FontWeight.normal,
                      color: isVegFilter == true ? Colors.green.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter Non-Veg
          GestureDetector(
            onTap: () {
              setState(() {
                isVegFilter = isVegFilter == false ? null : false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isVegFilter == false ? Colors.red.shade50 : Colors.white,
                border: Border.all(
                  color: isVegFilter == false ? Colors.red : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Non-Veg",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isVegFilter == false ? FontWeight.bold : FontWeight.normal,
                      color: isVegFilter == false ? Colors.red.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBubbles() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: availableCategories.map((cat) {
          final bool isSelected = selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = cat;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget? _buildCartPrompt(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;

    int totalItems = items.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt());
    double totalPrice = items.fold(0.0, (sum, item) {
       double p = (item['price'] as num?)?.toDouble() ?? 0.0;
       int q = (item['quantity'] as num).toInt();
       return sum + (p * q);
    });

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: InkWell(
          onTap: () {
            // Navigate to Cart Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF60B86B), // Swiggy green
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$totalItems ITEM${totalItems > 1 ? 'S' : ''}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "₹${totalPrice.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Text(
                      "View Cart",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String text, {
    bool showArrow = false,
    bool isSocial = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isSocial ? Colors.orange : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isSocial ? Colors.black87 : Colors.grey.shade700,
            fontSize: 13,
            fontWeight: isSocial ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (showArrow) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.grey.shade500,
          ),
        ],
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, int quantity) {
    final String itemId = item['id']?.toString() ?? '';
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final String name = item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown Item';
    final String image = item['image']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (Text, Prices, Details)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildDietIcon(item["is_veg"] ?? item["isVeg"] ?? false),
                    if (item['rating'] != null || true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              ((item['rating'] as num?)?.toDouble() ?? 4.0).toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item["title"] ?? item["name"] ?? "Unknown Item",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                if (item["is_highly_reordered"] ?? item["isHighlyReordered"] ?? false) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Highly reordered",
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                if (item["original_price"] != null || item["originalPrice"] != null) ...[
                  Text(
                    "₹${item["original_price"] ?? item["originalPrice"]}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  "Get for ₹${item["price"] ?? price}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5CA8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item["description"] ?? item["desc"] ?? "",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Right Column (Image + Dynamic Button Stack)
          Column(
            children: [
              SizedBox(
                width: 130,
                height: 140,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: image,
                                width: 130,
                                height: 120,
                                fit: BoxFit.cover,
                                memCacheWidth: 390, // Memory optimization (130 * 3)
                                memCacheHeight: 360, // Memory optimization (120 * 3)
                                errorWidget: (context, url, err) => Container(
                                  width: 130,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.fastfood,
                                      color: Colors.grey),
                                ),
                              )
                            : Container(
                                width: 130,
                                height: 120,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood,
                                    color: Colors.grey),
                              ),
                      ),
                    ),

                    // 2. THE DYNAMIC BUTTON
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: 110,
                        height: 38,
                        decoration: BoxDecoration(
                          // Change background to light red when quantity > 0
                          color: quantity == 0
                              ? Colors.white
                              : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          // Change border to red when quantity > 0
                          border: Border.all(
                            color: quantity == 0
                                ? Colors.grey.shade200
                                : const Color(0xFFE23744),
                            width: quantity == 0 ? 1.0 : 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: quantity == 0
                              ? _buildAddButton(itemId, quantity, name, price, image) // Show "ADD +"
                              : _buildQuantityCounter(itemId, quantity, name, price, image), // Show "- 1 +"
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "customisable",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String itemId, int quantity, String name, double price, String image) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isOpen ? () => _updateCartQuantity(itemId, quantity, 1, name, price, image) : null,
      child: Container(
        decoration: BoxDecoration(
          color: _isOpen ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "ADD",
              style: TextStyle(
                color: _isOpen ? const Color(0xFFE23744) : Colors.grey,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.add, color: _isOpen ? const Color(0xFFE23744) : Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityCounter(String itemId, int quantity, String name, double price, String image) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: _isOpen ? () => _updateCartQuantity(itemId, quantity, -1, name, price, image) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Icon(Icons.remove, color: _isOpen ? const Color(0xFFE23744) : Colors.grey, size: 18),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                quantity.toString(),
                style: TextStyle(
                  color: _isOpen ? const Color(0xFFE23744) : Colors.grey,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: _isOpen ? () => _updateCartQuantity(itemId, quantity, 1, name, price, image) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Icon(Icons.add, color: _isOpen ? const Color(0xFFE23744) : Colors.grey, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDietIcon(bool isVeg) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(
          color: isVeg ? Colors.green : Colors.red[800]!,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          isVeg ? Icons.circle : Icons.change_history,
          size: 8,
          color: isVeg ? Colors.green : Colors.red[800],
        ),
      ),
    );
  }
}

// FULLY REPAIRED DASHED DIVIDER
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey.shade300),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _FilterHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 120.0;

  @override
  double get minExtent => 120.0;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
