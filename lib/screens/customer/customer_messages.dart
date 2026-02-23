// lib/screens/customer/customer_messages.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CustomerMessagesScreen extends StatefulWidget {
  const CustomerMessagesScreen({super.key});

  @override
  State<CustomerMessagesScreen> createState() => _CustomerMessagesScreenState();
}

class _CustomerMessagesScreenState extends State<CustomerMessagesScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadUnreadCount();
  }

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Session expired. Please login again"),
            ),
          );
        }
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_my_messages',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['messages'] != null) {
          setState(() {
            _messages = List.from(data['messages']);
            _isLoading = false;
          });
        }
      } else {
        debugPrint("Messages fetch failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Messages error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) return;

      final res = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_unread_message_count',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() => _unreadCount = data['unread_count'] ?? 0);
        }
      }
    } catch (e) {
      debugPrint("Unread count error: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final sessionId = await _getSessionId();
      if (sessionId == null) return;

      final res = await http.post(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=mark_messages_read',
        ),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (res.statusCode == 200) {
        setState(() => _unreadCount = 0);
        _loadMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All messages marked as read")),
        );
      }
    } catch (e) {
      debugPrint("Mark read error: $e");
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy • HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Messages',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadMessages();
              _loadUnreadCount();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      size: 80,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No messages from admin yet",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text("Mark all as read"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _markAllAsRead,
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isUnread = msg['is_read'] == 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isUnread ? 6 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: isUnread ? Colors.white : Colors.white70,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // Optional: mark single message as read (if you want)
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isUnread)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                            top: 4,
                                          ),
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg['title'] ??
                                                  'Message from Admin',
                                              style: GoogleFonts.inter(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: isUnread
                                                    ? Colors.black87
                                                    : Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(msg['created_at']),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    msg['message'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      height: 1.4,
                                      color: isUnread
                                          ? Colors.black87
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
