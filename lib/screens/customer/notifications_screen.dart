import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/services/notification_stream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onNotificationsRead;

  const NotificationsScreen({super.key, this.onNotificationsRead});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=notifications',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['notifications'] != null) {
          // Calculate unread count
          final unread = (data['notifications'] as List)
              .where((n) => (n['is_read'] ?? 0) == 0)
              .length;

          setState(() {
            _notifications = data['notifications'];
            _unreadCount = unread;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Load notifications error: $e');
      setState(() => _isLoading = false);
    }
  }

  // Future<void> _markAsRead(int notificationId) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final sessionId = prefs.getString('session_id');

  //   if (sessionId == null) return;

  //   try {
  //     await http.post(
  //       Uri.parse(
  //         'https://chareta.com/riderhub/api/api.php?action=mark_notification_read',
  //       ),
  //       headers: {
  //         'X-Session-Id': sessionId,
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode({'notification_id': notificationId}),
  //     );

  //     // Update local state
  //     setState(() {
  //       final index = _notifications.indexWhere(
  //         (n) => n['id'] == notificationId,
  //       );
  //       if (index != -1) {
  //         _notifications[index]['is_read'] = 1;
  //         _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
  //       }
  //     });

  //     // Notify parent about read notifications
  //     widget.onNotificationsRead?.call();
  //   } catch (e) {
  //     debugPrint('Mark as read error: $e');
  //   }
  // }

  // Update the markAsRead function in notifications_screen.dart
  Future<void> _markAsRead(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) return;

    try {
      final response = await http.post(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=mark_notification_read',
        ),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notification_id': notificationId}),
      );

      if (response.statusCode == 200) {
        // Update local state
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['id'] == notificationId,
          );
          if (index != -1) {
            _notifications[index]['is_read'] = 1;
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          }
        });

        // Notify parent about read notifications
        widget.onNotificationsRead?.call();

        // Also notify the notification stream service
        final notificationService = NotificationStreamService();
        notificationService.markAsRead(notificationId);
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null || _unreadCount == 0) return;

    try {
      // Mark all unread notifications
      final unreadIds = _notifications
          .where((n) => (n['is_read'] ?? 0) == 0)
          .map((n) => n['id'])
          .toList();

      for (final id in unreadIds) {
        await _markAsRead(id);
      }

      // Call the callback to update parent
      widget.onNotificationsRead?.call();
    } catch (e) {
      debugPrint('Mark all as read error: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    if (notification['is_read'] == 0) {
      _markAsRead(notification['id']);
    }

    // Handle different notification types
    final type = notification['type'];
    if (type == 'new_bid') {
      _showBidDetails(notification);
    } else if (type == 'bid_accepted') {
      _showDeliveryDetails(notification);
    }
  }

  void _showBidDetails(Map<String, dynamic> notification) {
    final data = jsonDecode(notification['data'] ?? '{}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? ''),
            const SizedBox(height: 16),
            if (data['bid_amount'] != null)
              Text('Bid Amount: \$${data['bid_amount']?.toStringAsFixed(2)}'),
            if (data['rider_name'] != null)
              Text('Rider: ${data['rider_name']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery Update'),
        content: Text(notification['message'] ?? 'Delivery status updated'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when you receive bids.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isUnread = (notification['is_read'] ?? 0) == 0;

                return Dismissible(
                  key: ValueKey(notification['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    if (isUnread) {
                      _markAsRead(notification['id']);
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    color: isUnread ? Colors.blue[50] : null,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getNotificationColor(
                            notification['type'],
                          ).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getNotificationIcon(notification['type']),
                          color: _getNotificationColor(notification['type']),
                        ),
                      ),
                      title: Text(
                        notification['title'] ?? 'Notification',
                        style: GoogleFonts.inter(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        notification['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(notification['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _handleNotificationTap(notification),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_bid':
        return Icons.attach_money;
      case 'bid_accepted':
        return Icons.check_circle;
      case 'delivery_assigned':
        return Icons.delivery_dining;
      case 'new_message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_bid':
        return Colors.green;
      case 'bid_accepted':
        return Colors.blue;
      case 'delivery_assigned':
        return Colors.orange;
      case 'new_message':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return dateString;
    }
  }
}
