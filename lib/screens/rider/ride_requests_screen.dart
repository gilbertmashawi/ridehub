// Enhanced lib/screens/rider/ride_requests_screen.dart
// Added bid form with fare input and accept option
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riderhub/screens/rider/delivery_detail_screen.dart';

class RideRequestsScreen extends StatefulWidget {
  const RideRequestsScreen({super.key});

  @override
  State<RideRequestsScreen> createState() => _RideRequestsScreenState();
}

class _RideRequestsScreenState extends State<RideRequestsScreen> {
  final List<Map<String, dynamic>> _requests = [
    {
      'id': 'REQ001',
      'pickup': 'Central Harare',
      'dropoff': 'Avondale',
      'parcelSize': 'Small',
      'suggestedFare': 5.00,
      'status': 'Open',
      'distance': '2.5 km',
    },
    // ... (more dummy data as before)
  ];

  void _showBidDialog(Map<String, dynamic> request) {
    final TextEditingController _bidController = TextEditingController(
      text: '${request['suggestedFare']}',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bid on ${request['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suggested: \$${request['suggestedFare']}'),
            TextFormField(
              controller: _bidController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your Fare (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final bid = double.tryParse(_bidController.text) ?? 0;
              if (bid > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bid \$${bid} submitted!')),
                );
                Navigator.pop(context);
                // Navigate to detail if accepted
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeliveryDetailScreen(
                      requestId: request['id'],
                      fare: bid,
                    ),
                  ),
                );
              }
            },
            child: const Text('Submit Bid'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Accepted suggested fare \$${request['suggestedFare']}',
                  ),
                ),
              );
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeliveryDetailScreen(
                    requestId: request['id'],
                    fare: request['suggestedFare'],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Accept Price'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey.shade50,
        child: _requests.isEmpty
            ? const Center(
                // Empty state as before...
                child: Card(
                  // ... (same as previous)
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ... (header and details as before)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showBidDialog(request),
                                  icon: const Icon(Icons.gavel),
                                  label: const Text('Bid'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF667eea),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // View details
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DeliveryDetailScreen(
                                              requestId: request['id'],
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.info_outline),
                                  label: const Text('Details'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF667eea),
                                    side: BorderSide(
                                      color: const Color(0xFF667eea),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
