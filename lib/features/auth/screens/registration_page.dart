import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gusto/features/auth/screens/location_picker_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gusto/features/home/screens/root_screen.dart';

class RegisterPage extends StatefulWidget {
  final String phone;
  const RegisterPage({super.key, required this.phone});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  bool loading = false;
  final Color primaryOrange = const Color(
    0xFFFF7622,
  ); // Vibrant food app orange
  final Color bgGrey = const Color(0xFFF6F6F6);
  LatLng? selectedLocation;
  Placemark? selectedPlacemark;
  String? selectedHouseNo;
  String? selectedLandmark;
  String? selectedLabel;
  String addressText = "No location selected";

  Future<void> registerUser() async {
    // 2. Form Validation
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      _message("Please fill all fields");
      return;
    }

    if (selectedLocation == null || selectedPlacemark == null) {
      _message("Please select a delivery location on the map");
      return;
    }

    setState(() => loading = true);

    try {
      Placemark place = selectedPlacemark!;
      LatLng position = selectedLocation!;

      // 7. Write to Supabase - User Table
      final userResponse = await Supabase.instance.client.from('users').insert({
        "phone": "+91${widget.phone}",
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
      }).select();

      final newUserId = userResponse.first['id'] as String;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', newUserId);
      await prefs.setBool('isLoggedIn', true);

      // 8. Write to Supabase - Addresses Table
      await Supabase.instance.client.from('user_addresses').insert({
        "user_id": newUserId,
        "full_address": "${place.name}, ${place.subLocality}, ${place.locality}",
        "landmark": selectedLandmark,
        "latitude": position.latitude,
        "longitude": position.longitude,
        "is_default": true,
      });

      _message("Registration Successful!");

      // Navigate away after success
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RootScreen()),
        );
      }
    } catch (e) {
      _message("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Orange Wave or Design
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Personal Details",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Help us deliver your food faster!",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("NAME"),
                  _inputField(
                    "Enter your full name",
                    nameController,
                    Icons.person_rounded,
                  ),

                  const SizedBox(height: 25),

                  _sectionLabel("EMAIL"),
                  _inputField(
                    "Enter your email",
                    emailController,
                    Icons.email_rounded,
                  ),

                  const SizedBox(height: 25),

                  _sectionLabel("PHONE NUMBER"),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: bgGrey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      widget.phone,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Location Selection Button
                  _sectionLabel("DELIVERY LOCATION"),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocationPickerScreen(),
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          selectedLocation = result['position'];
                          selectedPlacemark = result['placemark'];
                          selectedHouseNo = result['houseNo'];
                          selectedLandmark = result['landmark'];
                          selectedLabel = result['label'];
                          // We don't really need addressText here if we display Placemark components directly
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: selectedLocation == null ? bgGrey : Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: selectedLocation == null ? Colors.transparent : Colors.orange.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selectedLocation == null ? Colors.grey.shade300 : Colors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedLocation == null ? Icons.location_on_outlined : Icons.my_location, 
                              color: selectedLocation == null ? Colors.grey.shade600 : primaryOrange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: selectedLocation == null 
                                ? const Text(
                                    "Tap to choose on map",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedPlacemark?.name ?? "Selected Location",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          selectedPlacemark?.street,
                                          selectedPlacemark?.subLocality,
                                          selectedPlacemark?.locality,
                                        ].where((e) => e != null && e.isNotEmpty).join(", "),
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                                      ),
                                    ],
                                  ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Final Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: loading ? null : registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "VERIFY & LOGIN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: primaryOrange, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
