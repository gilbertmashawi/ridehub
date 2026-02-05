import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riderhub/screens/chat_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DeliveryTrackingScreen extends StatefulWidget {
  final int assignmentId;
  final Map<String, dynamic> jobDetails;

  const DeliveryTrackingScreen({
    Key? key,
    required this.assignmentId,
    required this.jobDetails,
  }) : super(key: key);

  @override
  _DeliveryTrackingScreenState createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _currentStatus =
      'assigned'; // assigned, picked_up, in_transit, delivered
  int _unreadMessages = 0;
  Timer? _locationTimer;
  Timer? _chatTimer;

  // Real-time location tracking
  LatLng? _currentRiderLocation;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  // Distance tracking
  double _distanceToDropoff = 0.0;
  double _totalDistance = 0.0;
  List<LatLng> _routePoints = [];

  // Delivery confirmation
  File? _deliveryProofImage;
  bool _isWithinDeliveryRange = false;
  final double _deliveryRangeMeters = 100.0; // 0.1km = 100m

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startLocationTracking();
    _startChatUpdates();
    _loadCurrentAssignmentStatus();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _chatTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _initializeMap() {
    final pickup = LatLng(
      widget.jobDetails['pickup_lat'] ?? 0.0,
      widget.jobDetails['pickup_lng'] ?? 0.0,
    );
    final dropoff = LatLng(
      widget.jobDetails['dropoff_lat'] ?? 0.0,
      widget.jobDetails['dropoff_lng'] ?? 0.0,
    );

    // Store for distance calculations
    _routePoints = [pickup, dropoff];

    // Calculate initial total distance
    _totalDistance = _calculateDistance(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );

    _markers.addAll([
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Pickup Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: dropoff,
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
          snippet: 'Distance: ${_totalDistance.toStringAsFixed(1)} km',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    ]);

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [pickup, dropoff],
        color: Colors.blue.withOpacity(0.6),
        width: 4,
        patterns: [PatternItem.dash(10), PatternItem.gap(10)],
      ),
    );

    // Center map on pickup initially
    _centerMapOnLocation(pickup);
  }

  void _startLocationTracking() async {
    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    // Start listening to position stream
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 10, // Update every 10 meters
            timeLimit: Duration(seconds: 30),
          ),
        ).listen((Position position) {
          _updateRiderLocation(position);
        });

    // Also get initial position
    Position initialPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _updateRiderLocation(initialPosition);
  }

  void _updateRiderLocation(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() async {
      _currentRiderLocation = newLocation;
      _lastPosition = position;

      // Update or add rider marker
      _markers.removeWhere((marker) => marker.markerId.value == 'rider');
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: newLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: await _getRiderIcon(),
          rotation: position.heading ?? 0,
        ),
      );

      // Calculate distance to dropoff
      final dropoff = LatLng(
        widget.jobDetails['dropoff_lat'] ?? 0.0,
        widget.jobDetails['dropoff_lng'] ?? 0.0,
      );

      _distanceToDropoff = _calculateDistance(
        newLocation.latitude,
        newLocation.longitude,
        dropoff.latitude,
        dropoff.longitude,
      );

      // Check if within delivery range
      _isWithinDeliveryRange =
          _distanceToDropoff * 1000 <= _deliveryRangeMeters;

      // Update dropoff marker info
      _updateDropoffMarkerInfo();
    });

    // Send location update to server
    await _sendLocationToServer(position);

    // Center map on rider if they're far from center
    _centerMapOnRiderIfNeeded(newLocation);
  }

  Future<BitmapDescriptor> _getRiderIcon() async {
    // You can create a custom icon for the rider
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  void _updateDropoffMarkerInfo() {
    // Find and update dropoff marker
    final dropoffMarker = _markers.firstWhere(
      (marker) => marker.markerId.value == 'dropoff',
      orElse: () => Marker(markerId: const MarkerId('')),
    );

    if (dropoffMarker.markerId.value == 'dropoff') {
      _markers.remove(dropoffMarker);
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoffMarker.position,
          infoWindow: InfoWindow(
            title: 'Dropoff Location',
            snippet:
                'Distance: ${_distanceToDropoff.toStringAsFixed(1)} km '
                '(${(_distanceToDropoff * 1000).toStringAsFixed(0)} m)',
          ),
          icon: _isWithinDeliveryRange
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  void _centerMapOnRiderIfNeeded(LatLng riderLocation) {
    if (_mapController != null) {
      _mapController?.getVisibleRegion().then((visibleRegion) {
        final bounds = LatLngBounds(
          southwest: visibleRegion.southwest,
          northeast: visibleRegion.northeast,
        );

        if (!bounds.contains(riderLocation)) {
          _centerMapOnLocation(riderLocation);
        }
      });
    }
  }

  void _centerMapOnLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15.0));
  }

  Future<void> _sendLocationToServer(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final response = await http.post(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=update_delivery_location',
        ),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'delivery_id': widget.assignmentId,
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Location updated to server');
      }
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  Future<void> _loadCurrentAssignmentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

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
          setState(() {
            _currentStatus =
                data['assignment']['assignment_status'] ?? 'assigned';
          });
        }
      }
    } catch (e) {
      debugPrint('Load assignment status error: $e');
    }
  }

  Future<void> _updateStatus(String newStatus, {File? proofImage}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      // Create multipart request for image upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=deliveries_pod',
        ),
      );

      // Add headers
      request.headers['X-Session-Id'] = sessionId;

      // Add fields
      request.fields['delivery_id'] = widget.assignmentId.toString();
      request.fields['status'] = newStatus;

      // Add image if provided
      if (proofImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', proofImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] == null) {
          setState(() => _currentStatus = newStatus);

          if (newStatus == 'delivered') {
            _showDeliveryCompleteDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated to $newStatus'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Update status error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDeliveryProofImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _deliveryProofImage = File(pickedFile.path);
      });
    }
  }

  void _showDeliveryCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Delivery Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Delivery has been marked as complete.'),
            const SizedBox(height: 10),
            Text('Assignment ID: ${widget.assignmentId}'),
            Text('Fare: \$${widget.jobDetails['fare_amount'] ?? '0.00'}'),
            const SizedBox(height: 20),
            const Text(
              'Thank you for your service! Payment will be processed to your wallet.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Return Home'),
          ),
        ],
      ),
    );
  }

  void _showMarkDeliveredDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Mark Delivery as Complete'),
            const SizedBox(height: 16),
            if (!_isWithinDeliveryRange)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You must be within ${_deliveryRangeMeters}m of the dropoff point.\n'
                        'Current distance: ${(_distanceToDropoff * 1000).toStringAsFixed(0)}m',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Upload proof of delivery:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDeliveryProofImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _deliveryProofImage != null
                        ? Colors.green
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: _deliveryProofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _deliveryProofImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to take photo',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isWithinDeliveryRange && _deliveryProofImage != null
                    ? () {
                        Navigator.pop(context);
                        _updateStatus(
                          'delivered',
                          proofImage: _deliveryProofImage,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Confirm Delivery',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchUnreadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_messages&delivery_id=${widget.assignmentId}',
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
                (msg) =>
                    msg['sender_type'] == 'customer' && msg['is_read'] == 0,
              )
              .length;
        });
      }
    } catch (e) {
      debugPrint('Fetch unread messages error: $e');
    }
  }

  void _startChatUpdates() {
    _fetchUnreadMessages();
    _chatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchUnreadMessages();
    });
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          deliveryId: widget.assignmentId,
          otherUserName: widget.jobDetails['customer_name'] ?? 'Customer',
          riderName: null,
        ),
      ),
    ).then((_) {
      _fetchUnreadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Delivery'),
            if (_distanceToDropoff > 0)
              Text(
                '${(_distanceToDropoff * 1000).toStringAsFixed(0)}m to destination',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.chat), onPressed: _openChat),
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.jobDetails['pickup_lat'] ?? 0.0,
                      widget.jobDetails['pickup_lng'] ?? 0.0,
                    ),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      if (_currentRiderLocation != null) {
                        _centerMapOnLocation(_currentRiderLocation!);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                _buildStatusStep(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: Text(
                          'Chat${_unreadMessages > 0 ? ' ($_unreadMessages)' : ''}',
                        ),
                        onPressed: _openChat,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Delivered'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isWithinDeliveryRange
                              ? Colors.green
                              : Colors.grey,
                        ),
                        onPressed: _isWithinDeliveryRange
                            ? _showMarkDeliveredDialog
                            : null,
                      ),
                    ),
                  ],
                ),
                if (_distanceToDropoff > 0) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value:
                        1 -
                        (_distanceToDropoff / _totalDistance).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Progress: ${((1 - (_distanceToDropoff / _totalDistance)) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep() {
    final steps = ['Assigned', 'Picked Up', 'In Transit', 'Delivered'];
    final currentStep = _currentStatus == 'assigned'
        ? 0
        : _currentStatus == 'picked_up'
        ? 1
        : _currentStatus == 'in_transit'
        ? 2
        : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: index <= currentStep ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: index <= currentStep ? Colors.green : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (currentStep + 1) / steps.length,
          backgroundColor: Colors.grey[300],
          color: Colors.green,
        ),
      ],
    );
  }
}
