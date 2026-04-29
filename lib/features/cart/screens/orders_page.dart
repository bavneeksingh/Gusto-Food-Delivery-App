import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gusto/core/widgets/bottom_button.dart';
import 'order_details_page.dart';
import 'order_tracking_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String? userId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('uid');
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFE724C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: DefaultTabController(
        length: 2,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header & Tabs
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "My Orders",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      indicatorColor: primaryColor,
                      indicatorWeight: 3,
                      labelColor: primaryColor,
                      unselectedLabelColor: Colors.grey[500],
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: const [
                        Tab(text: "Active"),
                        Tab(text: "Past"),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : userId == null
                        ? _buildEmptyState("Please login to see your orders")
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: Supabase.instance.client
                                .from('orders')
                                .stream(primaryKey: ['id'])
                                .eq('user_id', userId!)
                                .order('created_at', ascending: false),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: primaryColor));
                              }

                              if (snapshot.hasError) {
                                return _buildEmptyState("Something went wrong! ${snapshot.error}");
                              }

                              final orders = snapshot.data ?? [];
                              final activeOrders = orders.where((o) {
                                final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
                                return status != 'DELIVERED' && status != 'CANCELLED';
                              }).toList();
                              
                              final pastOrders = orders.where((o) {
                                final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
                                return status == 'DELIVERED' || status == 'CANCELLED';
                              }).toList();

                              return TabBarView(
                                children: [
                                  // Active Orders Tab
                                  activeOrders.isEmpty
                                      ? _buildEmptyState("No active orders right now 🍔")
                                      : ListView.builder(
                                          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                                          itemCount: activeOrders.length,
                                          itemBuilder: (context, index) {
                                            return _buildActiveTrackingCard(activeOrders[index], primaryColor);
                                          },
                                        ),
                                  
                                  // Past Orders Tab
                                  pastOrders.isEmpty
                                      ? _buildEmptyState("No past orders found 🍽️")
                                      : ListView.builder(
                                          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                                          itemCount: pastOrders.length,
                                          itemBuilder: (context, index) {
                                            return _buildOrderCard(pastOrders[index], primaryColor);
                                          },
                                        ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      extendBody: true, // Allows content to scroll behind the floating nav bar
    );
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildOrderCard(Map<String, dynamic> order, Color primaryColor) {
    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    final total = parseDouble(order['final_amount'] ?? order['total_amount']);
    final dateStr = order['created_at'] != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['created_at']))
        : 'Unknown Date';
    
    Color statusColor = Colors.orange;
    if (status == 'DELIVERED') statusColor = Colors.green;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsPage(order: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Placeholder
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.receipt_long, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Order #${order['id'].toString().substring(0, 8).toUpperCase()}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "View Details",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrackingCard(Map<String, dynamic> order, Color primaryColor) {
    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    final total = parseDouble(order['final_amount'] ?? order['total_amount']);
    
    // Determine dynamic texts and progress
    String trackingTitle = "Order Received";
    String trackingSub = "Waiting for restaurant to confirm";
    double progress = 0.1;
    IconData statusIcon = Icons.hourglass_top;
    
    if (status == 'PREPARING') {
      trackingTitle = "Preparing Your Food";
      trackingSub = "The chef is working their magic";
      progress = 0.4;
      statusIcon = Icons.restaurant;
    } else if (status == 'OUT FOR DELIVERY' || status == 'PICKED UP') {
      trackingTitle = "Out for Delivery";
      trackingSub = "Rider is on the way to your location";
      progress = 0.8;
      statusIcon = Icons.electric_moped;
    } else if (status == 'ARRIVING') {
      trackingTitle = "Arriving Now";
      trackingSub = "Rider is at your doorstep";
      progress = 0.95;
      statusIcon = Icons.location_on;
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
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Map / Aesthetic header block
            if (status == 'OUT FOR DELIVERY' || status == 'PICKED UP' || status == 'ARRIVING')
              SizedBox(
                height: 120,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  child: SimulatedDriverMap(
                    driverLat: parseDouble(order['rider_lat']),
                    driverLng: parseDouble(order['rider_lng']),
                    destLat: parseDouble(order['delivery_lat']),
                    destLng: parseDouble(order['delivery_lng']),
                  ),
                ),
              )
            else 
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.teal.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Icon(Icons.map, size: 80, color: Colors.blue.withValues(alpha: 0.05)),
                    ),
                    Positioned(
                      right: 20,
                      top: 20,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Icon(statusIcon, color: primaryColor),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trackingTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            trackingSub,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 4,
            ),
            
            // Details & Driver block
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order #${order['id'].toString().substring(0, 8).toUpperCase()}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.electric_moped, color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Delivery Valet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Arriving securely", style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call, color: Colors.green, size: 18),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFE724C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 60,
                color: const Color(0xFFFE724C).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimulatedDriverMap extends StatefulWidget {
  final double driverLat;
  final double driverLng;
  final double destLat;
  final double destLng;

  const SimulatedDriverMap({
    super.key,
    required this.driverLat,
    required this.driverLng,
    required this.destLat,
    required this.destLng,
  });

  @override
  State<SimulatedDriverMap> createState() => _SimulatedDriverMapState();
}

class _SimulatedDriverMapState extends State<SimulatedDriverMap> {
  final Completer<GoogleMapController> _controller = Completer();
  late LatLng _currentDriverPos;
  late LatLng _destination;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Default to a spot in CP New Delhi if database values are totally empty.
    _destination = (widget.destLat != 0.0) 
        ? LatLng(widget.destLat, widget.destLng)
        : const LatLng(28.6300, 77.2160);
    
    // Simulate rider starting position slightly away
    _currentDriverPos = (widget.driverLat != 0.0)
        ? LatLng(widget.driverLat, widget.driverLng)
        : LatLng(_destination.latitude - 0.005, _destination.longitude - 0.005);

    // Update jump every 3 seconds to emulate imperfect realistic GPS pings
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      
      // Calculate a tiny distance explicitly towards the destination lock
      double latDiff = _destination.latitude - _currentDriverPos.latitude;
      double lngDiff = _destination.longitude - _currentDriverPos.longitude;
      
      if (latDiff.abs() < 0.0001 && lngDiff.abs() < 0.0001) {
        timer.cancel(); // Driver arrived!
        return;
      }
      
      setState(() {
        _currentDriverPos = LatLng(
          _currentDriverPos.latitude + (latDiff * 0.1), // move 10% closer on ping
          _currentDriverPos.longitude + (lngDiff * 0.1),
        );
      });
      _moveCamera();
    });
  }

  Future<void> _moveCamera() async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(_currentDriverPos));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentDriverPos,
        zoom: 15,
      ),
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), // Rider mapped
          zIndex: 2,
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Customer mapped
          zIndex: 1,
        ),
      },
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
        // Wait briefly then fit bounds
        Future.delayed(const Duration(milliseconds: 500), () {
          _fitBounds(controller);
        });
      },
    );
  }

  void _fitBounds(GoogleMapController controller) {
    LatLngBounds bounds;
    if (_currentDriverPos.latitude > _destination.latitude && _currentDriverPos.longitude > _destination.longitude) {
      bounds = LatLngBounds(southwest: _destination, northeast: _currentDriverPos);
    } else if (_currentDriverPos.latitude > _destination.latitude) {
      bounds = LatLngBounds(
          southwest: LatLng(_destination.latitude, _currentDriverPos.longitude),
          northeast: LatLng(_currentDriverPos.latitude, _destination.longitude));
    } else if (_currentDriverPos.latitude > _destination.latitude) {
      bounds = LatLngBounds(
          southwest: LatLng(_currentDriverPos.latitude, _destination.longitude),
          northeast: LatLng(_destination.latitude, _currentDriverPos.longitude));
    } else {
      bounds = LatLngBounds(southwest: _currentDriverPos, northeast: _destination);
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 30));
  }
}
