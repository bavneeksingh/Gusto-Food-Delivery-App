import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gusto/features/home/screens/root_screen.dart';
import 'package:gusto/core/widgets/bottom_button.dart';
import 'package:gusto/features/auth/screens/login_screen.dart';
import 'package:gusto/features/cart/screens/orders_page.dart';
import 'package:gusto/features/profile/screens/personal_information_screen.dart';
import 'package:gusto/features/profile/screens/addresses_screen.dart';
import 'favorites_screen.dart';
import 'package:provider/provider.dart';
import 'package:gusto/core/providers/preferences_provider.dart';
import 'package:gusto/features/profile/screens/payment_methods_screen.dart';
import 'package:gusto/features/profile/screens/language_screen.dart';
import 'package:gusto/features/profile/screens/help_centre_screen.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const ProfilePage({super.key, this.onBackToHome});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Theme Constant (Matches Cart Page)
  final Color primaryColor = const Color(0xFFFE724C);

  // State for toggles
  bool _notificationsEnabled = true;
  String? userId;

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
        extendBody: true,
        //
        backgroundColor: const Color(0xFFF8F9FA), // Light grey background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // 1. Profile Header
              if (userId == null)
                const CircularProgressIndicator()
              else
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client
                      .from('users')
                      .stream(primaryKey: ['id'])
                      .eq('id', userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Column(
                        children: [
                          Text("User", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text("No extra details found", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      );
                    }
                    
                    var userData = snapshot.data!.first;
                    String name = userData['name'] ?? 'User';
                    String detail = userData['email'] ?? userData['phone'] ?? 'No contact info';
                    String profileImg = userData['profile_image'] ?? "https://ui-avatars.com/api/?name=$name&background=FF9A44&color=fff";

                    return Column(
                      children: [
                        // Profile Avatar
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: NetworkImage(profileImg),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          detail,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),

              // 2. Stats Row (Wallet, Orders, etc.)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: userId == null 
                      ? const Stream.empty() 
                      : Supabase.instance.client.from('orders').stream(primaryKey: ['id']).eq('user_id', userId!),
                  builder: (context, orderSnapshot) {
                    final orderCount = orderSnapshot.data?.length ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: userId == null
                              ? const Stream.empty()
                              : Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('id', userId!),
                          builder: (context, userSnapshot) {
                            double walletBalance = 0.0;
                            if (userSnapshot.hasData && userSnapshot.data!.isNotEmpty) {
                              var userData = userSnapshot.data!.first;
                              walletBalance = double.tryParse(userData['wallet_balance']?.toString() ?? '0') ?? 0.0;
                            }
                            return _buildStatItem(
                              "Wallet",
                              "₹${walletBalance.toStringAsFixed(2)}",
                              Icons.account_balance_wallet_outlined,
                              onTap: () => _showAddMoneyModal(context, walletBalance),
                              showAddButton: true,
                            );
                          }
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[200]),
                        _buildStatItem(
                          "Orders",
                          orderCount.toString(),
                          Icons.shopping_bag_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OrdersPage()),
                            );
                          },
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[200]),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: userId == null
                              ? const Stream.empty()
                              : Supabase.instance.client
                                  .from('user_favorites')
                                  .stream(primaryKey: ['id']).eq('user_id', userId!),
                          builder: (context, favSnapshot) {
                            final favCount = favSnapshot.data?.length ?? 0;
                            return _buildStatItem(
                              "Favorites", 
                              favCount.toString(), 
                              Icons.favorite_border,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  }
                ),
              ),
              const SizedBox(height: 30),

              // 3. Settings Groups
              _buildSectionHeader("Account"),
              _buildOptionItem(
                Icons.person_outline, 
                "Personal Information",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PersonalInformationScreen()),
                  );
                }
              ),
              _buildOptionItem(
                Icons.favorite_border,
                "My Favorites",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                  );
                }
              ),
              _buildOptionItem(
                Icons.shopping_bag_outlined, 
                "My Orders", 
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const OrdersPage()),
                  );
                }
              ),
              _buildOptionItem(
                Icons.map_outlined, 
                "Addresses",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddressesScreen()),
                  );
                }
              ),
              _buildOptionItem(
                Icons.payment, 
                "Payment Methods",
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
                  );
                }
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("App Settings"),
              const SizedBox(height: 10),

              // Switch Item
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "Push Notifications",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      activeThumbColor: primaryColor,
                      onChanged: (val) =>
                          setState(() => _notificationsEnabled = val),
                    ),
                  ],
                ),
              ),
              _buildOptionItem(
                Icons.language,
                "Language",
                trailingText: context.watch<PreferencesProvider>().appLanguage,
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LanguageScreen()),
                  );
                }
              ),

              const SizedBox(height: 20),
              _buildSectionHeader("Support"),
              const SizedBox(height: 10),
              _buildOptionItem(
                Icons.help_outline, 
                "Help Center",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpCentreScreen()),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 4. Logout Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFFF8A80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FoodAppLoginPage(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          "Log Out",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 120), // ADDED PADDING TO FIX OUT-OF-SCREEN ISSUE
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  // --- Methods ---

  void _showAddMoneyModal(BuildContext context, double currentBalance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add Money to Wallet",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Current Balance: ₹${currentBalance.toStringAsFixed(2)}",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text("Select Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountChip(100),
                _buildAmountChip(500),
                _buildAmountChip(1000),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  "Top Up Now",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(int amount) {
    return InkWell(
      onTap: () {
        _addMoneyToWallet(amount.toDouble());
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("₹$amount added to your wallet!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.25,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            "₹$amount",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _addMoneyToWallet(double amount) async {
    if (userId == null) return;
    
    try {
      // Fetch current balance first
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('wallet_balance')
          .eq('id', userId!)
          .single();
      
      double currentBalance = double.tryParse(userResponse['wallet_balance']?.toString() ?? '0') ?? 0.0;
      double newBalance = currentBalance + amount;

      await Supabase.instance.client
          .from('users')
          .update({'wallet_balance': newBalance})
          .eq('id', userId!);
          
    } catch (e) {
      debugPrint("Error adding money: $e");
    }
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {VoidCallback? onTap, bool showAddButton = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(icon, color: Colors.grey[400], size: 24),
                if (showAddButton)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFE724C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, {String? trailingText, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF1A1D26), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1D26),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailingText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      trailingText,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
