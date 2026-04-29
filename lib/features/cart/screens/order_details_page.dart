import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Timer? _timer;
  bool _isCancelling = false;
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  Map<String, dynamic> get order => widget.order;

  @override
  void initState() {
    super.initState();
    _itemsFuture = Supabase.instance.client
        .from('order_items')
        .select()
        .eq('order_id', order['id']);
        
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_canCancel()) {
        if (mounted) setState(() {});
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _canCancel() {
    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    if (status != 'PENDING') return false;
    
    final createdStr = order['created_at'];
    if (createdStr == null) return false;

    // Convert string to UTC DateTime, then compare logic safely
    final createdAt = DateTime.parse(createdStr).toLocal();
    final now = DateTime.now();
    return now.difference(createdAt).inSeconds < 60;
  }

  Future<void> _cancelOrder() async {
    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', order['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order cancelled successfully."),
          backgroundColor: Colors.redAccent,
        ),
      );
      
      setState(() {
         order['status'] = 'cancelled';
      });
      Navigator.pop(context, true); 
    } catch (e) {
      debugPrint("Error cancelling order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel order: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFE724C);
    const Color backgroundColor = Color(0xFFF8F9FA);

    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    final dateStr = order['created_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['created_at']))
        : 'Unknown Date';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Order Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & ID Card
            _buildStatusCard(status, dateStr, primaryColor, context),
            const SizedBox(height: 24),

            const Text(
              "ITEMS ORDERED",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildItemsList(primaryColor),

            const SizedBox(height: 24),
            const Text(
              "DELIVERY ADDRESS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildAddressCard(),

            const SizedBox(height: 24),
            const Text(
              "BILL SUMMARY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildBillSummary(primaryColor),
            
            if (_canCancel()) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.red,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "CANCEL ORDER",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "You can cancel within 1 minute of placing the order.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String status, String date, Color primaryColor, BuildContext context) {
    Color statusColor = Colors.orange;
    if (status == 'DELIVERED') statusColor = Colors.green;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${order['id'].toString().substring(0, 8).toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.payment, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "Payment: ${order['payment_status'] ?? 'Completed'}",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),

            if (order['special_instructions'] != null && order['special_instructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Text(
                "Special Instructions",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                order['special_instructions'],
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
              ),
            ],


          ],
        ),
    );
  }

  Widget _buildItemsList(Color primaryColor) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        final items = snapshot.data ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (item['image_url'] != null && item['image_url'].toString().isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: item['image_url'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 50, height: 50, color: Colors.grey[200],
                                  ),
                                  errorWidget: (context, url, err) => Container(
                                    width: 50, height: 50, color: Colors.grey[200],
                                    child: const Icon(Icons.fastfood, color: Colors.grey, size: 20),
                                  ),
                                )
                              : Container(
                                  width: 50, height: 50, color: Colors.grey[200],
                                  child: const Icon(Icons.fastfood, color: Colors.grey, size: 20),
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFE724C),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "x${item['quantity']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? "Item",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₹${parseDouble(item['price']).toStringAsFixed(2)}",
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "₹${(parseDouble(item['price']) * parseDouble(item['quantity'])).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['customer_name'] ?? "No Name",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  order['delivery_address'] ?? "No Address Provided",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  order['customer_phone'] ?? "",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummary(Color primaryColor) {
    // Safely parse old vs new schema
    final totalAmount = parseDouble(order['final_amount'] ?? order['total_amount']);
    final deliveryFee = parseDouble(order['delivery_charge'] ?? order['delivery_fee']);
    final serviceFee = parseDouble(order['service_fee']);
    final tipAmount = parseDouble(order['tip_amount']);
    final discountAmount = parseDouble(order['discount'] ?? order['discount_amount']);
    final packagingFee = parseDouble(order['packaging_fee']);
    final taxesAndCharges = parseDouble(order['taxes_and_charges']);

    // If final_amount is present, it means it's a new order where total_amount strictly means subtotal.
    // If final_amount is null, it's an old order, so we reverse-calculate the subtotal.
    final subtotal = order['final_amount'] != null
        ? parseDouble(order['total_amount'])
        : (totalAmount - deliveryFee - serviceFee - tipAmount - packagingFee - taxesAndCharges + discountAmount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildBillRow("Subtotal", subtotal),
          if (discountAmount > 0)
             _buildBillRow("Offer Discount", -discountAmount, isDiscount: true),
          _buildBillRow("Delivery Fee", deliveryFee),
          _buildBillRow("Service Fee", serviceFee),
          if (packagingFee > 0)
            _buildBillRow("Packaging Fee", packagingFee),
          if (taxesAndCharges > 0)
            _buildBillRow("Taxes & Charges", taxesAndCharges),
          if (tipAmount > 0)
            _buildBillRow("Tip Amount", tipAmount),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Paid",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "₹${totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
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
            isDiscount 
              ? "-₹${amount.abs().toStringAsFixed(2)}" 
              : "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
