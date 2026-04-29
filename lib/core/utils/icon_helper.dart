import 'package:flutter/material.dart';

class IconHelper {
  static IconData getIcon(String name) {
    switch (name.toLowerCase()) {
      case 'combos':
        return Icons.fastfood;
      case 'burger':
        return Icons.lunch_dining;
      case 'pizza':
        return Icons.local_pizza;
      case 'starters':
        return Icons.restaurant_menu;
      case 'main course':
        return Icons.rice_bowl;
      case 'beverages':
        return Icons.local_drink;
      case 'desserts':
        return Icons.icecream;
      case 'healthy':
        return Icons.spa;
      case 'all':
        return Icons.grid_view_rounded;
      default:
        return Icons.fastfood;
    }
  }

  static Color getColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
