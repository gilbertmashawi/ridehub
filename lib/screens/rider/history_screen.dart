// lib/screens/rider/history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Delivery History',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5, // Dummy items
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.motorcycle, color: Color(0xFF667eea)),
                title: Text(
                  'Delivery #${index + 1}',
                  style: GoogleFonts.inter(fontSize: 16),
                ),
                subtitle: const Text(
                  'Completed on Nov 16, 2025\nFare: \$15.00',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to detail
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
