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

  // Helper function to safely parse coordinates
  double _parseCoordinate(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _loadDeliveryDetails() async {
    if (widget.deliveryDetails != null) {
      // Safely parse coordinates
      final pickupLat = _parseCoordinate(widget.deliveryDetails!['pickup_lat']);
      final pickupLng = _parseCoordinate(widget.deliveryDetails!['pickup_lng']);
      final dropoffLat = _parseCoordinate(
        widget.deliveryDetails!['dropoff_lat'],
      );
      final dropoffLng = _parseCoordinate(
        widget.deliveryDetails!['dropoff_lng'],
      );

      setState(() {
        if (pickupLat != 0.0 && pickupLng != 0.0) {
          _pickupLocation = LatLng(pickupLat, pickupLng);
        }
        if (dropoffLat != 0.0 && dropoffLng != 0.0) {
          _dropoffLocation = LatLng(dropoffLat, dropoffLng);
        }
      });
      _addMarkers();
    }
    await _fetchRiderLocation();
    setState(() => _isLoading = false);
  }

  // Future<void> _fetchRiderLocation() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final sessionId = prefs.getString('session_id');
  //   if (sessionId == null) return;

  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //         'https://chareta.com/riderhub/api/api.php?action=get_delivery_location&delivery_id=${widget.deliveryId}',
  //       ),
  //       headers: {'X-Session-Id': sessionId},
  //     );

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);

  //       // Debug log
  //       debugPrint('Rider location response: $data');

  //       if (data['location'] != null &&
  //           data['location']['lat'] != null &&
  //           data['location']['lng'] != null) {
  //         final lat = _parseCoordinate(data['location']['lat']);
  //         final lng = _parseCoordinate(data['location']['lng']);

  //         if (lat != 0.0 && lng != 0.0) {
  //           final newRiderLocation = LatLng(lat, lng);

  //           setState(() {
  //             _riderLocation = newRiderLocation;
  //             _riderInfo = data['rider'] is Map<String, dynamic>
  //                 ? Map<String, dynamic>.from(data['rider'])
  //                 : null;
  //           });

  //           _updateMap();

  //           // Debug log
  //           debugPrint('Rider location updated: $lat, $lng');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('Fetch rider location error: $e');
  //   }
  // }

  // In the _fetchRiderLocation function, update the response handling:
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

        // Debug log
        debugPrint('Rider location response: $data');

        // Check for location data
        if (data['location'] != null &&
            data['location']['lat'] != null &&
            data['location']['lng'] != null) {
          final lat = _parseCoordinate(data['location']['lat']);
          final lng = _parseCoordinate(data['location']['lng']);

          if (lat != 0.0 && lng != 0.0) {
            final newRiderLocation = LatLng(lat, lng);

            // Get rider info - now using the correct key from API
            Map<String, dynamic>? riderInfo;
            if (data['rider'] != null &&
                data['rider'] is Map<String, dynamic>) {
              riderInfo = Map<String, dynamic>.from(data['rider']);

              // Ensure we have name and rider_code
              if (riderInfo!['name'] == null) {
                riderInfo['name'] = 'Rider';
              }
              if (riderInfo['rider_code'] == null) {
                riderInfo['rider_code'] = '';
              }
            } else {
              // Fallback if rider info not available
              riderInfo = {'name': 'Rider', 'rider_code': '', 'phone': ''};
            }

            setState(() {
              _riderLocation = newRiderLocation;
              _riderInfo = riderInfo;
            });

            _updateMap();

            // Debug log
            debugPrint('Rider location updated: $lat, $lng');
            debugPrint('Rider info: $riderInfo');
          }
        } else {
          // If no location but we have rider info (rider hasn't started moving yet)
          if (data['rider'] != null && data['rider'] is Map<String, dynamic>) {
            final riderInfo = Map<String, dynamic>.from(data['rider']);

            setState(() {
              _riderInfo = riderInfo;
            });

            debugPrint('No location yet, but rider info: $riderInfo');
          }
        }
      }
    } catch (e) {
      debugPrint('Fetch rider location error: $e');
    }
  }

  // In the _openChat function:
  void _openChat() {
    // Make sure we have the rider name
    String riderName = _riderInfo?['name'] ?? 'Rider';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          deliveryId: widget.deliveryId,
          otherUserName: riderName,
          riderName: null, // This can be removed if ChatScreen doesn't need it
        ),
      ),
    ).then((_) {
      _fetchUnreadMessages();
    });
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
    // Update every 5 seconds for real-time feel
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchRiderLocation();
    });
  }

  void _startChatUpdates() {
    _chatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    // Add or update rider marker
    if (_riderLocation != null) {
      // Remove existing rider marker
      _markers.removeWhere((m) => m.markerId.value == 'rider');

      // Add new rider marker with animation
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
          anchor: const Offset(0.5, 0.5),
          draggable: false,
          visible: true,
          rotation: 0.0,
        ),
      );

      // Update polyline from rider to destination
      _polylines.clear();

      final destination = _dropoffLocation ?? _pickupLocation;
      if (destination != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_riderLocation!, destination],
            color: Colors.blue,
            width: 4,
            patterns: [PatternItem.dash(10), PatternItem.gap(10)],
          ),
        );
      }

      // Center map on rider location with all points visible
      if (_mapController != null) {
        final List<LatLng> points = [];

        if (_riderLocation != null) points.add(_riderLocation!);
        if (_pickupLocation != null) points.add(_pickupLocation!);
        if (_dropoffLocation != null) points.add(_dropoffLocation!);

        if (points.length > 1) {
          // Calculate bounds
          double minLat = points.first.latitude;
          double maxLat = points.first.latitude;
          double minLng = points.first.longitude;
          double maxLng = points.first.longitude;

          for (final point in points) {
            if (point.latitude < minLat) minLat = point.latitude;
            if (point.latitude > maxLat) maxLat = point.latitude;
            if (point.longitude < minLng) minLng = point.longitude;
            if (point.longitude > maxLng) maxLng = point.longitude;
          }

          final bounds = LatLngBounds(
            southwest: LatLng(minLat - 0.005, minLng - 0.005),
            northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
          );

          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        } else if (_riderLocation != null) {
          // Just center on rider
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_riderLocation!, 15),
          );
        }
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
                      _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
                    initialCameraPosition: CameraPosition(
                      target:
                          _pickupLocation ??
                          _riderLocation ??
                          const LatLng(-17.8249, 31.05),
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
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
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(
                              Icons.person,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            _riderInfo!['name'] ?? 'Rider',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_riderInfo!['rider_code'] != null)
                                Text(
                                  'Rider Code: ${_riderInfo!['rider_code']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              if (_riderInfo!['phone'] != null)
                                Text(
                                  'Phone: ${_riderInfo!['phone']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.phone),
                              label: const Text('Call Rider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _riderInfo?['phone'] != null
                                  ? () {
                                      // Implement phone call
                                      final phone = _riderInfo!['phone'];
                                      // You can use url_launcher package for this
                                      debugPrint('Calling rider: $phone');
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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

  // void _openChat() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => ChatScreen(
  //         deliveryId: widget.deliveryId,
  //         otherUserName: _riderInfo?['name'] ?? 'Rider',
  //         riderName: null, // Changed from 'riderName' to 'otherUserName'
  //       ),
  //     ),
  //   ).then((_) {
  //     _fetchUnreadMessages();
  //   });
  // }
}
