// lib/services/notification_stream_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NotificationStreamService {
  // Singleton instance
  static final NotificationStreamService _instance =
      NotificationStreamService._internal();
  factory NotificationStreamService() => _instance;
  NotificationStreamService._internal();

  // Stream controllers for real-time updates
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  final StreamController<List<dynamic>> _notificationsController =
      StreamController<List<dynamic>>.broadcast();

  // Timer for periodic updates
  Timer? _updateTimer;
  bool _isPolling = false;

  // Current state
  int _currentUnreadCount = 0;
  List<dynamic> _currentNotifications = [];

  // Getters for streams
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  Stream<List<dynamic>> get notificationsStream =>
      _notificationsController.stream;

  int get currentUnreadCount => _currentUnreadCount;
  List<dynamic> get currentNotifications => _currentNotifications;

  // Initialize the service
  Future<void> initialize() async {
    // Load initial data
    await _loadNotifications();

    // Start polling for updates every 30 seconds
    _startPolling();
  }

  // Start polling for new notifications
  void _startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadNotifications();
    });
  }

  // Stop polling (call when app is backgrounded or user logs out)
  void stopPolling() {
    _updateTimer?.cancel();
    _isPolling = false;
  }

  // Force refresh
  Future<void> refresh() async {
    await _loadNotifications();
  }

  // Load notifications from API
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');

      if (sessionId == null) return;

      // First, get unread count
      final countResponse = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_unread_notification_count',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (countResponse.statusCode == 200) {
        final countData = jsonDecode(countResponse.body);
        final newCount = countData['unread_count'] ?? 0;

        // Always fetch full notifications to check for new ones
        final notificationsResponse = await http.get(
          Uri.parse(
            'https://chareta.com/riderhub/api/api.php?action=notifications',
          ),
          headers: {'X-Session-Id': sessionId},
        );

        if (notificationsResponse.statusCode == 200) {
          final notificationsData = jsonDecode(notificationsResponse.body);
          final newNotifications = notificationsData['notifications'] ?? [];

          // Check if there are actually new unread notifications
          final newUnread = newNotifications
              .where((n) => (n['is_read'] ?? 0) == 0)
              .toList();

          // Store the latest notification for popup if it's new
          if (newUnread.isNotEmpty) {
            // Check if this notification is newer than what we have
            final latestNotification = newUnread.first;
            final latestId = latestNotification['id'];

            // Check if we haven't shown this notification yet
            bool isNew = true;
            for (var notif in _currentNotifications) {
              if (notif['id'] == latestId) {
                isNew = false;
                break;
              }
            }

            if (isNew && latestNotification['is_read'] == 0) {
              _showPopupForNewNotifications(newUnread);
            }
          }

          // Update state
          _currentNotifications = newNotifications;
          _currentUnreadCount = newCount;

          // Broadcast updates
          _unreadCountController.add(newCount);
          _notificationsController.add(newNotifications);
        }
      }
    } catch (e) {
      print('Notification stream error: $e');
    }
  }

  // Show popup for new notifications
  void _showPopupForNewNotifications(List<dynamic> notifications) {
    if (notifications.isNotEmpty) {
      // Get the latest notification
      final latest = notifications.first;

      // Trigger callback for UI to show popup
      if (_onNewNotification != null) {
        _onNewNotification!(latest);
      }
    }
  }

  // Callback for new notifications (to be set by UI)
  Function(Map<String, dynamic>)? _onNewNotification;

  void setNotificationCallback(Function(Map<String, dynamic>) callback) {
    _onNewNotification = callback;
  }

  // Mark notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');

      if (sessionId == null) return;

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
        // Update local count
        if (_currentUnreadCount > 0) {
          _currentUnreadCount--;
          _unreadCountController.add(_currentUnreadCount);
        }

        // Also update the local notification list
        final index = _currentNotifications.indexWhere(
          (n) => n['id'] == notificationId,
        );
        if (index != -1) {
          _currentNotifications[index]['is_read'] = 1;
          _notificationsController.add(_currentNotifications);
        }
      }
    } catch (e) {
      print('Mark as read error: $e');
    }
  }

  // Clean up
  void dispose() {
    stopPolling();
    _unreadCountController.close();
    _notificationsController.close();
  }
}
