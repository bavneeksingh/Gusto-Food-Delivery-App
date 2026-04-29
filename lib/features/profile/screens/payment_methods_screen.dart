import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final Color primaryColor = const Color(0xFFFE724C);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Payment Methods",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: userId == null
                  ? const Stream.empty()
                  : Supabase.instance.client
                      .from('payment_methods')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', userId!)
                      .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }

                final methods = snapshot.data ?? [];

                return CustomScrollView(
                  slivers: [
                    if (methods.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildModernPaymentCard(methods[index]),
                            childCount: methods.length,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        child: _buildAddMethodButton(),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.credit_card_off_outlined, size: 80, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            const Text(
              "No Payment Methods",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "Add a card or UPI ID for a seamless and lightning-fast checkout experience.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPaymentCard(Map<String, dynamic> method) {
    final bool isDefault = method['is_default'] ?? false;
    final String type = method['method_type'] ?? 'CARD';
    final String provider = method['provider'] ?? 'Unknown';
    final String details = method['details'] ?? '';

    if (type == 'CARD') {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDefault 
                ? [const Color(0xFF1A1D26), const Color(0xFF434858)]
                : [const Color(0xFFFE724C), const Color(0xFFFF9A76)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isDefault ? Colors.black : primaryColor).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(Icons.credit_card, size: 150, color: Colors.white.withValues(alpha: 0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text("PRIMARY", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Text(
                    details.replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} "),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CARD HOLDER", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text("Gusto User", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _deleteMethod(method['id']),
                        icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // UPI or Wallet Style
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isDefault ? Border.all(color: primaryColor, width: 1.5) : Border.all(color: Colors.grey.shade50),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.account_balance_wallet_outlined, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1D26)),
                ),
                Text(
                  details,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
            onPressed: () => _deleteMethod(method['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMethodButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFFFF9A76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _showAddMethodSheet,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text(
          "Add New Payment Method",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  void _showAddMethodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(36),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Add Payment Method",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text("Select how you'd like to pay for your next meal", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 32),
            _buildMethodTypeOption("UPI (GPay, PhonePe, manual ID)", Icons.account_balance_wallet_outlined, () => _addStaticMethod('UPI')),
            const SizedBox(height: 16),
            _buildMethodTypeOption("Credit or Debit Card", Icons.credit_card_outlined, () => _addStaticMethod('CARD')),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTypeOption(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade100, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D26))
                )
              ),
              const Icon(Icons.add_circle, color: Color(0xFFE0E0E0), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addStaticMethod(String type) async {
    if (userId == null) return;
    Navigator.pop(context);

    try {
      final methodData = {
        'user_id': userId!,
        'method_type': type,
        'provider': type == 'UPI' ? 'Google Pay' : 'Visa',
        'details': type == 'UPI' ? 'gusto.user@okaxis' : '4242424267891234',
        'is_default': false,
      };

      await Supabase.instance.client.from('payment_methods').insert(methodData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${type == 'UPI' ? 'UPI ID' : 'Card'} added successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding method: $e");
    }
  }

  Future<void> _deleteMethod(String id) async {
    try {
      await Supabase.instance.client.from('payment_methods').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting method: $e");
    }
  }
}
