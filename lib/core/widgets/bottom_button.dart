import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gusto/features/home/screens/main_screen.dart';
import 'package:gusto/features/cart/screens/cart.dart';
import 'package:gusto/features/profile/screens/profile_screen.dart';
import 'package:gusto/features/cart/screens/orders_page.dart';

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const FloatingBottomNav({super.key, required this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(context, 0, Icons.home_rounded, Icons.home_outlined, 'Home', const HomePage()),
                _navItem(context, 1, Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'Cart', CartPage()),
                _navItem(context, 2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders', const OrdersPage()),
                _navItem(context, 3, Icons.person_rounded, Icons.person_outline, 'Profile', ProfilePage()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context, int index, IconData activeIcon, IconData inactiveIcon, String label, Widget destination) {
    bool isActive = currentIndex == index;
    final primaryColor = const Color(0xFFFE724C);

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          if (onTap != null) {
            onTap!(index);
          } else {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, anim1, anim2) => destination,
                transitionDuration: Duration.zero,
              ),
            );
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                key: ValueKey(isActive),
                size: isActive ? 26 : 24,
                color: isActive ? primaryColor : Colors.grey.shade500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
