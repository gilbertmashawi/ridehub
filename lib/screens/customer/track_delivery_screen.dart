// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'dart:async';

// class TrackDeliveryScreen extends StatefulWidget {
//   final String deliveryId;
//   const TrackDeliveryScreen({super.key, required this.deliveryId});

//   @override
//   State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
// }

// class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
//   GoogleMapController? _mapController;
//   Set<Marker> _markers = {};
//   Set<Polyline> _polylines = {};
//   LatLng _riderPosition = const LatLng(-17.8249, 31.0469); // Harare default
//   String _eta = '5 mins';
//   String _status = 'In Transit';
//   Timer? _updateTimer;

//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchDeliveryData();
//     _startTracking();
//   }

//   Future<String?> _getAuthToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('token');
//   }

//   Future<void> _fetchDeliveryData() async {
//     final token = await _getAuthToken();
//     if (token == null) {
//       _showError('No authentication token found. Please log in.');
//       return;
//     }

//     try {
//       final response = await http
//           .get(
//             Uri.parse(
//               'https://chareta.com/riderhub/api/api.php?action=deliveries_track&delivery_id=${widget.deliveryId}',
//             ),
//             headers: {
//               'Authorization': 'Bearer $token',
//               'Content-Type': 'application/json',
//             },
//           )
//           .timeout(const Duration(seconds: 30));

