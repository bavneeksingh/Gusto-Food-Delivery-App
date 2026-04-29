import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  String? userId;
  final Color primaryColor = const Color(0xFFFE724C);

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('uid');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "My Addresses",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: primaryColor, size: 20),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userId == null 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('user_addresses').stream(primaryKey: ['id']).eq('user_id', userId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final addresses = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  return _buildAddressCard(addresses[index]);
                },
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
              child: Icon(Icons.location_off_outlined, size: 80, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            const Text(
              "Where do we deliver?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't saved any addresses yet. Add your home or work address for faster delivery!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_location_alt, color: Colors.white),
                label: const Text("Add New Address", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    bool isDefault = address['is_default'] ?? false;
    String type = address['address_type'] ?? 'OTHER';
    
    IconData icon;
    Color iconColor;
    
    switch(type.toUpperCase()) {
      case 'HOME':
        icon = Icons.home_rounded;
        iconColor = const Color(0xFF4A90E2);
        break;
      case 'WORK':
        icon = Icons.work_rounded;
        iconColor = const Color(0xFF50C878);
        break;
      default:
        icon = Icons.location_on_rounded;
        iconColor = primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: isDefault ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5) : Border.all(color: Colors.grey.shade50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            type.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "DEFAULT",
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        address['full_address'] ?? "No address details available",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
                      ),
                      if (address['landmark'] != null && address['landmark'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              "Landmark: ${address['landmark']}", 
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
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
}
