import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ← better date formatting
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
  bool _hasError = false;
  String _errorMessage = '';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Please log in to view notifications';
      });
      return;
    }

    try {
      final uri = Uri.parse(
        'https://chareta.com/riderhub/api/api.php?action=get_notifications',
      );

      final response = await http.get(
        uri,
        headers: {'X-Session-Id': sessionId, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['notifications'] is List) {
          final List notifications = data['notifications'];

          final unread = notifications
              .where((n) => (n['is_read'] ?? 0) == 0)
              .length;

          setState(() {
            _notifications = notifications;
            _unreadCount = unread;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = data['error'] ?? 'Invalid response format';
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Session expired. Please log in again.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Server error (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error: $e';
      });
    }
  }

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
          'Accept': 'application/json',
        },
        body: jsonEncode({'notification_id': notificationId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            final idx = _notifications.indexWhere(
              (n) => n['id'] == notificationId,
            );
            if (idx != -1) {
              _notifications[idx]['is_read'] = 1;
              if (_unreadCount > 0) _unreadCount--;
            }
          });
          widget.onNotificationsRead?.call();
        }
      }
    } catch (e) {
      // silent fail — don't disturb user
      debugPrint('Mark read failed: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;

    final unreadIds = _notifications
        .where((n) => (n['is_read'] ?? 0) == 0)
        .map<int>((n) => n['id'] as int)
        .toList();

    for (final id in unreadIds) {
      await _markAsRead(id);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 2) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return dateStr.split(' ').first;
    }
  }

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'delivery_assigned':
      case 'assignment_accepted':
        return Icons.delivery_dining;
      case 'new_message':
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'topup_approved':
      case 'topup_rejected':
        return Icons.account_balance_wallet;
      case 'new_bid':
      case 'bid_accepted':
        return Icons.attach_money;
      case 'system':
      case 'broadcast':
        return Icons.campaign;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'delivery_assigned':
      case 'assignment_accepted':
        return Colors.orange;
      case 'new_message':
      case 'chat_message':
        return Colors.purple;
      case 'topup_approved':
        return Colors.green;
      case 'topup_rejected':
        return Colors.red;
      case 'new_bid':
        return Colors.teal;
      case 'bid_accepted':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
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
        backgroundColor: const Color(0xFF6366f1),
        foregroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(_errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _loadNotifications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You’ll see updates here',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  final unread = (n['is_read'] ?? 0) == 0;
                  final type = n['type'] as String?;

                  return Dismissible(
                    key: ValueKey(n['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => _markAsRead(n['id']),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      elevation: unread ? 2 : 0,
                      color: unread ? const Color(0xFFF0F7FF) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _getColor(type).withOpacity(0.15),
                          radius: 24,
                          child: Icon(_getIcon(type), color: _getColor(type)),
                        ),
                        title: Text(
                          n['title']?.toString() ?? 'Update',
                          style: GoogleFonts.inter(
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            n['message']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(n['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (unread)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6366f1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          if (unread) _markAsRead(n['id']);
                          // You can navigate / show dialog based on type here
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
