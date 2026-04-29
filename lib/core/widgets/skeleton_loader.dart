import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _gradientPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _gradientPosition,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _gradientPosition.value - 0.3,
                _gradientPosition.value,
                _gradientPosition.value + 0.3,
              ],
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
        );
      },
    );
  }
}

// Pre-defined Skeleton Blocks for easier use
class SkeletonBanner extends StatelessWidget {
  const SkeletonBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return const SkeletonLoader(
      width: double.infinity,
      height: 180,
      borderRadius: 16,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

class SkeletonCategory extends StatelessWidget {
  const SkeletonCategory({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(width: 60, height: 60, borderRadius: 30),
        SizedBox(height: 8),
        SkeletonLoader(width: 50, height: 12),
      ],
    );
  }
}

class SkeletonRestaurantCard extends StatelessWidget {
  const SkeletonRestaurantCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: double.infinity, height: 160, borderRadius: 16),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonLoader(width: 150, height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const SkeletonLoader(width: 40, height: 20, borderRadius: 6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 100, height: 14),
        ],
      ),
    );
  }
}

class SkeletonMenuItem extends StatelessWidget {
  const SkeletonMenuItem({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 20, height: 20),
                const SizedBox(height: 12),
                const SkeletonLoader(width: 180, height: 20),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 100, height: 16),
                const SizedBox(height: 12),
                const SkeletonLoader(width: double.infinity, height: 40, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SkeletonLoader(width: 120, height: 120, borderRadius: 12),
        ],
      ),
    );
  }
}
