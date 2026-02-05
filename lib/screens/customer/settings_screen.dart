// lib/screens/customer/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  Map<String, String> _settings = {};

  bool pushNotifications = true; // You can make this dynamic later if needed

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_system_settings',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['settings'] != null) {
          setState(() {
            _settings = Map<String, String>.from(data['settings']);
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _getSetting(String key, String fallback) {
    final value = _settings[key];
    return (value != null && value.trim().isNotEmpty) ? value.trim() : fallback;
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          label,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.inter(fontSize: 16, color: Colors.blue),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String supportEmail = _getSetting(
      'support_email',
      'support@ridehubservices.com',
    );
    final String phone1 = _getSetting('support_phone_1', '');
    final String phone2 = _getSetting('support_phone_2', '');
    final String phone3 = _getSetting('support_phone_3', '');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF667eea)),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Notification Settings
                  Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: SwitchListTile(
                      title: Text(
                        'Push Notifications',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Receive delivery updates and promotions',
                      ),
                      value: pushNotifications,
                      onChanged: (value) {
                        setState(() {
                          pushNotifications = value;
                        });
                      },
                      secondary: const Icon(
                        Icons.notifications,
                        color: Color(0xFF667eea),
                      ),
                      activeColor: const Color(0xFF667eea),
                    ),
                  ),

                  // App Settings
                  Text(
                    'App Settings',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.language,
                        color: Color(0xFF667eea),
                      ),
                      title: Text(
                        'Language',
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Navigate to language selection
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.privacy_tip,
                        color: Color(0xFF667eea),
                      ),
                      title: Text(
                        'Privacy Policy',
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        _launchURL(
                          'https://chareta.com/privacy',
                        ); // Or make dynamic later
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Support & Contact Section
                  Text(
                    'Support & Contact',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Website
                  _buildContactItem(
                    icon: Icons.language,
                    iconColor: const Color(0xFF667eea),
                    label: 'Website',
                    value: 'www.chareta.com',
                    onTap: () => _launchURL('https://chareta.com'),
                  ),

                  // Support Email
                  _buildContactItem(
                    icon: Icons.email,
                    iconColor: const Color(0xFF667eea),
                    label: 'Support Email',
                    value: supportEmail,
                    onTap: () => _launchURL('mailto:$supportEmail'),
                  ),

                  // Phone Numbers
                  if (phone1.isNotEmpty)
                    _buildContactItem(
                      icon: Icons.phone,
                      iconColor: Colors.green,
                      label: 'Support Line 1',
                      value: phone1,
                      onTap: () => _launchURL('tel:$phone1'),
                    ),

                  if (phone2.isNotEmpty)
                    _buildContactItem(
                      icon: Icons.phone,
                      iconColor: Colors.green,
                      label: 'Support Line 2',
                      value: phone2,
                      onTap: () => _launchURL('tel:$phone2'),
                    ),

                  if (phone3.isNotEmpty)
                    _buildContactItem(
                      icon: Icons.phone,
                      iconColor: Colors.green,
                      label: 'Support Line 3',
                      value: phone3,
                      onTap: () => _launchURL('tel:$phone3'),
                    ),

                  const SizedBox(height: 24),

                  // Logout
                  Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.red,
                      ),
                      onTap: () {
                        // Handle logout logic
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                              'Are you sure you want to logout?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Perform logout
                                  Navigator.pop(ctx);
                                  // Navigate to login screen, etc.
                                },
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}
