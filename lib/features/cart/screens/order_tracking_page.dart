import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gusto/features/cart/screens/order_details_page.dart';

class OrderTrackingPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTrackingPage({super.key, required this.order});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();
  late LatLng _currentDriverPos;
  late LatLng _destination;
  late Timer _timer;
  double _progress = 0.0;
  
  Map<String, dynamic> get order => widget.order;

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();

    final destLat = parseDouble(order['delivery_lat']);
    final destLng = parseDouble(order['delivery_lng']);
    final driverLat = parseDouble(order['rider_lat']);
    final driverLng = parseDouble(order['rider_lng']);

    _destination = (destLat != 0.0) 
        ? LatLng(destLat, destLng)
        : const LatLng(28.6300, 77.2160);
    
    // Simulate rider starting position slightly away
    _currentDriverPos = (driverLat != 0.0)
        ? LatLng(driverLat, driverLng)
        : LatLng(_destination.latitude - 0.005, _destination.longitude - 0.005);

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      
      double latDiff = _destination.latitude - _currentDriverPos.latitude;
      double lngDiff = _destination.longitude - _currentDriverPos.longitude;
      
      if (latDiff.abs() < 0.0001 && lngDiff.abs() < 0.0001) {
        timer.cancel(); // Driver arrived!
        setState(() { _progress = 1.0; });
        return;
      }
      
      setState(() {
        _currentDriverPos = LatLng(
          _currentDriverPos.latitude + (latDiff * 0.1),
          _currentDriverPos.longitude + (lngDiff * 0.1),
        );
        _progress = (_progress + 0.05).clamp(0.0, 0.95);
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
    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 1. Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentDriverPos,
              zoom: 15,
            ),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: [_currentDriverPos, _destination],
                color: const Color(0xFFFE724C),
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            },
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
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
              // Wait briefly then fit bounds
              Future.delayed(const Duration(milliseconds: 500), () {
                _fitBounds(controller);
              });
            },
          ),
          
          // Header details top-right (like the dots in the image)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.more_horiz, color: Colors.black),
            ),
          ),
        ],
      ),
    ),
    // 2. Bottom Sheet UI
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Out for delivery",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Delivery Valet is on the way to deliver your order.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ETA Green Cube
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E9B66), // Swiggy/Zomato Green
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              "5", // Simulated ETA
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              "mins",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),

                  // Add Delivery Instructions & Driver profile
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 20, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Add Delivery Instructions",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order['delivery_address'] ?? "Update your address if needed",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Driver avatar & call button overlapping
                      SizedBox(
                        width: 70,
                        height: 42,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child: CircleAvatar(
                                radius: 21,
                                backgroundColor: Colors.orange.shade100,
                                backgroundImage: const NetworkImage(
                                    "https://ui-avatars.com/api/?name=Valet&background=FDBA74&color=fff"),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.call, color: Colors.deepOrange, size: 18),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  // View Order Details
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetailsPage(order: order),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFE724C),
                        side: const BorderSide(color: Color(0xFFFE724C)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "View Order Details",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }
}
