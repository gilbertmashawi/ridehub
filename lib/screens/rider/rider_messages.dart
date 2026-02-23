// rider_messages.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RiderMessagesScreen extends StatefulWidget {
  const RiderMessagesScreen({super.key});

  @override
  State<RiderMessagesScreen> createState() => _RiderMessagesScreenState();
}

class _RiderMessagesScreenState extends State<RiderMessagesScreen> {
  List<dynamic> messages = [];
  bool isLoading = true;
  int unreadCount = 0;

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
    setState(() => isLoading = true);

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
            messages = data['messages'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Messages error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
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
        setState(() {
          unreadCount = data['unread_count'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
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
        setState(() => unreadCount = 0);
        _loadMessages();
      }
    } catch (_) {}
  }

  String _formatDate(String dateStr) {
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
          'Messages',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF667eea),
        actions: [
          if (unreadCount > 0)
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
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
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
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : messages.isEmpty
            ? Center(
                child: Text(
                  "No messages from admin yet",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 18),
                ),
              )
            : Column(
                children: [
                  if (unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text("Mark all as read"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                        ),
                        onPressed: _markAllRead,
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isUnread = msg['is_read'] == 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: isUnread ? Colors.white : Colors.white70,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isUnread)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                      ),
                                    Expanded(
                                      child: Text(
                                        msg['title'] ?? 'No title',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDate(msg['created_at']),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  msg['message'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 15),
                                ),
                              ],
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
