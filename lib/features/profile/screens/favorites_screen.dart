import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../restaurant/screens/restaurant_menu_page.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? userId;
  List<Map<String, dynamic>> _favoriteRestaurants = [];
  bool _isLoading = true;

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
    if (userId != null) {
      _fetchFavorites();
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('restaurant_id, restaurants (*)')
          .eq('user_id', userId!);

      setState(() {
        _favoriteRestaurants = List<Map<String, dynamic>>.from(
            response.map((item) => item['restaurants'] as Map<String, dynamic>));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String restaurantId) async {
    try {
      await Supabase.instance.client
          .from('user_favorites')
          .delete()
          .match({'user_id': userId!, 'restaurant_id': restaurantId});

      setState(() {
        _favoriteRestaurants.removeWhere((r) => r['id'] == restaurantId);
      });
    } catch (e) {
      debugPrint("Error removing favorite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Favorites", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFE724C)))
          : _favoriteRestaurants.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteRestaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = _favoriteRestaurants[index];
                    return _buildRestaurantCard(restaurant);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No favorites yet", style: TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 8),
          const Text("Heart your favorite restaurants to see them here!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            restaurant['image_url'] ?? 'https://via.placeholder.com/100',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(restaurant['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(restaurant['rating']?.toString() ?? '4.5'),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(restaurant['delivery_time'] ?? '30 min'),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _removeFavorite(restaurant['id']),
        ),
        onTap: () {
          // Navigate to restaurant menu
        },
      ),
    );
  }
}
