import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for notifications with modern categorization
    final List<Map<String, dynamic>> notifications = [
      {
        'title': 'Order Arriving Soon!',
        'message': 'Your order from Gusto Pizza Shop is 5 minutes away. Get ready!',
        'time': '2m ago',
        'isRead': false,
        'type': 'order',
      },
      {
        'title': '50% OFF Weekend Bonanza 🍔',
        'message': 'Use code WEEKEND50 to get a whopping 50% discount on all burgers today.',
        'time': '2h ago',
        'isRead': false,
        'type': 'promo',
      },
      {
        'title': 'Rate your last meal',
        'message': 'How was your Maha Chicken Burger? Drop a rating to help others out.',
        'time': 'Yesterday',
        'isRead': true,
        'type': 'system',
      },
      {
        'title': 'Welcome to Gusto!',
        'message': 'We are so glad you are here. Explore the best local restaurants around you.',
        'time': '3 days ago',
        'isRead': true,
        'type': 'system',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
            ),
          ),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Add Clear All logic if backend is integrated later
            },
            child: const Text(
              "Clear All",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(notif);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No notifications yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When you get offers or orders,\nthey'll show up here",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final bool isRead = notif['isRead'] ?? false;
    final String type = notif['type'] ?? 'system';

    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'order':
        iconData = Icons.electric_moped;
        iconColor = Colors.white;
        bgColor = Colors.blueAccent;
        break;
      case 'promo':
        iconData = Icons.local_offer;
        iconColor = Colors.white;
        bgColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.black87;
        bgColor = Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: isRead ? null : Border.all(color: Colors.orange.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          // Content Block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notif['message'],
                  style: TextStyle(
                    fontSize: 13,
                    color: isRead ? Colors.grey.shade600 : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notif['time'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
