import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gusto/features/auth/screens/location_picker_screen.dart';
import 'package:gusto/core/widgets/skeleton_loader.dart';
import 'package:gusto/features/notifications/screens/notification_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:gusto/core/providers/preferences_provider.dart';
import 'package:gusto/core/utils/icon_helper.dart';
import 'package:gusto/features/home/widgets/restaurant_card.dart';
import 'package:gusto/features/home/widgets/top_product_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // =========================
  // DATA
  // =========================
  String? selectedCategory;
  String _searchQuery = '';

  bool _isListening = false;
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<String> bannerImages = [
    "images/food.jpg", // Ensure these assets exist
    "images/food.jpg",
    "images/food.jpg",
  ];

  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  String? userId;
  bool _isFetchingLocation = false; // Lock to prevent multi-clicks
  Map<String, dynamic>? _optimisticAddress; // For instant UI updates 📍

  // Favorites State
  final Set<String> _favoriteRestaurantIds = {};

  // User location for distance-based filtering (5km)
  double? _userLat;
  double? _userLng;

  // Nearby restaurant IDs & their menu categories (location-aware)
  Set<String> _nearbyRestaurantIds = {};
  Set<String> _nearbyMenuCategories = {};

  // High Performance State
  List<Map<String, dynamic>> _processedRestaurants = [];
  bool _isProcessing = false;
  List<Map<String, dynamic>>? _rawRestaurantsCache;

  // Persisted Streams to prevent UI freezing on setState
  Stream<List<Map<String, dynamic>>>? _addressesStream;
  late final Stream<List<Map<String, dynamic>>> _categoriesStream;
  late final Stream<List<Map<String, dynamic>>> _restaurantsStream;

  @override
  void initState() {
    super.initState();

    // Initialize standard streams ONCE
    _categoriesStream = Supabase.instance.client
        .from('categories')
        .stream(primaryKey: ['id'])
        .order('sort_order', ascending: true);

    _restaurantsStream = Supabase.instance.client
        .from('restaurants')
        .stream(primaryKey: ['id']);

    _loadUser();

    // Auto-scroll banner logic
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final next = (_pageController.page?.round() ?? 0) + 1;
        _pageController.animateToPage(
          next % bannerImages.length,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });

    // Status Bar Style Changer (Optimized: only fire on state change)
    bool isStatusDark = false;
    _scrollController.addListener(() {
      final double offset = _scrollController.offset;
      if (offset > 200 && !isStatusDark) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
        isStatusDark = true;
      } else if (offset <= 200 && isStatusDark) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        );
        isStatusDark = false;
      }
    });

    // Subscribe to restaurant stream for background processing
    _restaurantsStream.listen((data) {
      if (mounted) {
        _rawRestaurantsCache = data;
        _reprocessRestaurants();
      }
    });
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final newUserId = prefs.getString('uid');

    setState(() {
      userId = newUserId;
      if (userId != null) {
        // Initialize user-dependent streams ONCE
        _addressesStream = Supabase.instance.client
            .from("user_addresses")
            .stream(primaryKey: ['id'])
            .eq('user_id', userId!);
      } else {
        _addressesStream = null;
      }
    });

    if (userId != null) {
      _fetchFavorites();
      _fetchDefaultLocation();
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('restaurant_id')
          .eq('user_id', userId!);

      if (mounted) {
        setState(() {
          _favoriteRestaurantIds.clear();
          for (var item in response) {
            _favoriteRestaurantIds.add(item['restaurant_id'] as String);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
    }
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to add favorites!")),
      );
      return;
    }

    final isCurrentlyFavorite = _favoriteRestaurantIds.contains(restaurantId);

    // 1. Optimistic UI Update
    setState(() {
      if (isCurrentlyFavorite) {
        _favoriteRestaurantIds.remove(restaurantId);
      } else {
        _favoriteRestaurantIds.add(restaurantId);
      }
    });

    // 2. Database Sync
    try {
      if (isCurrentlyFavorite) {
        await Supabase.instance.client.from('user_favorites').delete().match({
          'user_id': userId!,
          'restaurant_id': restaurantId,
        });
      } else {
        await Supabase.instance.client.from('user_favorites').upsert({
          'user_id': userId!,
          'restaurant_id': restaurantId,
        });
      }
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
      // Revert Optimistic Update on failure
      if (mounted) {
        setState(() {
          if (isCurrentlyFavorite) {
            _favoriteRestaurantIds.add(restaurantId);
          } else {
            _favoriteRestaurantIds.remove(restaurantId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update favorites.")),
        );
      }
    }
  }

  /// Fetch the default address and set user lat/lng for distance filtering
  Future<void> _fetchDefaultLocation() async {
    if (userId == null) return;
    try {
      final addresses = await Supabase.instance.client
          .from('user_addresses')
          .select()
          .eq('user_id', userId!)
          .eq('is_default', true)
          .limit(1);
      if (addresses.isNotEmpty && mounted) {
        final lat = (addresses.first['latitude'] as num?)?.toDouble();
        final lng = (addresses.first['longitude'] as num?)?.toDouble();
        setState(() {
          _userLat = lat;
          _userLng = lng;
        });
        _reprocessRestaurants();
        _refreshNearbyData();
      }
    } catch (e) {
      debugPrint('Error fetching default location: $e');
    }
  }

  /// Refresh nearby restaurant IDs and their available menu categories
  Future<void> _refreshNearbyData() async {
    if (_userLat == null || _userLng == null) return;
    try {
      // Fetch all restaurants
      final allRestaurants = await Supabase.instance.client
          .from('restaurants')
          .select('id, latitude, longitude');

      // Filter by 5km distance
      final nearbyIds = <String>{};
      for (final r in allRestaurants) {
        final rLat = (r['latitude'] as num?)?.toDouble();
        final rLng = (r['longitude'] as num?)?.toDouble();
        if (rLat == null || rLng == null) continue;
        if (_calculateDistance(_userLat!, _userLng!, rLat, rLng) <= 5000) {
          nearbyIds.add(r['id'].toString());
        }
      }

      if (nearbyIds.isEmpty) {
        if (mounted) {
          setState(() {
            _nearbyRestaurantIds = nearbyIds;
            _nearbyMenuCategories = {};
          });
        }
        return;
      }

      // Fetch distinct menu categories from nearby restaurants
      final menuItems = await Supabase.instance.client
          .from('menu_items')
          .select('category')
          .inFilter('restaurant_id', nearbyIds.toList());

      final categories = <String>{};
      for (final item in menuItems) {
        final cat = item['category']?.toString();
        if (cat != null && cat.isNotEmpty) categories.add(cat);
      }

      if (mounted) {
        setState(() {
          _nearbyRestaurantIds = nearbyIds;
          _nearbyMenuCategories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing nearby data: $e');
    }
  }

  /// Haversine formula — calculates distance in meters between two lat/lng points
  Future<void> _reprocessRestaurants() async {
    if (_rawRestaurantsCache == null) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final restaurants = await compute(_processRestaurantsBackground, {
        'all': _rawRestaurantsCache!,
        'query': _searchQuery,
        'userLat': _userLat,
        'userLng': _userLng,
      });
      
      if (mounted) {
        setState(() {
          _processedRestaurants = restaurants;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint("Processing Error: $e");
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _changeLocation() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to change address")),
      );
      return;
    }

    if (_isFetchingLocation) return; // Prevent multi-clicks

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final addresses = await Supabase.instance.client
          .from("user_addresses")
          .select()
          .eq("user_id", userId!);

      if (!mounted) return;

      _showAddressSelectionSheet(List<Map<String, dynamic>>.from(addresses));
    } catch (e) {
      debugPrint("Error fetching addresses: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _showAddressSelectionSheet(List<Map<String, dynamic>> userAddresses) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Delivery Address",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: userAddresses.map((addr) {
                    final isSelected = addr['is_default'] == true;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);

                        // 🏎️ Optimistic Update + Location
                        setState(() {
                          _optimisticAddress = addr;
                          _userLat = (addr['latitude'] as num?)?.toDouble();
                          _userLng = (addr['longitude'] as num?)?.toDouble();
                          selectedCategory =
                              null; // Reset category on address change
                        });
                        _refreshNearbyData();

                        // Make this address the default in the DB
                        if (userId != null) {
                          try {
                            await Supabase.instance.client
                                .from('user_addresses')
                                .update({'is_default': false})
                                .eq('user_id', userId!);
                            await Supabase.instance.client
                                .from('user_addresses')
                                .update({'is_default': true})
                                .eq('id', addr['id']);
                          } catch (e) {
                            debugPrint("Error updating address: $e");
                            if (mounted) {
                              setState(() {
                                _optimisticAddress = null;
                              });
                            }
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFE724C).withValues(alpha: 0.04)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFE724C).withValues(alpha: 0.5)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            if (!isSelected)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFFFE724C,
                                      ).withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                addr['label']?.toString().toLowerCase() ==
                                        'home'
                                    ? Icons.home_rounded
                                    : addr['label']?.toString().toLowerCase() ==
                                          'work'
                                    ? Icons.work_rounded
                                    : Icons.location_on_rounded,
                                color: isSelected
                                    ? const Color(0xFFFE724C)
                                    : Colors.grey.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr['label'] ?? 'Address',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Spacer(),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFFFE724C),
                                          size: 22,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    addr['full_address'] ??
                                        'No Address Details',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _addNewAddress();
                },
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                label: const Text(
                  "Add New Address",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFE724C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: const Color(0xFFFE724C).withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null) {
      LatLng position = result['position'];
      Placemark place = result['placemark'];
      String houseNo = result['houseNo'] ?? "";
      String landmark = result['landmark'] ?? "";

      String fullAddress = [
        houseNo,
        place.name,
        place.subLocality,
        place.locality,
      ].where((e) => e != null && e.toString().isNotEmpty).join(", ");

      try {
        if (userId != null) {
          // Unset all previous defaults
          await Supabase.instance.client
              .from('user_addresses')
              .update({'is_default': false})
              .eq('user_id', userId!);

          final newAddr = {
            "user_id": userId!,
            "landmark": landmark,
            "full_address": fullAddress,
            "is_default": true,
            "latitude": position.latitude,
            "longitude": position.longitude,
          };

          // 🏎️ Optimistic Update + Location
          if (mounted) {
            setState(() {
              _optimisticAddress = newAddr;
              _userLat = position.latitude;
              _userLng = position.longitude;
              selectedCategory = null;
            });
            _refreshNearbyData();
          }

          // Add this new address as the default
          await Supabase.instance.client.from("user_addresses").insert(newAddr);

          // Clear optimistic override once DB sync is reflected
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            setState(() {
              _optimisticAddress = null;
            });
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Address added successfully!",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error adding address: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Failed to add address",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToSpeech() async {
    if (!_isListening) {
      // INSTANT UI FEEDBACK
      setState(() => _isListening = true);

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint('onError: $val');
          setState(() => _isListening = false);
        },
      );
      if (available) {
        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
              _searchQuery = val.recognizedWords;
            });
            _reprocessRestaurants();
          },
        );
      } else {
        setState(() => _isListening = false);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<List<int>> dp = List.generate(
      a.length + 1,
      (i) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) dp[i][0] = i;
    for (int j = 0; j <= b.length; j++) dp[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[a.length][b.length];
  }

  bool _isFuzzyMatch(String target, String query) {
    target = target.toLowerCase();
    query = query.toLowerCase();

    if (target.contains(query)) return true;
    if (target.replaceAll(' ', '').contains(query.replaceAll(' ', '')))
      return true;

    List<String> targetWords = target.split(' ');
    List<String> queryWords = query.split(' ');

    for (String qWord in queryWords) {
      if (qWord.length < 3) continue;
      bool wordMatched = false;
      for (String tWord in targetWords) {
        if (_levenshteinDistance(tWord, qWord) <= (qWord.length <= 4 ? 1 : 2)) {
          wordMatched = true;
          break;
        }
      }
      if (wordMatched) return true;
    }

    return false;
  }

  // --- BACKGROUND PROCESSING (ISOLATE READY) ---
  static List<Map<String, dynamic>> _processRestaurantsBackground(
    Map<String, dynamic> params,
  ) {
    final List<Map<String, dynamic>> all = params['all'];
    final String query = params['query'];
    final double? userLat = params['userLat'];
    final double? userLng = params['userLng'];

    var restaurants = List<Map<String, dynamic>>.from(all);

    // 0. Image Filter: Remove restaurants without images
    restaurants = restaurants.where((r) {
      final imageUrl = r['image']?.toString() ?? '';
      return imageUrl.isNotEmpty;
    }).toList();

    // 1. Search Filter
    if (query.isNotEmpty) {
      restaurants = restaurants.where((r) {
        final name = r['name']?.toString().toLowerCase() ?? '';
        final tags = (r['tags'] as List<dynamic>?)?.join(' ').toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) || tags.contains(query.toLowerCase());
      }).toList();
    }

    // 2. Distance Calculation
    if (userLat != null && userLng != null) {
      for (var r in restaurants) {
        final rLat = (r['latitude'] as num?)?.toDouble();
        final rLng = (r['longitude'] as num?)?.toDouble();
        if (rLat != null && rLng != null) {
          final double dLat = (rLat - userLat) * (pi / 180);
          final double dLng = (rLng - userLng) * (pi / 180);
          final double a = sin(dLat / 2) * sin(dLat / 2) +
              cos(userLat * (pi / 180)) *
                  cos(rLat * (pi / 180)) *
                  sin(dLng / 2) *
                  sin(dLng / 2);
          final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
          r['_distance'] = 6371 * c * 1000; // in meters
        } else {
          r['_distance'] = double.infinity;
        }
      }

      // 3. Distance Filter
      restaurants = restaurants
          .where((r) => (r['_distance'] as double) <= 5000)
          .toList();

      // 4. Final Sort
      restaurants.sort((a, b) {
        final aOpen = a['is_open'] != false;
        final bOpen = b['is_open'] != false;
        if (aOpen != bOpen) return aOpen ? -1 : 1;
        final double aDist = a['_distance'];
        final double bDist = b['_distance'];
        return aDist.compareTo(bDist);
      });
    } else {
      restaurants.sort((a, b) {
        final aOpen = a['is_open'] != false;
        final bOpen = b['is_open'] != false;
        return aOpen ? -1 : 1;
      });
    }

    return restaurants;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF5F6F8), // Light grey background
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // =========================
            // 1. MODERN HEADER (No Images)
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(
                0xFFF5F6F8,
              ), // Matches scaffold background
              elevation: 0,
              toolbarHeight: 90,
              // 1. DELETE titlePadding. USE titleSpacing: 0 INSTEAD.
              titleSpacing: 0,
              // 2. WRAP YOUR ROW IN A PADDING WIDGET
              title: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Location Details
                    Expanded(
                      child: GestureDetector(
                        onTap: _changeLocation,
                        child: Container(
                          color: Colors
                              .transparent, // Ensures the whole area is clickable
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.orange,
                                    size: 22,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Home",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.orange,
                                    size: 22,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _addressesStream,
                                  builder: (context, snapshot) {
                                    String addressText = "Loading address...";
                                    if (userId == null) {
                                      addressText =
                                          "Please log in to see address";
                                    } else if (snapshot.hasError &&
                                        !snapshot.hasData &&
                                        _optimisticAddress == null) {
                                      addressText =
                                          "Failed to load address: ${snapshot.error}";
                                    } else if (snapshot.hasData ||
                                        _optimisticAddress != null) {
                                      final docs =
                                          snapshot.data
                                              ?.where(
                                                (d) => d['is_default'] == true,
                                              )
                                              .toList() ??
                                          [];

                                      final data =
                                          _optimisticAddress ??
                                          (docs.isNotEmpty ? docs.first : null);

                                      if (data != null) {
                                        addressText =
                                            "${data['full_address'] ?? 'No address'} • 30 mins";
                                      } else if (snapshot.hasData) {
                                        addressText =
                                            "No default address found";
                                      } else {
                                        addressText = "Loading address...";
                                      }
                                    }
                                    return Text(
                                      addressText,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Modern Notification Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Badge(
                          backgroundColor: Colors.redAccent,
                          smallSize: 10,
                          child: Icon(
                            Icons.notifications_outlined,
                            color: Colors.black87,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================
            // 2. PERSISTENT SEARCH BAR
            // =========================
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarHeader(
                searchController: _searchController,
                isListening: _isListening,
                onMicTap: _listenToSpeech,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                  _reprocessRestaurants();
                },
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SliverToBoxAdapter(child: _OfferCardsSection()),
              // =========================
              // 3. CATEGORIES SECTION
              // =========================
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Text(
                    "What's on your mind?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _categoriesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        if (snapshot.hasError) {
                          debugPrint(
                            "Categories Stream Error: ${snapshot.error}",
                          );
                        }
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 5,
                          separatorBuilder: (c, i) => const SkeletonCategory(),
                          itemBuilder: (context, index) =>
                              const SkeletonCategory(),
                        );
                      }

                      const allowedCategories = [
                        'All',
                        'Combos',
                        'Burger',
                        'Pizza',
                        'Starters',
                        'Main Course',
                        'Beverages',
                        'Desserts',
                        'Healthy',
                      ];

                      // Filter categories: only show ones available in nearby restaurants
                      final categoriesList =
                          snapshot.data?.where((c) {
                            if (c['is_active'] != true) return false;
                            final catName = c['name']?.toString() ?? '';
                            if (!allowedCategories.contains(catName))
                              return false;
                            // 'All' always shown; others only if nearby menus have them
                            if (catName == 'All') return true;
                            if (_nearbyMenuCategories.isEmpty &&
                                _userLat == null)
                              return true; // No location yet, show all
                            return _nearbyMenuCategories.contains(catName);
                          }).toList() ??
                          [];

                      // Sort by the order in allowedCategories
                      categoriesList.sort(
                        (a, b) => allowedCategories
                            .indexOf(a['name'])
                            .compareTo(allowedCategories.indexOf(b['name'])),
                      );

                      if (categoriesList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "No categories available nearby",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categoriesList.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final item = categoriesList[index];
                          final String categoryName = item["name"] ?? 'Unknown';
                          final bool isSelected =
                              selectedCategory == categoryName;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selectedCategory == categoryName) {
                                  selectedCategory = null; // Toggle off
                                } else {
                                  selectedCategory = categoryName;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              transform: isSelected
                                  ? Matrix4.diagonal3Values(1.1, 1.1, 1.0)
                                  : Matrix4.identity(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.orange,
                                              width: 2,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? Colors.orange.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.15),
                                          blurRadius: isSelected ? 15 : 10,
                                          offset: isSelected
                                              ? const Offset(0, 6)
                                              : const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      IconHelper.getIcon(
                                        item["icon_name"] ?? '',
                                      ),
                                      color: IconHelper.getColor(
                                        item["color_hex"] ?? '#000000',
                                      ),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // =========================
            // 4. RESTAURANT LIST
            // =========================
            if (selectedCategory == null || selectedCategory == 'All') ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        "All Restaurants",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.sort, size: 18),
                      SizedBox(width: 4),
                      Text(
                        "Sort",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              // --- HIGH PERFORMANCE LIST ---
              if (_isProcessing && _processedRestaurants.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const SkeletonRestaurantCard(),
                    childCount: 3,
                  ),
                )
              else if (_processedRestaurants.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Icon(
                            Icons.location_off_rounded,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userLat != null
                                ? "No restaurants within 5 km of your location"
                                : "Select an address to see nearby restaurants",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_userLat != null)
                            Text(
                              "Try changing your delivery address",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final restaurant = _processedRestaurants[index];
                    final isFavorite = _favoriteRestaurantIds.contains(
                      restaurant['id'],
                    );

                    return RestaurantCard(
                      restaurant: restaurant,
                      index: index,
                      isFavorite: isFavorite,
                      onToggleFavorite: () => _toggleFavorite(restaurant['id']),
                    );
                  }, childCount: _processedRestaurants.length),
                ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    children: [
                      Text(
                        "Top Rated ${selectedCategory!}s",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _nearbyRestaurantIds.isNotEmpty
                    ? Supabase.instance.client
                          .from('menu_items')
                          .select('*, restaurants(name, id, is_open)')
                          .eq('category', selectedCategory!)
                          .inFilter(
                            'restaurant_id',
                            _nearbyRestaurantIds.toList(),
                          )
                          .order('rating', ascending: false)
                          .limit(20)
                    : Supabase.instance.client
                          .from('menu_items')
                          .select('*, restaurants(name, id, is_open)')
                          .eq('category', selectedCategory!)
                          .order('rating', ascending: false)
                          .limit(20),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const SkeletonRestaurantCard(),
                        childCount: 3,
                      ),
                    );
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Text(
                            "No ${selectedCategory!.toLowerCase()} items found nearby.",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  final items = snapshot.data!;
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = items[index];
                        final restaurantData = item['restaurants'];
                        final restaurantName = restaurantData != null
                            ? restaurantData['name']?.toString() ??
                                  'Unknown Restaurant'
                            : 'Unknown Restaurant';
                        final isVeg = item['is_veg'] == true;

                        return TopProductCard(
                          menuItem: item,
                          restaurantName: restaurantName,
                          isVeg: isVeg,
                        );
                      }, childCount: items.length),
                    ),
                  );
                },
              ),
            ],

            // Bottom Padding for FAB/Nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        // Assuming you have this file, otherwise remove
      ),
    );
  }
}

// =========================
// WIDGETS
// =========================

/// The Header Delegate handles the search bar sticking
class _SearchBarHeader extends SliverPersistentHeaderDelegate {
  final ValueChanged<String>? onChanged;
  final TextEditingController? searchController;
  final VoidCallback? onMicTap;
  final bool isListening;

  _SearchBarHeader({
    this.onChanged,
    this.searchController,
    this.onMicTap,
    this.isListening = false,
  });

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF5F6F8), // Matches Scaffold background perfectly
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), // Soft modern shadow
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isListening ? Icons.graphic_eq : Icons.search,
              color: isListening ? Colors.redAccent : Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 10),

            // SEARCH FIELD
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: isListening ? "Listening..." : "Search for food...",
                  hintStyle: TextStyle(
                    color: isListening
                        ? Colors.redAccent.withValues(alpha: 0.6)
                        : Colors.grey.shade400,
                    fontSize: 15,
                    fontStyle: isListening
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            // MIC BUTTON
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: isListening ? Colors.red : Colors.orange,
                size: 24,
              ),
              onPressed: onMicTap,
            ),

            // VERTICAL DIVIDER
            Container(
              height: 24,
              width: 1.5,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),

            // VEG SWITCH (Your original logic, styled)
            Consumer<PreferencesProvider>(
              builder: (context, prefs, child) {
                final isVegMode = prefs.isVegMode;
                return GestureDetector(
                  onTap: () {
                    prefs.toggleVegMode();
                  },
                  child: Row(
                    children: [
                      Text(
                        "Veg",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isVegMode
                              ? Colors.green
                              : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 20,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isVegMode
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          border: Border.all(
                            color: isVegMode
                                ? Colors.green
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          alignment: isVegMode
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isVegMode
                                  ? Colors.green
                                  : Colors.grey.shade400,
                            ),
                            child: isVegMode
                                ? const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _OfferCardsSection extends StatelessWidget {
  const _OfferCardsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('offers')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Offers Fetch Error: ${snapshot.error}");
            return const SizedBox.shrink();
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 2,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => const SkeletonLoader(
                width: 280,
                height: 160,
                borderRadius: 20,
              ),
            );
          }

          final offersList = snapshot.data ?? [];
          if (offersList.isEmpty) return const SizedBox.shrink();

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: offersList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final offer = offersList[index];
              final Color c1 = IconHelper.getColor(
                offer['color_start_hex'] ?? '#FF9A44',
              );
              final Color c2 = IconHelper.getColor(
                offer['color_end_hex'] ?? '#FC6076',
              );
              final IconData icon = IconHelper.getIcon(
                offer['icon_name'] ?? 'local_pizza',
              );

              return CustomPaint(
                painter: TicketPainter(color1: c1, color2: c2),
                child: Container(
                  width: 280,
                  height: 160,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                "SPECIAL OFFER",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              offer["title"] ?? "Get 50% OFF",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer["subtitle"] ?? "On your first order",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 40, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TicketPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  TicketPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color1, color2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    const double cutoutRadius = 12.0;
    const double dashWidth = 5.0;
    const double dashSpace = 3.0;

    final path = Path()
      ..moveTo(0, 20)
      ..quadraticBezierTo(0, 0, 20, 0)
      ..lineTo(size.width - 20, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 20)
      // Right cutout
      ..lineTo(size.width, size.height / 2 - cutoutRadius)
      ..arcToPoint(
        Offset(size.width, size.height / 2 + cutoutRadius),
        radius: const Radius.circular(cutoutRadius),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - 20)
      ..quadraticBezierTo(size.width, size.height, size.width - 20, size.height)
      ..lineTo(20, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 20)
      // Left cutout
      ..lineTo(0, size.height / 2 + cutoutRadius)
      ..arcToPoint(
        Offset(0, size.height / 2 - cutoutRadius),
        radius: const Radius.circular(cutoutRadius),
        clockwise: false,
      )
      ..close();

    canvas.drawShadow(path, Colors.black, 8, true);
    canvas.drawPath(path, paint);

    // Optional: Add a dotted line across the ticket
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startY = cutoutRadius + 10;
    while (startY < size.height - cutoutRadius - 10) {
      canvas.drawLine(
        Offset(size.width * 0.7, startY),
        Offset(size.width * 0.7, startY + dashWidth),
        dashPaint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
