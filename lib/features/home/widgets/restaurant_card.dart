import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gusto/features/restaurant/screens/restaurant_menu_page.dart';

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final int index;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.index,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    // Supabase data
    final double rating = (restaurant['rating'] as num?)?.toDouble() ?? 4.0;
    final bool isExclusive = restaurant['is_exclusive'] == true;
    final String promoText = restaurant['promo_text'] ?? '';
    final bool hasPromo = promoText.isNotEmpty;
    final bool isOpen = restaurant['is_open'] != false;

    // Fallback for demo if no DB promo text exists yet
    final String displayPromo = hasPromo
        ? promoText
        : (index % 2 == 0 ? "50% OFF up to ₹80" : "");
    final bool showPromo = hasPromo || (index % 2 == 0);

    final String name = restaurant['name'] ?? "Unknown Restaurant";
    final String address = restaurant['address'] ?? "Unknown Location";

    const allowedTags = [
      'Combos',
      'Burger',
      'Pizza',
      'Starters',
      'Main Course',
      'Beverages',
      'Desserts',
      'Healthy',
    ];
    final List<dynamic> rawTagsList =
        restaurant['tags'] ?? restaurant['cuisine_tags'] ?? [];
    final List<String> tagsList = rawTagsList
        .where((tag) => allowedTags.contains(tag.toString()))
        .map((tag) => tag.toString())
        .toList();

    final String tags = tagsList.isNotEmpty ? tagsList.join(' • ') : "Main Course";

    final String deliveryTime =
        restaurant['delivery_time']?.toString() ?? "30-45 mins";
    final int costForTwo = restaurant['cost_for_two'] ?? 200;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantMenuPage(
                restaurantId: restaurant['id'],
                restaurantName: restaurant['name'],
                restaurantImage: restaurant['image'],
                restaurantRating: (restaurant['rating'] as num?)?.toDouble(),
                restaurantAddress: address,
                deliveryTime: deliveryTime,
                initialIsOpen: isOpen,
              ),
            ),
          );
        },
        child: Container(
          foregroundDecoration: !isOpen
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  backgroundBlendMode: BlendMode.saturation,
                )
              : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE SECTION
              Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      color: Colors.grey.shade300,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: restaurant['image'] != null &&
                              restaurant['image'].toString().startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: restaurant['image'],
                              fit: BoxFit.cover,
                              memCacheHeight: 400, // Memory optimization
                              memCacheWidth: 800,
                              color: !isOpen
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : null,
                              colorBlendMode: !isOpen ? BlendMode.darken : null,
                              placeholder: (context, url) => const Center(
                                child: Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: Colors.white54,
                                ),
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                "images/food.jpg",
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              restaurant['image'] ?? "images/food.jpg",
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),

                  // Closed Overlay Badge
                  if (!isOpen)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "CLOSED",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  "Offline Now",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Gusto Exclusive Badge
                  if (isExclusive)
                    Positioned(
                      top: 16,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFFA500),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.star, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "GUSTO EXCLUSIVE",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Discount Badge
                  if (showPromo)
                    Positioned(
                      top: isExclusive ? 48 : 16,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isExclusive ? Colors.white : Colors.blueAccent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          border: isExclusive
                              ? Border.all(color: Colors.orange.shade100)
                              : null,
                        ),
                        child: Text(
                          displayPromo,
                          style: TextStyle(
                            color: isExclusive ? Colors.deepOrange : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  // Like Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 16,
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.black87,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Time Badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            deliveryTime,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // INFO SECTION
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Icon(Icons.star, size: 10, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tags,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.wallet, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          "₹$costForTwo for two",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
