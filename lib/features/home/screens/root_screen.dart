import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gusto/features/home/screens/main_screen.dart';
import 'package:gusto/features/cart/screens/cart.dart';
import 'package:gusto/features/cart/screens/orders_page.dart';
import 'package:gusto/features/cart/screens/order_tracking_page.dart';
import 'package:gusto/features/profile/screens/profile_screen.dart';
import 'package:gusto/core/widgets/bottom_button.dart';

class RootScreen extends StatefulWidget {
  final int initialIndex;
  const RootScreen({super.key, this.initialIndex = 0});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  late int _currentIndex;
  late List<Widget> _pages;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      const HomePage(),
      CartPage(onBackToHome: () => _onTabTapped(0)),
      const OrdersPage(),
      ProfilePage(onBackToHome: () => _onTabTapped(0)),
    ];
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('uid');
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          if (_userId != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 100, // Just above the FloatingBottomNav
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('orders')
                    .stream(primaryKey: ['id'])
                    .eq('user_id', _userId!)
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final activeOrders = snapshot.data!.where((o) {
                    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
                    // Active order states that should show tracking
                    return status == 'PREPARING' || 
                           status == 'OUT FOR DELIVERY' || 
                           status == 'PICKED UP' || 
                           status == 'ARRIVING';
                  }).toList();

                  if (activeOrders.isEmpty) return const SizedBox.shrink();

                  final order = activeOrders.first;
                  final status = order['status']?.toString().toUpperCase() ?? '';
                  String displayStatus = "Preparing Order";
                  if (status == 'OUT FOR DELIVERY' || status == 'PICKED UP') {
                    displayStatus = "Out for Delivery";
                  } else if (status == 'ARRIVING') {
                    displayStatus = "Arriving Now";
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingPage(order: order),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E9B66), // Swiggy/Zomato Green
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E9B66).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delivery_dining, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const Text(
                                  "Track your order",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "ETA: 5 mins", // Could be dynamic if ETA field exists
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
