import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gusto/features/home/screens/root_screen.dart';
import 'package:gusto/features/auth/screens/registration_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodAppLoginPage extends StatefulWidget {
  const FoodAppLoginPage({super.key});
  @override
  State<FoodAppLoginPage> createState() => _FoodAppLoginPageState();
}

class _FoodAppLoginPageState extends State<FoodAppLoginPage> {
  // Controller for the scrolling images
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController phoneController = TextEditingController();
  bool loading = false;

  // Data for the 3 scrollable images
  final List<Map<String, String>> _onboardingData = [
    {
      "image":
          "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1000&q=80",
      "title": "Delicious Pizza",
      "subtitle": "Hot and fresh, straight to your door.",
    },
    {
      "image":
          "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1000&q=80",
      "title": "Gourmet Steaks",
      "subtitle": "Experience fine dining at home.",
    },
    {
      "image":
          "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=1000&q=80",
      "title": "Healthy Salads",
      "subtitle": "Stay fit with our green choices.",
    },
  ];
  Future<void> sendOtp(BuildContext context) async {
    final phone = phoneController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10 digit number")),
      );
      return;
    }

    // --- MANUAL BYPASS FOR ALL NUMBERS ---
    // Check if user exists in Supabase first
    final data = await Supabase.instance.client
        .from("users")
        .select()
        .eq("phone", "+91$phone");

    bool userExists = data.isNotEmpty;
    String? existingUid;
    if (userExists) {
      existingUid = data.first['id'] as String;
    }

    if (!context.mounted) return;
    
    if (userExists && existingUid != null) {
      // Existing user: create session and go to Home
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', existingUid);
      await prefs.setBool('isLoggedIn', true);
      
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
      );
    } else {
      // New user: go to Registration
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterPage(phone: phone),
        ),
      );
    }
    return;
    // --- END MANUAL BYPASS ---
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen height to calculate ratios
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      // Allows the keyboard to push the content up without breaking layout
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ---------------------------------------------------
          // 1. TOP SECTION: Scrollable Images (65% of Screen)
          // ---------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.58,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _onboardingData.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // The Image
                        CachedNetworkImage(
                          imageUrl: _onboardingData[index]['image']!,
                          fit: BoxFit.cover,
                          // What to show while loading
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                            ),
                          ),
                          // What to show if the URL fails
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                          // Fade in animation when image loads
                          fadeInDuration: const Duration(milliseconds: 500),
                        ),
                        // Black Gradient Overlay (for text readability)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // Text on Image
                        Positioned(
                          bottom: 100, // Positioned above the white login sheet
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _onboardingData[index]['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _onboardingData[index]['subtitle']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Dot Indicators
                Positioned(
                  bottom: 50, // Just above the white sheet overlap
                  left: 20,
                  child: Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => buildDot(index),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------
          // 2. BOTTOM SECTION: Login Form (45% of Screen)
          // ---------------------------------------------------
          // ---------------------------------------------------
          // 2. BOTTOM SECTION: Phone Number Entry
          // ---------------------------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Text(
                      "Get Started",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Enter your phone number to continue",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),

                    const SizedBox(height: 30),

                    // Phone Number Field
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "Phone Number",
                        prefixIcon: const Icon(
                          Icons.phone_android,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: () {
                        sendOtp(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Login / Sign Up",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "By continuing, you agree to our",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => showTerms(context),
                          child: const Text("Terms & Conditions"),
                        ),

                        const Text("and"),

                        TextButton(
                          onPressed: () => showPolicy(context),
                          child: const Text("Privacy Policy"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the Dot Indicators
  Widget buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.deepOrange : Colors.white54,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

void showTerms(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Terms & Conditions",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 12),

            Text("""
• Users must provide accurate information.
• Orders once placed cannot be cancelled.
• Payments are non-refundable.
• Misuse may lead to account suspension.

(Add your real terms here)
"""),
          ],
        ),
      ),
    ),
  );
}

void showPolicy(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Privacy Policy",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 12),

            Text("""
We respect your privacy.

• Phone used only for login.
• Location used for delivery.
• Data never shared with third parties.

(Add your real policy here)
"""),
          ],
        ),
      ),
    ),
  );
}
