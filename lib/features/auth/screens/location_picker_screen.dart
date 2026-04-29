import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _currentAddress = "Locating...";
  Placemark? _selectedPlacemark;

  // Autocomplete state
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placePredictions = [];
  Timer? _debounce;
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _fetchPlaceAutocomplete(query);
      } else {
        setState(() {
          _placePredictions = [];
        });
      }
    });
  }

  Future<void> _fetchPlaceAutocomplete(String input) async {
    final String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          setState(() {
            _placePredictions = result['predictions'];
          });
        } else {
          setState(() {
            _placePredictions = [];
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorAndReturn("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorAndReturn("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorAndReturn("Location permissions are permanently denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    _getAddressFromLatLng(_currentPosition!);
  }

  void _showErrorAndReturn(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    Navigator.pop(context);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // We will use the placemark directly in UI to build the parts beautifully.
          _selectedPlacemark = place;
          // Build a short fallback address just in case
          List<String> parts = [];
          if (place.name != null && place.name!.isNotEmpty) {
            parts.add(place.name!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            parts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
          }
          _currentAddress = parts.join(", ");
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
  }

  void _onCameraIdle() {
    if (_currentPosition != null) {
      _getAddressFromLatLng(_currentPosition!);
    }
  }

  Future<void> _searchAndNavigateToAddress(String query) async {
    if (query.trim().isEmpty) return;
    try {
      FocusScope.of(context).unfocus(); // Close keyboard
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Searching for '$query'..."), duration: const Duration(seconds: 1)),
      );

      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final GoogleMapController mapController = await _controller.future;
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc.latitude, loc.longitude),
              zoom: 17,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not find location '$query'")),
      );
    }
  }

  void _showAddressDetailsSheet() {
    if (_currentPosition == null || _selectedPlacemark == null) return;

    String houseNo = "";
    String landmark = "";
    String selectedLabel = "Home"; // Default

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 25,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter Complete Address",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        labelText: "House / Flat / Block No.",
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFE724C), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (val) => houseNo = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        labelText: "Landmark (Optional)",
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFE724C), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (val) => landmark = val,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Save As",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ["Home", "Work", "Other"].map((label) {
                        final isSelected = selectedLabel == label;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFE724C),
                            backgroundColor: const Color(0xFFF5F6F8),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFFFE724C) : Colors.transparent,
                              )
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedLabel = label);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFE724C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0xFFFE724C).withValues(alpha: 0.4),
                        ),
                        onPressed: () {
                          if (houseNo.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter House/Flat No."),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          Navigator.pop(context, {
                            'position': _currentPosition,
                            'placemark': _selectedPlacemark,
                            'houseNo': houseNo,
                            'landmark': landmark,
                            'label': selectedLabel,
                          });
                        },
                        child: const Text(
                          "Save Address",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Choose Delivery Location',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text("Locating you...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 17,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),

                // SEARCH BAR & SUGGESTIONS OVERLAY
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _searchAndNavigateToAddress,
                          decoration: InputDecoration(
                            hintText: "Search for a city or area...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.search, color: Colors.orange),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      if (_placePredictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: _placePredictions.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final prediction = _placePredictions[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.grey),
                                title: Text(
                                  prediction['description'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  _searchController.text = prediction['description'];
                                  setState(() => _placePredictions = []);
                                  _searchAndNavigateToAddress(prediction['description']);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // Beautiful Custom Center Marker
                if (MediaQuery.of(context).viewInsets.bottom == 0 && _placePredictions.isEmpty)
                  Positioned(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 40.0,
                    ), // Offset to point to exact center
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Text(
                            "Order Here",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Icon(Icons.location_on, size: 45, color: Colors.orange),
                      ],
                    ),
                  ),
                ),

                // Floating My Location Button
                Positioned(
                  bottom: 300,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    child: const Icon(Icons.my_location, color: Colors.orange),
                    onPressed: () async {
                      Position pos = await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                      );
                      final GoogleMapController mapController =
                          await _controller.future;
                      mapController.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: LatLng(pos.latitude, pos.longitude),
                            zoom: 17,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Floating Bottom Address Confirm Box
                if (MediaQuery.of(context).viewInsets.bottom == 0 && _placePredictions.isEmpty)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.orange,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Delivery Address",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedPlacemark?.name ??
                                        "Getting name...",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Detailed Sub-components Breakdown
                        if (_selectedPlacemark != null) ...[
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [
                                        _selectedPlacemark!.street,
                                        _selectedPlacemark!.subLocality,
                                        _selectedPlacemark!.locality,
                                      ]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(", "),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.public,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [
                                        _selectedPlacemark!.administrativeArea,
                                        _selectedPlacemark!.country,
                                      ]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(", "),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            _currentAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFE724C),
                              elevation: 6,
                              shadowColor: const Color(0xFFFE724C).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _showAddressDetailsSheet,
                            child: const Text(
                              "Enter Complete Address",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
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
}