//       print('Response status: ${response.statusCode}'); // Debug
//       print('Response body: ${response.body}'); // Debug

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         if (responseData.containsKey('error')) {
//           _showError('Tracking failed: ${responseData['error']}');
//         } else {
//           final delivery = responseData['delivery'];
//           setState(() {
//             _status = delivery['status'] ?? 'In Transit';
//             _eta = '${delivery['eta_mins'] ?? 5} mins';
//             if (delivery['rider_lat'] != null &&
//                 delivery['rider_lng'] != null) {
//               _riderPosition = LatLng(
//                 delivery['rider_lat'],
//                 delivery['rider_lng'],
//               );
//             }
//             _addMarkers(delivery);
//           });
//         }
//       } else {
//         _showError('Server error: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error: $e'); // Debug
//       _showError('Network error: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _addMarkers(Map<String, dynamic> delivery) {
//     _markers.clear();
//     _markers.add(
//       Marker(
//         markerId: const MarkerId('pickup'),
//         position: LatLng(delivery['pickup_lat'], delivery['pickup_lng']),
//         infoWindow: const InfoWindow(title: 'Pickup'),
//       ),
//     );
//     _markers.add(
//       Marker(
//         markerId: const MarkerId('dropoff'),
//         position: LatLng(delivery['dropoff_lat'], delivery['dropoff_lng']),
//         infoWindow: const InfoWindow(title: 'Dropoff'),
//       ),
//     );
//     _markers.add(
//       Marker(
//         markerId: const MarkerId('rider'),
//         position: _riderPosition,
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//         infoWindow: InfoWindow(title: delivery['rider_name'] ?? 'Rider'),
//       ),
//     );
//     // Sample polyline
//     _polylines.add(
//       Polyline(
//         polylineId: const PolylineId('route'),
//         points: [
//           LatLng(delivery['pickup_lat'], delivery['pickup_lng']),
//           _riderPosition,
//           LatLng(delivery['dropoff_lat'], delivery['dropoff_lng']),
//         ],
//         color: Colors.blue,
//         width: 3,
//       ),
//     );
//     if (_mapController != null) {
//       _mapController!.animateCamera(CameraUpdate.newLatLng(_riderPosition));
//     }
//   }

//   void _startTracking() {
//     _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
//       _fetchDeliveryData();
//     });
//   }

//   void _confirmDelivery() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Confirm Delivery'),
//         content: const Text('Delivery received? Rate the rider.'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Delivery confirmed! Rating submitted.'),
//                 ),
//               );
//               // Navigate to rating screen or home
//             },
//             child: const Text('Yes, Rate Rider'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('No'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   @override
//   void dispose() {
//     _updateTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Track Delivery #${widget.deliveryId}',
//           style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: const Color(0xFF667eea),
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 // Status and ETA Banner
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.all(16),
//                   color: Colors.white,
//                   child: Row(
//                     children: [
//                       Icon(
//                         _status == 'In Transit'
//                             ? Icons.local_shipping
//                             : Icons.check_circle,
//                         color: _status == 'In Transit'
//                             ? Colors.blue
//                             : Colors.green,
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               _status,
//                               style: GoogleFonts.inter(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               'ETA: $_eta',
//                               style: GoogleFonts.inter(
//                                 fontSize: 14,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (_status == 'Arrived')
//                         ElevatedButton(
//                           onPressed: _confirmDelivery,
//                           child: const Text('Confirm'),
//                         ),
//                     ],
//                   ),
//                 ),
//                 // Map
//                 Expanded(
//                   child: GoogleMap(
//                     initialCameraPosition: const CameraPosition(
//                       target: LatLng(-17.8249, 31.0469),
//                       zoom: 14,
//                     ),
//                     markers: _markers,
//                     polylines: _polylines,
//                     myLocationEnabled: true,
//                     onMapCreated: (GoogleMapController controller) {
//                       _mapController = controller;
//                     },
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riderhub/screens/chat_screen.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final int deliveryId;
  final Map<String, dynamic>? deliveryDetails;

  const CustomerTrackingScreen({
    Key? key,
    required this.deliveryId,
    this.deliveryDetails,
  }) : super(key: key);

  @override
  _CustomerTrackingScreenState createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  GoogleMapController? _mapController;
  LatLng? _riderLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  Timer? _chatTimer;
  Map<String, dynamic>? _riderInfo;
  int _unreadMessages = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
    _startLocationTracking();
    _startChatUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _chatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeliveryDetails() async {
    if (widget.deliveryDetails != null) {
      setState(() {
        _pickupLocation = LatLng(
          widget.deliveryDetails!['pickup_lat'] ?? 0.0,
          widget.deliveryDetails!['pickup_lng'] ?? 0.0,
        );
        _dropoffLocation = LatLng(
          widget.deliveryDetails!['dropoff_lat'] ?? 0.0,
          widget.deliveryDetails!['dropoff_lng'] ?? 0.0,
        );
      });
      _addMarkers();
    }
    await _fetchRiderLocation();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchRiderLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_delivery_location&delivery_id=${widget.deliveryId}',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['location'] != null) {
          final lat = double.parse(data['location']['lat'].toString());
          final lng = double.parse(data['location']['lng'].toString());

          setState(() {
            _riderLocation = LatLng(lat, lng);
            _riderInfo = data['rider'];
          });

          _updateMap();
        }
      }
    } catch (e) {
      debugPrint('Fetch rider location error: $e');
    }
  }

  Future<void> _fetchUnreadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_messages&delivery_id=${widget.deliveryId}',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = List<Map<String, dynamic>>.from(
          data['messages'] ?? [],
        );

        setState(() {
          _unreadMessages = messages
              .where(
                (msg) => msg['sender_type'] == 'rider' && msg['is_read'] == 0,
              )
              .length;
        });
      }
    } catch (e) {
      debugPrint('Fetch unread messages error: $e');
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchRiderLocation();
    });
  }

  void _startChatUpdates() {
    _chatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchUnreadMessages();
    });
  }

  void _addMarkers() {
    _markers.clear();

    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    if (_dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          infoWindow: const InfoWindow(title: 'Dropoff Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  void _updateMap() {
    if (_riderLocation != null) {
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderLocation!,
          infoWindow: InfoWindow(
            title: _riderInfo?['name'] ?? 'Rider',
            snippet: _riderInfo?['rider_code'] ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      if (_pickupLocation != null && _riderLocation != null) {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_riderLocation!, _dropoffLocation ?? _pickupLocation!],
            color: Colors.blue,
            width: 4,
          ),
        );
      }

      if (_mapController != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            (_riderLocation!.latitude +
                        (_pickupLocation?.latitude ?? 0) +
                        (_dropoffLocation?.latitude ?? 0)) /
                    3 -
                0.01,
            (_riderLocation!.longitude +
                        (_pickupLocation?.longitude ?? 0) +
                        (_dropoffLocation?.longitude ?? 0)) /
                    3 -
                0.01,
          ),
          northeast: LatLng(
            (_riderLocation!.latitude +
                        (_pickupLocation?.latitude ?? 0) +
                        (_dropoffLocation?.latitude ?? 0)) /
                    3 +
                0.01,
            (_riderLocation!.longitude +
                        (_pickupLocation?.longitude ?? 0) +
                        (_dropoffLocation?.longitude ?? 0)) /
                    3 +
                0.01,
          ),
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Delivery'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () => _openChat(),
              ),
              if (_unreadMessages > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadMessages',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-17.8249, 31.05),
                      zoom: 12,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_riderLocation != null) _updateMap();
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_riderInfo != null)
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            _riderInfo!['name'] ?? 'Rider',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Rider Code: ${_riderInfo!['rider_code'] ?? 'N/A'}\n'
                            'Phone: ${_riderInfo!['phone'] ?? 'N/A'}',
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.phone),
                              label: const Text('Call Rider'),
                              onPressed: _riderInfo?['phone'] != null
                                  ? () {
                                      // Implement phone call
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: Text(
                                'Chat${_unreadMessages > 0 ? ' ($_unreadMessages)' : ''}',
                              ),
                              onPressed: () => _openChat(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          deliveryId: widget.deliveryId,
          riderName: _riderInfo?['name'] ?? 'Rider',
          otherUserName: '',
        ),
      ),
    ).then((_) {
      _fetchUnreadMessages();
    });
  }
}
