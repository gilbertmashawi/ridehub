// lib/screens/rider/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                title: Text(
                  'Push Notifications',
                  style: GoogleFonts.inter(fontSize: 16),
                ),
                subtitle: const Text('Receive job alerts'),
                value: true,
                onChanged: (value) {},
                secondary: const Icon(Icons.notifications),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text('Language', style: GoogleFonts.inter(fontSize: 16)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text('Privacy', style: GoogleFonts.inter(fontSize: 16)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text('Logout', style: GoogleFonts.inter(fontSize: 16)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
