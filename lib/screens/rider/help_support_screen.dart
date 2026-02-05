// lib/screens/rider/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  bool _loading = true;
  Map<String, String> _settings = {};

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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.08),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, color: const Color(0xFF667eea), size: 28),
                if (icon != null) const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF667eea),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
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
    final String commissionRate = _getSetting('commission_rate', '15');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // About Section
                    _buildSection(
                      title: 'About Chareta Rider Hub',
                      icon: Icons.info_outline,
                      children: [
                        Text(
                          'Rider Hub is Zimbabwe\'s fastest and most reliable on-demand delivery service. '
                          'We connect customers with trusted riders for food, groceries, parcels, and more — '
                          'with real-time tracking, secure payments, and excellent support.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),

                    // Contact Details Section
                    _buildSection(
                      title: 'Contact Details',
                      icon: Icons.contact_phone,
                      children: [
                        // Website (hardcoded)
                        Row(
                          children: [
                            const Icon(
                              Icons.language,
                              color: Color(0xFF667eea),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () =>
                                  _launchURL('http://ridehubservices.com'),
                              child: Text(
                                'www.ridehubservices.com',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Support Email
                        Row(
                          children: [
                            const Icon(
                              Icons.email,
                              color: Color(0xFF667eea),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _launchURL('mailto:$supportEmail'),
                              child: Text(
                                supportEmail,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Phone Numbers (multiple)
                        if (phone1.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.green,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _launchURL('tel:$phone1'),
                                child: Text(
                                  phone1,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (phone1.isNotEmpty) const SizedBox(height: 12),

                        if (phone2.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.green,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _launchURL('tel:$phone2'),
                                child: Text(
                                  phone2,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (phone2.isNotEmpty) const SizedBox(height: 12),

                        if (phone3.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.green,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _launchURL('tel:$phone3'),
                                child: Text(
                                  phone3,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Commission Rate Section
                    _buildSection(
                      title: 'Commission Rate',
                      icon: Icons.percent,
                      children: [
                        Text(
                          'Our current commission rate for riders is:',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$commissionRate%',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF667eea),
                          ),
                        ),
                      ],
                    ),

                    // Our Offices Section (hardcoded)
                    _buildSection(
                      title: 'Our Offices',
                      icon: Icons.location_on,
                      children: [
                        Text(
                          'Head Office:',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '123 Main Street, Cityville, Country',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Branch Office:',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '456 Robert Mugabe Street, Harare, Zimbabwe',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                    // Legal Section (you can add URLs later in settings)
                    _buildSection(
                      title: 'Legal',
                      icon: Icons.gavel,
                      children: [
                        Text(
                          'Terms & Conditions, Privacy Policy, and Rider Agreement will be available soon.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}
