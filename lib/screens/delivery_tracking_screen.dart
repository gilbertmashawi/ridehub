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
  String _currentStatus = 'assigned'; // assigned, picked_up, delivered
  int _unreadMessages = 0;
  Timer? _chatTimer;

  // Real-time location tracking
  LatLng? _currentRiderLocation;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  // Distance tracking
  double _distanceToDropoff = 0.0;
  double _totalDistance = 0.0;

  // Delivery confirmation
  File? _deliveryProofImage;
  bool _isWithinDeliveryRange = false;
  final double _deliveryRangeMeters = 100.0; // 100 meters

  bool _isLoadingAction = false;

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
    _chatTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _initializeMap() {
    final pickup = LatLng(
      widget.jobDetails['pickup_lat']?.toDouble() ?? 0.0,
      widget.jobDetails['pickup_lng']?.toDouble() ?? 0.0,
    );
    final dropoff = LatLng(
      widget.jobDetails['dropoff_lat']?.toDouble() ?? 0.0,
      widget.jobDetails['dropoff_lng']?.toDouble() ?? 0.0,
    );

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
      ),
    );

    _centerMapOnLocation(pickup);
  }

  void _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          _updateRiderLocation(position);
        });

    // Initial position
    try {
      Position initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateRiderLocation(initial);
    } catch (e) {
      debugPrint("Initial location error: $e");
    }
  }

  void _updateRiderLocation(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentRiderLocation = newLocation;
      _lastPosition = position;

      // Update rider marker
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: newLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          rotation: position.heading,
        ),
      );

      // Distance to dropoff
      final dropoff = LatLng(
        widget.jobDetails['dropoff_lat']?.toDouble() ?? 0.0,
        widget.jobDetails['dropoff_lng']?.toDouble() ?? 0.0,
      );

      _distanceToDropoff = _calculateDistance(
        newLocation.latitude,
        newLocation.longitude,
        dropoff.latitude,
        dropoff.longitude,
      );

      _isWithinDeliveryRange =
          (_distanceToDropoff * 1000) <= _deliveryRangeMeters;

      _updateDropoffMarkerInfo();
    });

    // Send to server
    await _sendLocationToServer(position);
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  void _updateDropoffMarkerInfo() {
    final dropoffMarkerIndex = _markers.toList().indexWhere(
      (m) => m.markerId.value == 'dropoff',
    );
    if (dropoffMarkerIndex == -1) return;

    final oldMarker = _markers.elementAt(dropoffMarkerIndex);
    _markers.remove(oldMarker);

    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: oldMarker.position,
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
          snippet:
              'Distance: ${(_distanceToDropoff * 1000).toStringAsFixed(0)} m',
        ),
        icon: _isWithinDeliveryRange
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _centerMapOnLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  Future<void> _sendLocationToServer(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      await http.post(
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
    } catch (e) {
      debugPrint('Location update failed: $e');
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
      debugPrint('Load status error: $e');
    }
  }

  Future<void> _markAsPickedUp() async {
    setState(() => _isLoadingAction = true);

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) {
      setState(() => _isLoadingAction = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=mark_picked_up',
        ),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'delivery_id': widget.assignmentId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _currentStatus = 'picked_up';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as Picked Up'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoadingAction = false);
  }

  Future<void> _pickAndUploadProof() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 900,
    );

    if (pickedFile == null) return;

    setState(() {
      _deliveryProofImage = File(pickedFile.path);
    });

    _showConfirmDeliveryDialog();
  }

  void _showConfirmDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_deliveryProofImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _deliveryProofImage!,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to mark this delivery as completed?',
            ),
            if (!_isWithinDeliveryRange)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Warning: You are not very close to the drop-off point (${(_distanceToDropoff * 1000).toStringAsFixed(0)}m)',
                  style: const TextStyle(color: Colors.orange),
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
              Navigator.pop(context);
              _submitDelivered();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Delivered'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDelivered() async {
    if (_deliveryProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof photo is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoadingAction = true);

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) {
      setState(() => _isLoadingAction = false);
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=mark_delivered',
        ),
      );

      request.headers['X-Session-Id'] = sessionId;
      request.fields['delivery_id'] = widget.assignmentId.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'proof_photo',
          _deliveryProofImage!.path,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _currentStatus = 'delivered';
          _deliveryProofImage = null;
        });

        _showDeliveryCompleteDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Delivered error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error completing delivery'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoadingAction = false);
  }

  void _showDeliveryCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Delivery Completed!'),
          ],
        ),
        content: const Text(
          'The delivery has been successfully marked as delivered.\n'
          'Thank you for your service!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUnreadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final res = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_messages&delivery_id=${widget.assignmentId}',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final messages = (data['messages'] as List?) ?? [];
        setState(() {
          _unreadMessages = messages
              .where((m) => m['sender_type'] == 'customer' && m['is_read'] == 0)
              .length;
        });
      }
    } catch (e) {
      debugPrint('Unread messages error: $e');
    }
  }

  void _startChatUpdates() {
    _fetchUnreadMessages();
    _chatTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _fetchUnreadMessages(),
    );
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
    ).then((_) => _fetchUnreadMessages());
  }

  double get _progress {
    if (_currentStatus == 'delivered') return 1.0;
    if (_currentStatus == 'picked_up') return 0.5;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

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
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
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
                      widget.jobDetails['pickup_lat']?.toDouble() ?? -17.83,
                      widget.jobDetails['pickup_lng']?.toDouble() ?? 31.05,
                    ),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                if (_currentRiderLocation != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () =>
                          _centerMapOnLocation(_currentRiderLocation!),
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Progress bar
                Row(
                  children: [
                    Text(
                      _currentStatus == 'delivered'
                          ? 'Delivered'
                          : _currentStatus == 'picked_up'
                          ? 'Picked Up'
                          : 'Assigned',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  color: progress >= 1.0 ? Colors.green : Colors.blue,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 20),

                // Action buttons
                if (_currentStatus == 'assigned')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Picked Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoadingAction ? null : _markAsPickedUp,
                    ),
                  ),

                if (_currentStatus == 'picked_up') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Upload Proof & Mark Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isWithinDeliveryRange
                            ? Colors.green
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoadingAction || !_isWithinDeliveryRange
                          ? null
                          : _pickAndUploadProof,
                    ),
                  ),
                  if (!_isWithinDeliveryRange)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You must be within 100m of drop-off to complete delivery',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],

                if (_currentStatus == 'delivered')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Delivery Completed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: Text(
                          'Chat${_unreadMessages > 0 ? ' ($_unreadMessages)' : ''}',
                        ),
                        onPressed: _openChat,
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
}
