import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/delivery_tracking_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:riderhub/screens/rider/no_active_job_screen.dart';

class CurrentJobTile extends StatefulWidget {
  const CurrentJobTile({super.key});

  @override
  State<CurrentJobTile> createState() => _CurrentJobTileState();
}

class _CurrentJobTileState extends State<CurrentJobTile> {
  Map<String, dynamic>? _activeAssignment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveAssignment();
  }

  Future<Map<String, dynamic>?> _fetchActiveAssignment() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) return null;

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_active_assignment',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['has_active_assignment'] == true) {
          final assignment = data['assignment'];

          // Type-safe conversion
          return {
            'assignment_id': _safeParseInt(assignment['assignment_id']),
            'order_id': _safeParseInt(assignment['order_id']),
            'fare_amount': _safeParseDouble(assignment['fare_amount']),
            'assignment_status': assignment['assignment_status'] ?? 'assigned',
            'customer_name': assignment['customer_name'] ?? 'Customer',
            'customer_phone': assignment['customer_phone'] ?? '',
            'pickup_lat': _safeParseDouble(assignment['pickup_lat']),
            'pickup_lng': _safeParseDouble(assignment['pickup_lng']),
            'dropoff_lat': _safeParseDouble(assignment['dropoff_lat']),
            'dropoff_lng': _safeParseDouble(assignment['dropoff_lng']),
            'parcel_size': assignment['parcel_size'] ?? 'Parcel',
            'suggested_fare': _safeParseDouble(assignment['suggested_fare']),
            'payment_method': assignment['payment_method'] ?? 'cash',
            'parcel_photo': assignment['parcel_photo'],
            'created_at': assignment['created_at'],
            ...assignment,
          };
        }
      }
    } catch (e) {
      debugPrint('Fetch active assignment error: $e');
    }

    return null;
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadActiveAssignment() async {
    final assignment = await _fetchActiveAssignment();
    setState(() {
      _activeAssignment = assignment;
      _isLoading = false;
    });
  }

  void _navigateToJobScreen() {
    if (_activeAssignment != null && _activeAssignment!['assignment_id'] > 0) {
      final assignmentId = _activeAssignment!['assignment_id'];
      final jobDetails = _activeAssignment!;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryTrackingScreen(
            assignmentId: assignmentId,
            jobDetails: jobDetails,
          ),
        ),
      ).then((_) {
        // Refresh when returning from tracking screen
        _loadActiveAssignment();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NoActiveJobScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _activeAssignment != null
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delivery_dining,
                color: Colors.green,
                size: 20,
              ),
            )
          : const Icon(Icons.delivery_dining_outlined),
      title: const Text('Current Job'),
      subtitle: _isLoading
          ? const Text('Checking...')
          : _activeAssignment != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery #${_activeAssignment!['order_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activeAssignment!['assignment_status']
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  ],
                ),
              ],
            )
          : const Text('No active delivery'),
      trailing: _activeAssignment != null
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : const Icon(Icons.info_outline, size: 20),
      onTap: _navigateToJobScreen,
    );
  }
}
