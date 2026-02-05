// lib/screens/customer/riders_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riderhub/screens/customer/rider_profile_screen.dart';

class RidersListScreen extends StatelessWidget {
  const RidersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> riders = [
      {'name': 'John Doe', 'rating': 4.8, 'jobs': 150},
      {'name': 'Mike Johnson', 'rating': 4.5, 'jobs': 89},
      {'name': 'Sarah Lee', 'rating': 4.9, 'jobs': 200},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Riders',
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
          itemCount: riders.length,
          itemBuilder: (context, index) {
            final rider = riders[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF667eea),
                  child: Text(
                    rider['name'][0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(rider['name']),
                subtitle: Text(
                  'Rating: ${rider['rating']}/5 | Jobs: ${rider['jobs']}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RiderProfileScreen(),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
