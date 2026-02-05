import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riderhub/screens/customer_tracking_screen.dart';

class TrackDeliveryWrapperScreen extends StatefulWidget {
  const TrackDeliveryWrapperScreen({super.key});

  @override
  State<TrackDeliveryWrapperScreen> createState() =>
      _TrackDeliveryWrapperScreenState();
}

class _TrackDeliveryWrapperScreenState
    extends State<TrackDeliveryWrapperScreen> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _deliveryData;
  int? _deliveryId;

  @override
  void initState() {
    super.initState();
    _loadActiveDelivery();
  }

  Future<void> _loadActiveDelivery() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not logged in';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_active_customer_delivery',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['has_active_delivery'] == true) {
          final delivery = data['delivery'];

          // Parse assignment ID
          final dynamic idValue = delivery['assignment_id'];
          final int assignmentId = idValue is int
              ? idValue
              : (idValue is String ? int.tryParse(idValue) ?? 0 : 0);

          if (assignmentId > 0) {
            setState(() {
              _deliveryId = assignmentId;
              _deliveryData = Map<String, dynamic>.from(delivery);
              _isLoading = false;
            });
          } else {
            setState(() {
              _isLoading = false;
              _error = 'Invalid delivery ID';
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _error = 'No active delivery found';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Track Delivery'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_deliveryId != null && _deliveryData != null) {
      return CustomerTrackingScreen(
        deliveryId: _deliveryId!,
        deliveryDetails: _deliveryData,
      );
    }

    return Scaffold(
      body: Center(
        child: Text('Unexpected error', style: TextStyle(color: Colors.red)),
      ),
    );
  }
}
