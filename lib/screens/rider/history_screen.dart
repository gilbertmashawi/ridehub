// lib/screens/rider/history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// This would normally be replaced with real API data
// For now we use the fact that there are NO completed deliveries
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In real app → fetch from API endpoint like: get_rider_completed_deliveries
    // For this DB snapshot → list will be empty
    final List<Map<String, dynamic>> completedDeliveries = [];

    final dateFormat = DateFormat("MMM d, yyyy 'at' h:mm a");

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
        child: completedDeliveries.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_transportation_outlined,
                      size: 90,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No completed deliveries yet",
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Once you mark a delivery as 'Delivered', it will appear here with earnings, customer info, date and route summary.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Optional: refresh or go to active jobs screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking for updates...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        side: const BorderSide(
                          color: Color(0xFF667eea),
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: completedDeliveries.length,
                itemBuilder: (context, index) {
                  // Real implementation would go here (like in previous message)
                  return const SizedBox.shrink(); // placeholder
                },
              ),
      ),
    );
  }
}
